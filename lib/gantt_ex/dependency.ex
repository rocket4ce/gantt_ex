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

  @typedoc """
  The links of a store indexed by task (see `index/1`):

    * `:incoming` - task id => `incoming/2` of the task
    * `:outgoing` - task id => `outgoing/2` of the task
    * `:sources` - link id => `source_ids/2` of the link
  """
  @type index :: %{
          incoming: %{Task.id() => [Link.t()]},
          outgoing: %{Task.id() => [Link.t()]},
          sources: %{Task.id() => [Task.id()]}
        }

  @doc """
  Indexes the links of the store by the tasks they relate, so that a pass
  over the whole plan does not scan every link for every task. The index
  stays valid while only dates change (it depends on the links and the tree).

      iex> store = GanttEx.Store.new!(
      ...>   [%{id: 1, start_date: ~D[2025-01-06]}, %{id: 2, start_date: ~D[2025-01-06]}],
      ...>   [%{id: 1, source: 1, target: 2}]
      ...> )
      iex> index = GanttEx.Dependency.index(store)
      iex> {Enum.map(index.incoming[2], & &1.id), index.outgoing[2], index.sources[1]}
      {[1], nil, [1]}
  """
  @spec index(Store.t()) :: index()
  def index(store) do
    links = Store.links(store)

    %{
      incoming: group(links, &constrained_ids(store, &1)),
      outgoing: group(links, &[&1.source | Store.descendant_ids(store, &1.source)]),
      sources: Map.new(links, &{&1.id, source_ids(store, &1)})
    }
  end

  # The ids `incoming/2` returns a link for: its target, and the descendants
  # of the target for finish-to-start and start-to-start links.
  defp constrained_ids(store, %Link{target: target, type: type}) do
    if type in [:finish_to_start, :start_to_start],
      do: [target | Store.descendant_ids(store, target)],
      else: [target]
  end

  # Groups the links by the ids `fun` returns for each, keeping link order.
  defp group(links, fun) do
    links
    |> Enum.reduce(%{}, fn link, acc ->
      Enum.reduce(fun.(link), acc, fn id, acc -> Map.update(acc, id, [link], &[link | &1]) end)
    end)
    |> Map.new(fn {id, links} -> {id, Enum.reverse(links)} end)
  end

  @doc """
  Returns the schedulable task ids ordered so that every task comes after the
  tasks it depends on (ties keep the tree order). Tasks in a cycle, which
  links between a project and its own descendants can create, are appended
  in tree order.

  Pass the `index/1` of the store when you already have it.
  """
  @spec order(Store.t(), index() | nil) :: [Task.id()]
  def order(store, index \\ nil) do
    index = index || index(store)
    ids = schedulable_ids(store)

    preds =
      Map.new(ids, fn id ->
        deps =
          index.incoming
          |> Map.get(id, [])
          |> Enum.flat_map(&Map.fetch!(index.sources, &1.id))
          |> Enum.reject(&(&1 == id))
          |> MapSet.new()

        {id, deps}
      end)

    succs =
      Enum.reduce(preds, %{}, fn {id, deps}, acc ->
        Enum.reduce(deps, acc, &Map.update(&2, &1, [id], fn ids -> [id | ids] end))
      end)

    position = ids |> Enum.with_index() |> Map.new()
    pending = Map.new(preds, fn {id, deps} -> {id, MapSet.size(deps)} end)

    ready = :gb_sets.from_list(for {id, 0} <- pending, do: {Map.fetch!(position, id), id})

    kahn(ready, Map.reject(pending, &(elem(&1, 1) == 0)), succs, position, [], ids)
  end

  # Kahn's algorithm, always taking the ready task that comes first in the tree.
  defp kahn(ready, pending, succs, position, acc, ids) do
    if :gb_sets.is_empty(ready) do
      # what is left depends on a cycle
      Enum.reverse(acc, Enum.filter(ids, &Map.has_key?(pending, &1)))
    else
      {{_position, id}, ready} = :gb_sets.take_smallest(ready)

      {ready, pending} =
        succs
        |> Map.get(id, [])
        |> Enum.reduce({ready, pending}, fn succ, {ready, pending} ->
          case Map.fetch!(pending, succ) do
            1 ->
              {:gb_sets.add({Map.fetch!(position, succ), succ}, ready), Map.delete(pending, succ)}

            count ->
              {ready, Map.put(pending, succ, count - 1)}
          end
        end)

      kahn(ready, pending, succs, position, [id | acc], ids)
    end
  end

  @doc """
  Returns the earliest start the links of `task` allow, or `nil` when no link
  constrains it. Pass the `index/1` of the store when you already have it.
  """
  @spec earliest_start(Store.t(), Task.t(), index() | nil) :: NaiveDateTime.t() | nil
  def earliest_start(store, %Task{} = task, index \\ nil) do
    if(index, do: Map.get(index.incoming, task.id, []), else: incoming(store, task))
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
