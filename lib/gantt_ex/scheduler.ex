defmodule GanttEx.Scheduler do
  @moduledoc """
  Auto-scheduling: moves tasks so that dependencies and constraints hold.

  Tasks are processed in dependency order (see `GanttEx.Dependency`). Each
  task starts at the earliest date its predecessors allow, adjusted by its
  constraint:

  | Constraint | Meaning                          | Effect                                      |
  | ---------- | -------------------------------- | ------------------------------------------- |
  | `:asap`    | as soon as possible (default)    | dependencies only                           |
  | `:alap`    | as late as possible              | as late as successors and the project allow |
  | `:snet`    | start no earlier than the date   | lower bound                                 |
  | `:fnet`    | finish no earlier than the date  | lower bound                                 |
  | `:snlt`    | start no later than the date     | upper bound (wins over dependencies)        |
  | `:fnlt`    | finish no later than the date    | upper bound (wins over dependencies)        |
  | `:mso`     | must start on the date           | fixed start                                 |
  | `:mfo`     | must finish on the date          | fixed end                                   |

  By default only tasks that violate a dependency are moved (later). With
  `strict: true` every constrained task moves to its earliest possible date,
  so tasks also move earlier when their predecessors do.

      iex> store = GanttEx.Store.new!(
      ...>   [
      ...>     %{id: 1, text: "Design", start_date: ~D[2025-01-06], duration: 3},
      ...>     %{id: 2, text: "Build", start_date: ~D[2025-01-07], duration: 2},
      ...>     %{id: 3, text: "Launch", start_date: ~D[2025-01-08], type: :milestone}
      ...>   ],
      ...>   [%{id: 1, source: 1, target: 2}, %{id: 2, source: 2, target: 3}]
      ...> )
      iex> {:ok, store, changes} = GanttEx.Scheduler.schedule(store)
      iex> Enum.map(changes, fn {type, task, _} -> {type, task.id} end)
      [task_updated: 2, task_updated: 3]
      iex> {GanttEx.Store.get_task(store, 2).start_date, GanttEx.Store.get_task(store, 3).start_date}
      {~N[2025-01-09 00:00:00], ~N[2025-01-11 00:00:00]}
  """

  alias GanttEx.{Dates, Dependency, Store, Task}

  @doc """
  Schedules every task of the store.

  ## Options

    * `:strict` - move tasks to their earliest possible date, even earlier.
      Defaults to `false`.

  Returns `{:ok, store, changes}` like the mutations of `GanttEx.Store`.
  """
  @spec schedule(Store.t(), keyword()) :: {:ok, Store.t(), [Store.change()]}
  def schedule(%Store{} = store, opts \\ []) do
    strict = Keyword.get(opts, :strict, false)
    order = Dependency.order(store)

    {store, changes} =
      Enum.reduce(order, {store, []}, fn id, {store, acc} ->
        task = Store.get_task(store, id)
        move(store, task, target_start(store, task, strict), acc)
      end)

    {store, changes} =
      order
      |> Enum.reverse()
      |> Enum.reduce({store, changes}, fn id, {store, acc} ->
        task = Store.get_task(store, id)

        if task.constraint_type == :alap,
          do: move(store, task, alap_start(store, task), acc),
          else: {store, acc}
      end)

    {:ok, store, compact(changes)}
  end

  defp move(store, _task, nil, acc), do: {store, acc}

  defp move(store, task, start, acc) do
    if NaiveDateTime.compare(start, task.start_date) == :eq do
      {store, acc}
    else
      {:ok, store, changes} = Store.update_task(store, task.id, %{start_date: start})
      {store, acc ++ changes}
    end
  end

  @doc """
  Returns the start date `task` should have, or `nil` to keep it.
  """
  @spec target_start(Store.t(), Task.t(), boolean()) :: NaiveDateTime.t() | nil
  def target_start(store, %Task{} = task, strict \\ false) do
    date = task.constraint_date
    back = fn date -> Store.add_duration(store, task, date, -(task.duration || 0)) end

    case {task.constraint_type, date} do
      {:mso, %NaiveDateTime{}} ->
        date

      {:mfo, %NaiveDateTime{}} ->
        back.(date)

      {type, date} ->
        lower =
          [
            Dependency.earliest_start(store, task),
            type == :snet && date,
            type == :fnet && date && back.(date)
          ]
          |> Enum.filter(& &1)
          |> Enum.reduce(nil, &Dates.max/2)

        start =
          cond do
            is_nil(lower) -> task.start_date
            strict -> lower
            true -> Dates.max(task.start_date, lower)
          end

        upper =
          case {type, date} do
            {:snlt, %NaiveDateTime{}} -> date
            {:fnlt, %NaiveDateTime{}} -> back.(date)
            _ -> nil
          end

        if upper, do: Dates.min(start, upper), else: start
    end
  end

  # As late as possible: right before the earliest successor needs it, or at
  # the end of the project when nothing depends on it.
  defp alap_start(store, task) do
    project_end =
      store |> Store.tasks() |> Enum.map(& &1.end_date) |> Enum.reduce(nil, &Dates.max/2)

    latest_finish =
      store
      |> Dependency.outgoing(task)
      |> Enum.map(fn link ->
        case Store.get_task(store, link.target) do
          nil -> nil
          target -> Dependency.finish_bound(store, task, link, target.start_date, target.end_date)
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.reduce(nil, &Dates.min/2)

    finish = latest_finish || project_end
    start = Store.add_duration(store, task, finish, -(task.duration || 0))
    Dates.max(start, Dependency.earliest_start(store, task) || start)
  end

  @doc """
  Merges repeated `:task_updated` changes of the same task (a project can be
  recomputed several times while its children move), keeping the first
  position and the last value.

      iex> a = GanttEx.Task.new!(id: 1, text: "A")
      iex> b = %{a | text: "B"}
      iex> GanttEx.Scheduler.compact([{:task_updated, a, %{changes: %{start_date: 1}}}, {:task_updated, b, %{changes: %{end_date: 2}}}])
      [{:task_updated, b, %{changes: %{start_date: 1, end_date: 2}}}]
  """
  @spec compact([Store.change()]) :: [Store.change()]
  def compact(changes) do
    {order, merged} =
      Enum.reduce(changes, {[], %{}}, fn
        {:task_updated, task, %{changes: diff}} = change, {order, merged} ->
          key = {:task_updated, task.id}

          case Map.fetch(merged, key) do
            {:ok, {:task_updated, _old, %{changes: old_diff}}} ->
              {order,
               Map.put(merged, key, {:task_updated, task, %{changes: Map.merge(old_diff, diff)}})}

            :error ->
              {[key | order], Map.put(merged, key, change)}
          end

        change, {order, merged} ->
          key = make_ref()
          {[key | order], Map.put(merged, key, change)}
      end)

    order |> Enum.reverse() |> Enum.map(&Map.fetch!(merged, &1))
  end
end
