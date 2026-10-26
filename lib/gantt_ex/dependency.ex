defmodule GanttEx.Dependency do
  @moduledoc """
  The dependency graph behind auto-scheduling (`GanttEx.Scheduler`) and the
  critical path (`GanttEx.CriticalPath`).

  Only *schedulable* tasks take part: tasks and milestones, and projects
  without children. Projects with children get their dates from their
  descendants, so:

    * a link **from** a project depends on every schedulable descendant of it
    * a finish-to-start or start-to-start link **to** a project applies to each
      of its schedulable descendants

  Lags are in the duration unit of the store, using the calendar of the task
  being scheduled.

      iex> store = GanttEx.Store.new!(
      ...>   [%{id: 1, start_date: ~D[2025-01-06], duration: 2}, %{id: 2, start_date: ~D[2025-01-06], duration: 1}],
      ...>   [%{id: 1, source: 1, target: 2, lag: 1}]
      ...> )
      iex> GanttEx.Dependency.order(store)
      [1, 2]
      iex> task = GanttEx.Store.get_task(store, 2)
      iex> GanttEx.Dependency.earliest_start(store, task)
      ~N[2025-01-09 00:00:00]
  """

  alias GanttEx.{Dates, Link, Store, Task}

  @doc "Returns `true` when the dates of `task` are scheduled (not rolled up)."
  @spec schedulable?(Store.t(), Task.t()) :: boolean()
  def schedulable?(store, %Task{} = task),
    do: not (task.type == :project and Store.has_children?(store, task.id))

  @doc "Returns the ids of the schedulable tasks, in tree order."
  @spec schedulable_ids(Store.t()) :: [Task.id()]
  def schedulable_ids(store) do
    for task <- Store.tasks(store), schedulable?(store, task), do: task.id
  end

  @doc """
  Returns the links that constrain `task`: links to the task itself, plus
  finish-to-start and start-to-start links to its ancestor projects.
  """
  @spec incoming(Store.t(), Task.t()) :: [Link.t()]
  def incoming(store, %Task{} = task) do
    ancestors = MapSet.new(Store.ancestor_ids(store, task.id))

    Enum.filter(Store.links(store), fn link ->
      link.target == task.id or
        (MapSet.member?(ancestors, link.target) and
           link.type in [:finish_to_start, :start_to_start])
    end)
  end

  @doc "Returns the links whose source is `task` or one of its ancestor projects."
  @spec outgoing(Store.t(), Task.t()) :: [Link.t()]
  def outgoing(store, %Task{} = task) do
    sources = MapSet.new([task.id | Store.ancestor_ids(store, task.id)])
    Enum.filter(Store.links(store), &MapSet.member?(sources, &1.source))
  end

  @doc "Returns the schedulable tasks a link source stands for."
  @spec source_ids(Store.t(), Link.t()) :: [Task.id()]
  def source_ids(store, %Link{source: source}) do
    case Store.get_task(store, source) do
      nil ->
        []

      task ->
        if schedulable?(store, task),
          do: [source],
          else:
            store
            |> Store.descendant_ids(source)
            |> Enum.filter(&schedulable?(store, Store.get_task(store, &1)))
    end
  end

  @doc """
  Returns the schedulable task ids ordered so that every task comes after the
  tasks it depends on (ties keep the tree order). Tasks in a cycle, which
  links between a project and its own descendants can create, are appended
  in tree order.
  """
  @spec order(Store.t()) :: [Task.id()]
  def order(store) do
    ids = schedulable_ids(store)

    preds =
      Map.new(ids, fn id ->
        task = Store.get_task(store, id)

        deps =
          store
          |> incoming(task)
          |> Enum.flat_map(&source_ids(store, &1))
          |> Enum.reject(&(&1 == id))
          |> MapSet.new()

        {id, deps}
      end)

    kahn(ids, preds, MapSet.new(), [])
  end

  defp kahn([], _preds, _done, acc), do: Enum.reverse(acc)

  defp kahn(pending, preds, done, acc) do
    case Enum.find(pending, &MapSet.subset?(Map.fetch!(preds, &1), done)) do
      nil -> Enum.reverse(acc) ++ pending
      id -> kahn(List.delete(pending, id), preds, MapSet.put(done, id), [id | acc])
    end
  end

  @doc """
  Returns the earliest start the links of `task` allow, or `nil` when no link
  constrains it.
  """
  @spec earliest_start(Store.t(), Task.t()) :: NaiveDateTime.t() | nil
  def earliest_start(store, %Task{} = task) do
    store
    |> incoming(task)
    |> Enum.map(&start_bound(store, task, &1))
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce(nil, &Dates.max/2)
  end

  @doc """
  Returns the earliest start of `task` allowed by one incoming `link`.

    * finish-to-start: starts after the source ends (plus lag)
    * start-to-start: starts after the source starts (plus lag)
    * finish-to-finish: ends after the source ends (plus lag)
    * start-to-finish: ends after the source starts (plus lag)
  """
  @spec start_bound(Store.t(), Task.t(), Link.t()) :: NaiveDateTime.t() | nil
  def start_bound(store, %Task{} = task, %Link{} = link) do
    case Store.get_task(store, link.source) do
      nil ->
        nil

      source ->
        lagged = fn date -> Store.add_duration(store, task, date, link.lag) end
        back = fn date -> Store.add_duration(store, task, date, -(task.duration || 0)) end

        case link.type do
          :finish_to_start -> lagged.(source.end_date)
          :start_to_start -> lagged.(source.start_date)
          :finish_to_finish -> back.(lagged.(source.end_date))
          :start_to_finish -> back.(lagged.(source.start_date))
        end
    end
  end

  @doc """
  Returns the latest end of `source` that does not delay `successor` through
  `link`, given the successor's latest start and end.
  """
  @spec finish_bound(Store.t(), Task.t(), Link.t(), NaiveDateTime.t(), NaiveDateTime.t()) ::
          NaiveDateTime.t()
  def finish_bound(store, %Task{} = source, %Link{} = link, late_start, late_finish) do
    unlag = fn date -> Store.add_duration(store, source, date, -link.lag) end
    forward = fn date -> Store.add_duration(store, source, date, source.duration || 0) end

    case link.type do
      :finish_to_start -> unlag.(late_start)
      :start_to_start -> forward.(unlag.(late_start))
      :finish_to_finish -> unlag.(late_finish)
      :start_to_finish -> forward.(unlag.(late_finish))
    end
  end
end
