defmodule GanttEx.CriticalPath do
  @moduledoc """
  Critical path and slack analysis (CPM) of the current plan.

  A backward pass computes, for each schedulable task, the latest dates it
  can have without delaying its successors or the end of the project:

    * **total slack** - how much the task can slip without delaying the
      project end (`late start - start`)
    * **free slack** - how much the task can slip without delaying any
      successor
    * a task is **critical** when its total slack is zero (or negative, when
      the plan already breaks a dependency); a project is critical when one
      of its descendants is
    * a link is critical when it joins two critical tasks and drives the
      successor (the successor starts exactly when the link allows)

  Slack is expressed in the duration unit of the store and honors calendars.

      iex> store = GanttEx.Store.new!(
      ...>   [
      ...>     %{id: 1, text: "Design", start_date: ~D[2025-01-06], duration: 2},
      ...>     %{id: 2, text: "Build", start_date: ~D[2025-01-08], duration: 3},
      ...>     %{id: 3, text: "Docs", start_date: ~D[2025-01-08], duration: 1},
      ...>     %{id: 4, text: "Launch", start_date: ~D[2025-01-11], type: :milestone}
      ...>   ],
      ...>   [
      ...>     %{id: 1, source: 1, target: 2},
      ...>     %{id: 2, source: 1, target: 3},
      ...>     %{id: 3, source: 2, target: 4},
      ...>     %{id: 4, source: 3, target: 4}
      ...>   ]
      ...> )
      iex> analysis = GanttEx.CriticalPath.analyze(store)
      iex> for id <- 1..4, do: {id, analysis.tasks[id].critical, analysis.tasks[id].total_slack}
      [{1, true, 0}, {2, true, 0}, {3, false, 2}, {4, true, 0}]
      iex> analysis.tasks[3].free_slack
      2
      iex> analysis.links |> Enum.sort()
      [1, 3]
  """

  alias GanttEx.{Dates, Dependency, Store, Task}

  @typedoc "Analysis of one task."
  @type task_result :: %{
          critical: boolean(),
          total_slack: integer(),
          free_slack: integer(),
          late_start: NaiveDateTime.t(),
          late_finish: NaiveDateTime.t()
        }

  @type t :: %{
          tasks: %{Task.id() => task_result()},
          links: MapSet.t(Task.id()),
          project_end: NaiveDateTime.t() | nil
        }

  @doc """
  Analyzes the store. Projects with children get `critical` (and the slack
  of their most critical descendant).
  """
  @spec analyze(Store.t()) :: t()
  def analyze(%Store{} = store) do
    order = Dependency.order(store)
    tasks = Map.new(order, &{&1, Store.get_task(store, &1)})

    project_end =
      tasks |> Map.values() |> Enum.map(& &1.end_date) |> Enum.reduce(nil, &Dates.max/2)

    late =
      order
      |> Enum.reverse()
      |> Enum.reduce(%{}, fn id, late ->
        task = Map.fetch!(tasks, id)
        finish = latest_finish(store, task, late) || project_end
        start = Store.add_duration(store, task, finish, -(task.duration || 0))
        Map.put(late, id, {start, finish})
      end)

    results =
      Map.new(order, fn id ->
        task = Map.fetch!(tasks, id)
        {late_start, late_finish} = Map.fetch!(late, id)
        total = Store.duration_between(store, task, task.start_date, late_start)

        {id,
         %{
           critical: total <= 0,
           total_slack: total,
           free_slack: free_slack(store, task, project_end),
           late_start: late_start,
           late_finish: late_finish
         }}
      end)

    %{
      tasks: Map.merge(results, project_results(store, results)),
      links: critical_links(store, results),
      project_end: project_end
    }
  end

  # The latest finish allowed by the successors of `task` (nil when none).
  defp latest_finish(store, task, late) do
    store
    |> Dependency.outgoing(task)
    |> Enum.flat_map(fn link ->
      for successor <- successors(store, link),
          {late_start, late_finish} = Map.get(late, successor.id, {nil, nil}),
          late_start != nil do
        Dependency.finish_bound(store, task, link, late_start, late_finish)
      end
    end)
    |> Enum.reduce(nil, &Dates.min/2)
  end

  # The schedulable tasks a link targets (the descendants of a project target).
  defp successors(store, link) do
    case Store.get_task(store, link.target) do
      nil ->
        []

      target ->
        if Dependency.schedulable?(store, target) do
          [target]
        else
          if link.type in [:finish_to_start, :start_to_start] do
            store
            |> Store.descendant_ids(target.id)
            |> Enum.map(&Store.get_task(store, &1))
            |> Enum.filter(&Dependency.schedulable?(store, &1))
          else
            []
          end
        end
    end
  end

  defp free_slack(store, task, project_end) do
    slacks =
      store
      |> Dependency.outgoing(task)
      |> Enum.flat_map(fn link ->
        for successor <- successors(store, link),
            bound = Dependency.start_bound(store, successor, link),
            bound != nil,
            do: Store.duration_between(store, successor, bound, successor.start_date)
      end)

    case slacks do
      [] ->
        max(Store.duration_between(store, task, task.end_date, project_end || task.end_date), 0)

      slacks ->
        max(Enum.min(slacks), 0)
    end
  end

  defp critical_links(store, results) do
    for link <- Store.links(store),
        source_ids = Dependency.source_ids(store, link),
        Enum.any?(source_ids, &critical?(results, &1)),
        successor <- successors(store, link),
        critical?(results, successor.id),
        bound = Dependency.start_bound(store, successor, link),
        bound != nil,
        Store.duration_between(store, successor, bound, successor.start_date) <= 0,
        into: MapSet.new(),
        do: link.id
  end

  defp critical?(results, id), do: match?(%{critical: true}, Map.get(results, id))

  defp project_results(store, results) do
    for task <- Store.tasks(store),
        not Map.has_key?(results, task.id),
        descendants =
          Store.descendant_ids(store, task.id)
          |> Enum.map(&Map.get(results, &1))
          |> Enum.reject(&is_nil/1),
        descendants != [],
        into: %{} do
      worst = Enum.min_by(descendants, & &1.total_slack)
      {task.id, %{worst | critical: Enum.any?(descendants, & &1.critical)}}
    end
  end
end
