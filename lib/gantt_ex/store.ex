defmodule GanttEx.Store do
  @moduledoc """
  An immutable, in-memory container of tasks and links.

  The store keeps tasks as an ordered tree (siblings keep the order they were
  given in), computes missing dates/durations, rolls up the dates of
  `:project` tasks from their children and validates dependencies.

  Every mutating function returns `{:ok, store, changes}`, where `changes` is
  the list of everything that changed, including side effects such as the
  dates of a parent project or the links removed with a task. `GanttEx.Live.Gantt`
  turns each change into a `GanttEx.Event` for the parent LiveView.

  ## Examples

      iex> {:ok, store} =
      ...>   GanttEx.Store.new(
      ...>     [
      ...>       %{id: 1, text: "Website", type: :project},
      ...>       %{id: 2, text: "Design", parent: 1, start_date: ~D[2025-01-06], duration: 3},
      ...>       %{id: 3, text: "Build", parent: 1, start_date: ~D[2025-01-09], end_date: ~D[2025-01-16]}
      ...>     ],
      ...>     [%{id: 1, source: 2, target: 3}]
      ...>   )
      iex> project = GanttEx.Store.get_task(store, 1)
      iex> {project.start_date, project.end_date, project.duration}
      {~N[2025-01-06 00:00:00], ~N[2025-01-16 00:00:00], 10}
      iex> {:ok, store, changes} = GanttEx.Store.update_task(store, 3, %{duration: 9})
      iex> Enum.map(changes, fn {type, task, _details} -> {type, task.id} end)
      [task_updated: 3, task_updated: 1]
      iex> GanttEx.Store.get_task(store, 1).end_date
      ~N[2025-01-18 00:00:00]
  """

  alias GanttEx.{Calendar, Dates, Link, Task}

  defstruct tasks: %{},
            links: %{},
            link_order: [],
            children: %{nil => []},
            task_keys: %{},
            link_keys: %{},
            duration_unit: :day,
            work_time: false,
            calendar: nil,
            calendars: %{},
            auto_types: false,
            resize_snap: :extend

  @typedoc "A string version of an id, as used in the DOM and in client events."
  @type key :: String.t()

  @typedoc "Why an operation was rejected."
  @type error ::
          Task.error()
          | {:invalid_task, Task.id(), term()}
          | {:invalid_link, Task.id(), term()}
          | {:duplicate_id, :task | :link, Task.id()}
          | {:parent_cycle, Task.id()}
          | :not_found
          | :missing_parent
          | :invalid_parent
          | :self_link
          | :missing_task
          | :duplicate_link
          | :cycle

  @typedoc """
  A change produced by a mutation: `{type, entity, details}`.

    * `:task_created`, `:task_deleted`, `:link_created`, `:link_deleted` have empty details
    * `:task_updated` and `:link_updated` details contain `:changes`, a map of the
      changed fields and their new values
    * `:task_moved` details contain `:parent`, `:index` and `:siblings` (the
      ordered ids of the new siblings, including the moved task)
  """
  @type change ::
          {:task_created | :task_updated | :task_deleted | :task_moved, Task.t(), map()}
          | {:link_created | :link_updated | :link_deleted, Link.t(), map()}

  @type t :: %__MODULE__{
          tasks: %{Task.id() => Task.t()},
          links: %{Task.id() => Link.t()},
          link_order: [Task.id()],
          children: %{(Task.id() | nil) => [Task.id()]},
          task_keys: %{key() => Task.id()},
          link_keys: %{key() => Task.id()},
          duration_unit: Dates.unit(),
          work_time: boolean(),
          calendar: Calendar.t() | nil,
          calendars: %{term() => Calendar.t()},
          auto_types: boolean(),
          resize_snap: resize_snap()
        }

  @typedoc """
  Where an edited edge that falls on a non-working day goes: the task grows
  to the next working day (`:extend`) or shrinks to the previous one
  (`:shrink`). See `schedule/5`.
  """
  @type resize_snap :: :extend | :shrink

  @typedoc "A visible row, as returned by `rows/2`."
  @type row :: %{
          task: Task.t(),
          key: key(),
          index: non_neg_integer(),
          level: non_neg_integer(),
          parent_key: key() | nil,
          has_children: boolean(),
          open: boolean(),
          wbs: String.t(),
          uid: String.t(),
          group: boolean(),
          count: non_neg_integer() | nil
        }

  @date_fields [:start_date, :end_date, :duration]

  # -- building ----------------------------------------------------------------

  @doc """
  Builds a store from lists of tasks and links (anything accepted by
  `GanttEx.Task.new/1` and `GanttEx.Link.new/1`).

  ## Options

    * `:duration_unit` - unit of `:duration` and `:lag` values. Defaults to `:day`.
    * `:work_time` - count only working time in durations (see `GanttEx.Calendar`).
      Defaults to `false`.
    * `:calendar` - the global calendar (a `GanttEx.Calendar` or its options).
      Defaults to Monday to Friday, 08:00-12:00 and 13:00-17:00.
    * `:calendars` - other calendars, referenced by the `:calendar_id` of tasks.
    * `:resize_snap` - with working time, where a start or an end edited onto
      a non-working day goes: `:extend` (the default) grows the task to the
      next working day, `:shrink` shrinks it to the previous one, as MS
      Project does. See `schedule/5`.
    * `:auto_types` - tasks with children become projects and projects without
      children become tasks, also after every mutation. Defaults to `false`.

  Dates are completed as follows: when both `:start_date` and `:end_date` are
  given the duration is computed (the end date wins over a given duration);
  with a start date and a duration the end date is computed; a lone start date
  gets a duration of 1. Milestones always end when they start.

  Tasks pointing to an unknown parent become root tasks and links pointing to
  unknown tasks are ignored.

      iex> {:ok, store} = GanttEx.Store.new([%{id: "a", start_date: "2025-02-01 09:00"}], [], duration_unit: :hour)
      iex> GanttEx.Store.get_task(store, "a").end_date
      ~N[2025-02-01 10:00:00]

      iex> GanttEx.Store.new([%{id: 1, start_date: ~D[2025-01-01]}, %{id: 1, start_date: ~D[2025-01-01]}])
      {:error, {:duplicate_id, :task, 1}}

      iex> GanttEx.Store.new([%{id: 1, text: "Undated"}])
      {:error, {:invalid_task, 1, {:missing, :start_date}}}

  With working time, a 2-day task starting on Friday ends on Tuesday, and a
  task starting on a weekend starts on Monday:

      iex> {:ok, store} = GanttEx.Store.new([%{id: 1, start_date: ~D[2025-01-10], duration: 2}, %{id: 2, start_date: ~D[2025-01-11], duration: 1}], [], work_time: true)
      iex> {GanttEx.Store.get_task(store, 1).end_date, GanttEx.Store.get_task(store, 2).start_date}
      {~N[2025-01-14 00:00:00], ~N[2025-01-13 00:00:00]}
  """
  @spec new([term()], [term()], keyword()) :: {:ok, t()} | {:error, error()}
  def new(tasks \\ [], links \\ [], opts \\ []) do
    with {:ok, base} <- base_store(opts),
         {:ok, tasks} <- cast_all(tasks, &Task.new/1, :task),
         {:ok, links} <- cast_all(links, &Link.new/1, :link),
         :ok <- unique_ids(tasks, :task),
         :ok <- unique_ids(links, :link),
         {:ok, tasks} <- schedule_all(tasks, base) do
      task_map = Map.new(tasks, &{&1.id, &1})
      {task_map, children} = build_tree(tasks, task_map)

      store = %{
        base
        | tasks: task_map,
          children: children,
          task_keys: Map.new(tasks, &{key(&1.id), &1.id})
      }

      with :ok <- check_reachable(store) do
        store =
          if store.auto_types, do: store |> retype(Map.keys(store.tasks)) |> elem(0), else: store

        store = rollup_all(store)

        with :ok <- check_dates(store) do
          {:ok, put_valid_links(store, links)}
        end
      end
    end
  end

  @doc """
  Like `new/3` but raises `ArgumentError` when the data is invalid.
  """
  @spec new!([term()], [term()], keyword()) :: t()
  def new!(tasks \\ [], links \\ [], opts \\ []) do
    case new(tasks, links, opts) do
      {:ok, store} -> store
      {:error, reason} -> raise ArgumentError, "invalid Gantt data: #{inspect(reason)}"
    end
  end

  defp cast_all(items, fun, kind) do
    Enum.reduce_while(items, {:ok, []}, fn item, {:ok, acc} ->
      case fun.(item) do
        {:ok, entity} -> {:cont, {:ok, [entity | acc]}}
        {:error, reason} -> {:halt, {:error, {:"invalid_#{kind}", id_of(item), reason}}}
      end
    end)
    |> case do
      {:ok, acc} -> {:ok, Enum.reverse(acc)}
      error -> error
    end
  end

  defp id_of(item) when is_list(item), do: Keyword.get(item, :id)
  defp id_of(item) when is_map(item), do: Map.get(item, :id) || Map.get(item, "id")
  defp id_of(_item), do: nil

  defp unique_ids(entities, kind) do
    entities
    |> Enum.reduce_while(MapSet.new(), fn %{id: id}, seen ->
      if MapSet.member?(seen, id),
        do: {:halt, {:error, {:duplicate_id, kind, id}}},
        else: {:cont, MapSet.put(seen, id)}
    end)
    |> case do
      {:error, _} = error -> error
      _seen -> :ok
    end
  end

  defp base_store(opts) do
    work_time = Keyword.get(opts, :work_time, false)
    resize_snap = Keyword.get(opts, :resize_snap, :extend)

    unless resize_snap in [:extend, :shrink],
      do: raise(ArgumentError, "invalid :resize_snap #{inspect(resize_snap)}")

    with {:ok, calendar} <- Calendar.new(Keyword.get(opts, :calendar) || []),
         {:ok, calendars} <- cast_calendars(Keyword.get(opts, :calendars, [])) do
      {:ok,
       %__MODULE__{
         duration_unit: Keyword.get(opts, :duration_unit, :day),
         work_time: work_time,
         calendar: if(work_time, do: calendar),
         calendars: calendars,
         auto_types: Keyword.get(opts, :auto_types, false),
         resize_snap: resize_snap
       }}
    end
  end

  defp cast_calendars(calendars) when is_map(calendars),
    do: calendars |> Map.values() |> cast_calendars()

  defp cast_calendars(calendars) do
    Enum.reduce_while(calendars, {:ok, %{}}, fn calendar, {:ok, acc} ->
      case Calendar.new(calendar) do
        {:ok, calendar} -> {:cont, {:ok, Map.put(acc, calendar.id, calendar)}}
        {:error, reason} -> {:halt, {:error, {:invalid_calendar, reason}}}
      end
    end)
  end

  defp schedule_all(tasks, store) do
    Enum.reduce_while(tasks, {:ok, []}, fn task, {:ok, acc} ->
      case schedule(task, store.duration_unit, [], calendar_for(store, task)) do
        {:ok, task} -> {:cont, {:ok, [task | acc]}}
        {:error, reason} -> {:halt, {:error, {:invalid_task, task.id, reason}}}
      end
    end)
    |> case do
      {:ok, acc} -> {:ok, Enum.reverse(acc)}
      error -> error
    end
  end

  defp build_tree(tasks, task_map) do
    {tasks, children} =
      Enum.map_reduce(tasks, %{nil => []}, fn task, children ->
        parent =
          if task.parent != task.id and Map.has_key?(task_map, task.parent),
            do: task.parent,
            else: nil

        {%{task | parent: parent}, Map.update(children, parent, [task.id], &[task.id | &1])}
      end)

    {Map.new(tasks, &{&1.id, &1}), Map.new(children, fn {k, ids} -> {k, Enum.reverse(ids)} end)}
  end

  defp check_reachable(store) do
    reachable = MapSet.new(descendant_ids(store, nil))

    case Enum.find(Map.keys(store.tasks), &(not MapSet.member?(reachable, &1))) do
      nil -> :ok
      id -> {:error, {:parent_cycle, id}}
    end
  end

  defp check_dates(store) do
    case Enum.find(tasks(store), &is_nil(&1.start_date)) do
      nil -> :ok
      task -> {:error, {:invalid_task, task.id, {:missing, :start_date}}}
    end
  end

  # Keeps the links `add_link/2` would accept when adding them one by one,
  # without rebuilding the graph for every link: the valid links usually have
  # no cycle, so all of them are kept at once.
  defp put_valid_links(store, links) do
    {candidates, _seen} =
      Enum.flat_map_reduce(links, MapSet.new(), fn link, seen ->
        dependency = {link.source, link.target, link.type}

        if link.source == link.target or not Map.has_key?(store.tasks, link.source) or
             not Map.has_key?(store.tasks, link.target) or MapSet.member?(seen, dependency),
           do: {[], seen},
           else: {[link], MapSet.put(seen, dependency)}
      end)

    links = if acyclic?(candidates), do: candidates, else: drop_cycles(candidates)

    %{
      store
      | links: Map.new(links, &{&1.id, &1}),
        link_keys: Map.new(links, &{key(&1.id), &1.id}),
        link_order: Enum.map(links, & &1.id)
    }
  end

  defp acyclic?(links) do
    graph = Enum.group_by(links, & &1.source, & &1.target)
    pending = Enum.frequencies_by(links, & &1.target)
    roots = graph |> Map.keys() |> Enum.reject(&Map.has_key?(pending, &1))
    peel(roots, graph, pending, 0) == length(links)
  end

  # Kahn's algorithm: counts the links left behind by tasks without pending
  # predecessors. Links in or after a cycle are never counted.
  defp peel([], _graph, _pending, count), do: count

  defp peel([node | rest], graph, pending, count) do
    targets = Map.get(graph, node, [])

    {ready, pending} =
      Enum.flat_map_reduce(targets, pending, fn target, pending ->
        case Map.fetch!(pending, target) do
          1 -> {[target], Map.delete(pending, target)}
          left -> {[], Map.put(pending, target, left - 1)}
        end
      end)

    peel(ready ++ rest, graph, pending, count + length(targets))
  end

  # Adds the links one by one, dropping the ones that close a cycle.
  defp drop_cycles(links) do
    {kept, _graph} =
      Enum.reduce(links, {[], %{}}, fn link, {kept, graph} ->
        if do_reachable?(graph, [link.target], link.source, MapSet.new()),
          do: {kept, graph},
          else:
            {[link | kept], Map.update(graph, link.source, [link.target], &[link.target | &1])}
      end)

    Enum.reverse(kept)
  end

  # -- scheduling --------------------------------------------------------------

  @doc """
  Completes the dates of a single task for the given duration unit.

      iex> task = GanttEx.Task.new!(id: 1, start_date: ~D[2025-01-01], duration: 2)
      iex> {:ok, task} = GanttEx.Store.schedule(task, :day)
      iex> task.end_date
      ~N[2025-01-03 00:00:00]

      iex> task = GanttEx.Task.new!(id: 1, start_date: ~D[2025-01-05], end_date: ~D[2025-01-01])
      iex> GanttEx.Store.schedule(task, :day)
      {:error, {:invalid, :end_date}}

  `changed` holds the fields just edited, which decide what gives way: a
  new start alone moves the task (the duration stays), a new end resizes
  it, a new duration or calendar moves the end.

  With a calendar, a start alone that falls on a non-working day goes
  forward to the next working day. With the `:day` unit, an edited end on a
  non-working day, or a start edited together with the end (resizing the
  start), snap as `opts[:resize_snap]` says:

    * `:extend` (the default) - the task grows: an end on Saturday goes to
      the end of Monday, a start on Sunday to the start of Friday
    * `:shrink` - the task shrinks, as MS Project does: the end goes back to
      the end of Friday, the start forward to Monday

  For example, stretching the end of a task that starts on Thursday over
  Saturday (the end date is exclusive: Sunday at 00:00):

      iex> calendar = GanttEx.Calendar.new!()
      iex> task = GanttEx.Task.new!(id: 1, start_date: ~D[2025-01-09], end_date: ~D[2025-01-12])
      iex> {:ok, extended} = GanttEx.Store.schedule(task, :day, [:end_date], calendar)
      iex> {extended.end_date, extended.duration}
      {~N[2025-01-14 00:00:00], 3}
      iex> {:ok, shrunk} = GanttEx.Store.schedule(task, :day, [:end_date], calendar, resize_snap: :shrink)
      iex> {shrunk.end_date, shrunk.duration}
      {~N[2025-01-11 00:00:00], 2}

  And its start, back to Sunday:

      iex> calendar = GanttEx.Calendar.new!()
      iex> task = GanttEx.Task.new!(id: 1, start_date: ~D[2025-01-12], end_date: ~D[2025-01-16])
      iex> {:ok, extended} = GanttEx.Store.schedule(task, :day, [:start_date, :end_date], calendar)
      iex> {extended.start_date, extended.duration}
      {~N[2025-01-10 00:00:00], 4}
      iex> {:ok, shrunk} = GanttEx.Store.schedule(task, :day, [:start_date, :end_date], calendar, resize_snap: :shrink)
      iex> {shrunk.start_date, shrunk.duration}
      {~N[2025-01-13 00:00:00], 3}
  """
  @spec schedule(Task.t(), Dates.unit(), [atom()], Calendar.t() | nil, keyword()) ::
          {:ok, Task.t()} | {:error, Task.error()}
  def schedule(task, unit, changed \\ [], calendar \\ nil, opts \\ [])

  def schedule(%Task{type: :milestone} = task, unit, _changed, calendar, _opts) do
    start = snap_start(task.start_date || task.end_date, unit, calendar)
    {:ok, %{task | start_date: start, end_date: start, duration: 0}}
  end

  def schedule(%Task{} = task, unit, changed, calendar, opts) do
    %Task{start_date: start, end_date: finish, duration: duration} = task
    add = fn datetime, amount -> add_time(calendar, datetime, amount, unit) end
    snap = Keyword.get(opts, :resize_snap, :extend)

    start =
      cond do
        :end_date in changed and :start_date not in changed -> start
        :end_date in changed -> snap_resized_start(start, unit, calendar, snap)
        true -> snap_start(start, unit, calendar)
      end

    {start, finish, duration} =
      cond do
        is_nil(start) and is_nil(finish) ->
          {nil, nil, duration}

        is_nil(start) ->
          {add.(finish, -(duration || 1)), finish, duration || 1}

        is_nil(finish) or (:duration in changed and :end_date not in changed) ->
          duration = duration || 1
          {start, add.(start, duration), duration}

        :start_date in changed and :end_date not in changed and not is_nil(duration) ->
          {start, add.(start, duration), duration}

        :calendar_id in changed and :end_date not in changed and not is_nil(duration) ->
          {start, add.(start, duration), duration}

        true ->
          finish =
            if :end_date in changed,
              do: snap_end(finish, start, unit, calendar, snap),
              else: finish

          {start, finish, diff_time(calendar, start, finish, unit)}
      end

    if start && NaiveDateTime.compare(finish, start) == :lt do
      {:error, {:invalid, :end_date}}
    else
      {:ok, %{task | start_date: start, end_date: finish, duration: duration && max(duration, 0)}}
    end
  end

  defp snap_start(nil, _unit, _calendar), do: nil
  defp snap_start(start, _unit, nil), do: start
  defp snap_start(start, unit, calendar), do: Calendar.next_working(calendar, start, unit)

  # A start resized onto a non-working day: the start of the previous
  # working day when the task grows
  defp snap_resized_start(start, :day, %Calendar{} = calendar, :extend) when not is_nil(start) do
    if Calendar.working_day?(calendar, NaiveDateTime.to_date(start)),
      do: start,
      else: Calendar.add(calendar, start, -1, :day)
  end

  defp snap_resized_start(start, unit, calendar, _snap), do: snap_start(start, unit, calendar)

  # An end edited onto a non-working day (the last day of the task doesn't
  # work): the end of the next working day, or of the previous one when the
  # task shrinks, as long as it stays after the start
  defp snap_end(finish, start, :day, %Calendar{} = calendar, snap)
       when not is_nil(finish) and not is_nil(start) do
    last_day = finish |> Dates.add(-1, :minute) |> NaiveDateTime.to_date()

    cond do
      Calendar.working_day?(calendar, last_day) ->
        finish

      snap == :extend ->
        Calendar.add(calendar, finish, 1, :day)

      true ->
        shrunk = calendar |> Calendar.add(finish, -1, :day) |> Dates.add(1, :day)
        if NaiveDateTime.compare(shrunk, start) == :gt, do: shrunk, else: finish
    end
  end

  defp snap_end(finish, _start, _unit, _calendar, _snap), do: finish

  defp add_time(nil, datetime, amount, unit), do: Dates.add(datetime, amount, unit)

  defp add_time(calendar, datetime, amount, unit),
    do: Calendar.add(calendar, datetime, amount, unit)

  defp diff_time(nil, from, to, unit), do: Dates.diff(from, to, unit)
  defp diff_time(calendar, from, to, unit), do: Calendar.diff(calendar, from, to, unit)

  @doc """
  Returns the calendar that applies to `task` (its `:calendar_id`, or the
  global calendar), or `nil` when the store does not use working time.
  """
  @spec calendar_for(t(), Task.t() | nil) :: Calendar.t() | nil
  def calendar_for(%__MODULE__{work_time: false}, _task), do: nil
  def calendar_for(%__MODULE__{} = store, nil), do: store.calendar

  def calendar_for(%__MODULE__{} = store, %Task{calendar_id: id}),
    do: Map.get(store.calendars, id) || store.calendar

  @doc """
  Adds `amount` duration units to `datetime` for `task`, honoring its calendar.

      iex> store = GanttEx.Store.new!([], [], work_time: true)
      iex> GanttEx.Store.add_duration(store, nil, ~N[2025-01-10 00:00:00], 1)
      ~N[2025-01-11 00:00:00]
      iex> GanttEx.Store.add_duration(store, nil, ~N[2025-01-10 00:00:00], 2)
      ~N[2025-01-14 00:00:00]
  """
  @spec add_duration(t(), Task.t() | nil, NaiveDateTime.t(), number()) :: NaiveDateTime.t()
  def add_duration(%__MODULE__{} = store, task, datetime, amount),
    do: add_time(calendar_for(store, task), datetime, amount, store.duration_unit)

  @doc """
  Returns the duration between two datetimes for `task`, honoring its calendar.

      iex> store = GanttEx.Store.new!([], [], work_time: true)
      iex> GanttEx.Store.duration_between(store, nil, ~N[2025-01-10 00:00:00], ~N[2025-01-14 00:00:00])
      2
  """
  @spec duration_between(t(), Task.t() | nil, NaiveDateTime.t(), NaiveDateTime.t()) :: integer()
  def duration_between(%__MODULE__{} = store, task, from, to),
    do: diff_time(calendar_for(store, task), from, to, store.duration_unit)

  defp rollup_all(store) do
    Enum.reduce(post_order(store, nil), store, fn id, store -> rollup_one(store, id) end)
  end

  defp post_order(store, id) do
    Enum.flat_map(child_ids(store, id), &(post_order(store, &1) ++ [&1]))
  end

  defp rollup_one(store, id) do
    task = Map.fetch!(store.tasks, id)

    case {task.type, child_ids(store, id)} do
      {:project, [_ | _] = ids} ->
        children = Enum.map(ids, &Map.fetch!(store.tasks, &1))
        start = children |> Enum.map(& &1.start_date) |> Enum.reduce(nil, &Dates.min/2)
        finish = children |> Enum.map(& &1.end_date) |> Enum.reduce(nil, &Dates.max/2)
        duration = if start && finish, do: duration_between(store, task, start, finish)

        put_in(store.tasks[id], %{task | start_date: start, end_date: finish, duration: duration})

      _ ->
        store
    end
  end

  # With auto types, a task with children is a project and a project without
  # children is a task.
  defp retype(%__MODULE__{auto_types: false} = store, _ids), do: {store, []}

  defp retype(store, ids) do
    ids
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.reduce({store, []}, fn id, {store, changes} ->
      with %Task{} = task <- Map.get(store.tasks, id),
           type when type != task.type <- expected_type(store, task) do
        task = %{task | type: type}

        {put_in(store.tasks[id], task),
         changes ++ [{:task_updated, task, %{changes: %{type: type}}}]}
      else
        _ -> {store, changes}
      end
    end)
  end

  defp expected_type(store, task) do
    cond do
      has_children?(store, task.id) -> :project
      task.type == :project -> :task
      true -> task.type
    end
  end

  @doc """
  Merges repeated `:task_updated` changes of the same task, keeping the
  position of the first one and the last value.

      iex> a = GanttEx.Task.new!(id: 1, text: "A")
      iex> b = %{a | text: "B"}
      iex> GanttEx.Store.compact([{:task_updated, a, %{changes: %{start_date: 1}}}, {:task_updated, b, %{changes: %{end_date: 2}}}])
      [{:task_updated, b, %{changes: %{start_date: 1, end_date: 2}}}]
  """
  @spec compact([change()]) :: [change()]
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

  @doc """
  Recomputes the dates of the given projects and all their ancestors
  (deepest first) from their children, and reports the ones that changed.

      iex> store = GanttEx.Store.new!([%{id: 1, type: :project}, %{id: 2, parent: 1, start_date: ~D[2025-01-06], duration: 2}])
      iex> {:ok, store, _} = GanttEx.Store.update_task(store, 2, %{duration: 4}, rollup: false)
      iex> GanttEx.Store.get_task(store, 1).end_date
      ~N[2025-01-08 00:00:00]
      iex> {store, [{:task_updated, %{id: 1}, %{changes: changes}}]} = GanttEx.Store.rollup(store, [1])
      iex> {changes, GanttEx.Store.get_task(store, 1).end_date}
      {%{end_date: ~N[2025-01-10 00:00:00], duration: 4}, ~N[2025-01-10 00:00:00]}
  """
  @spec rollup(t(), [Task.id() | nil]) :: {t(), [change()]}
  def rollup(%__MODULE__{} = store, ids) do
    chain =
      ids
      |> Enum.reject(&is_nil/1)
      |> Enum.filter(&Map.has_key?(store.tasks, &1))
      |> Enum.flat_map(&[&1 | ancestor_ids(store, &1)])
      |> Enum.uniq()
      |> Enum.sort_by(&(-level(store, &1)))

    before = Map.take(store.tasks, chain)
    store = Enum.reduce(chain, store, &rollup_one(&2, &1))

    changes =
      for id <- chain,
          new = Map.fetch!(store.tasks, id),
          diff = field_changes(Map.fetch!(before, id), new, @date_fields),
          diff != %{},
          do: {:task_updated, new, %{changes: diff}}

    {store, changes}
  end

  # -- queries -----------------------------------------------------------------

  @doc """
  Converts an id into its string key (as used in DOM ids and client events).

      iex> GanttEx.Store.key(42)
      "42"

      iex> GanttEx.Store.key("a-1")
      "a-1"
  """
  @spec key(Task.id()) :: key()
  def key(id) when is_binary(id), do: id
  def key(id) when is_integer(id), do: Integer.to_string(id)
  def key(id) when is_atom(id), do: Atom.to_string(id)
  def key(id), do: inspect(id)

  @doc "Returns the duration unit of the store."
  @spec duration_unit(t()) :: Dates.unit()
  def duration_unit(%__MODULE__{duration_unit: unit}), do: unit

  @doc "Fetches a task by id."
  @spec fetch_task(t(), Task.id()) :: {:ok, Task.t()} | :error
  def fetch_task(%__MODULE__{tasks: tasks}, id), do: Map.fetch(tasks, id)

  @doc "Gets a task by id, or `nil`."
  @spec get_task(t(), Task.id()) :: Task.t() | nil
  def get_task(%__MODULE__{tasks: tasks}, id), do: Map.get(tasks, id)

  @doc """
  Gets a task by its string key (see `key/1`), or `nil`.

      iex> store = GanttEx.Store.new!([%{id: 7, start_date: ~D[2025-01-01]}])
      iex> GanttEx.Store.task_by_key(store, "7").id
      7
  """
  @spec task_by_key(t(), key()) :: Task.t() | nil
  def task_by_key(%__MODULE__{} = store, key) do
    case Map.fetch(store.task_keys, key) do
      {:ok, id} -> Map.get(store.tasks, id)
      :error -> nil
    end
  end

  @doc "Fetches a link by id."
  @spec fetch_link(t(), Task.id()) :: {:ok, Link.t()} | :error
  def fetch_link(%__MODULE__{links: links}, id), do: Map.fetch(links, id)

  @doc "Gets a link by id, or `nil`."
  @spec get_link(t(), Task.id()) :: Link.t() | nil
  def get_link(%__MODULE__{links: links}, id), do: Map.get(links, id)

  @doc "Gets a link by its string key, or `nil`."
  @spec link_by_key(t(), key()) :: Link.t() | nil
  def link_by_key(%__MODULE__{} = store, key) do
    case Map.fetch(store.link_keys, key) do
      {:ok, id} -> Map.get(store.links, id)
      :error -> nil
    end
  end

  @doc """
  Returns all tasks in tree order (depth first).

      iex> store = GanttEx.Store.new!([%{id: 2, parent: 1, start_date: ~D[2025-01-01]}, %{id: 1, start_date: ~D[2025-01-01]}, %{id: 3, start_date: ~D[2025-01-01]}])
      iex> store |> GanttEx.Store.tasks() |> Enum.map(& &1.id)
      [1, 2, 3]
  """
  @spec tasks(t()) :: [Task.t()]
  def tasks(%__MODULE__{} = store) do
    store |> descendant_ids(nil) |> Enum.map(&Map.fetch!(store.tasks, &1))
  end

  @doc "Returns all links in insertion order."
  @spec links(t()) :: [Link.t()]
  def links(%__MODULE__{} = store), do: Enum.map(store.link_order, &Map.fetch!(store.links, &1))

  @doc "Returns the number of tasks."
  @spec task_count(t()) :: non_neg_integer()
  def task_count(%__MODULE__{tasks: tasks}), do: map_size(tasks)

  @doc "Returns the ids of the direct children of `id` (`nil` for the root)."
  @spec child_ids(t(), Task.id() | nil) :: [Task.id()]
  def child_ids(%__MODULE__{children: children}, id), do: Map.get(children, id, [])

  @doc "Returns the direct children of `id` (`nil` for the root)."
  @spec children(t(), Task.id() | nil) :: [Task.t()]
  def children(%__MODULE__{} = store, id),
    do: store |> child_ids(id) |> Enum.map(&Map.fetch!(store.tasks, &1))

  @doc "Returns `true` if the task has children."
  @spec has_children?(t(), Task.id()) :: boolean()
  def has_children?(%__MODULE__{} = store, id), do: child_ids(store, id) != []

  @doc """
  Returns the ids of all descendants of `id`, depth first.

      iex> store = GanttEx.Store.new!([%{id: 1, start_date: ~D[2025-01-01]}, %{id: 2, parent: 1, start_date: ~D[2025-01-01]}, %{id: 3, parent: 2, start_date: ~D[2025-01-01]}])
      iex> GanttEx.Store.descendant_ids(store, 1)
      [2, 3]
  """
  @spec descendant_ids(t(), Task.id() | nil) :: [Task.id()]
  def descendant_ids(%__MODULE__{} = store, id) do
    Enum.flat_map(child_ids(store, id), &[&1 | descendant_ids(store, &1)])
  end

  @doc """
  Returns the ids of the ancestors of `id`, closest first.

      iex> store = GanttEx.Store.new!([%{id: 1, start_date: ~D[2025-01-01]}, %{id: 2, parent: 1, start_date: ~D[2025-01-01]}, %{id: 3, parent: 2, start_date: ~D[2025-01-01]}])
      iex> GanttEx.Store.ancestor_ids(store, 3)
      [2, 1]
  """
  @spec ancestor_ids(t(), Task.id()) :: [Task.id()]
  def ancestor_ids(%__MODULE__{} = store, id) do
    case get_task(store, id) do
      %Task{parent: nil} -> []
      %Task{parent: parent} -> [parent | ancestor_ids(store, parent)]
      nil -> []
    end
  end

  @doc "Returns the depth of a task (`0` for root tasks)."
  @spec level(t(), Task.id()) :: non_neg_integer()
  def level(%__MODULE__{} = store, id), do: length(ancestor_ids(store, id))

  @doc "Returns the position of a task among its siblings."
  @spec index(t(), Task.id()) :: non_neg_integer() | nil
  def index(%__MODULE__{} = store, id) do
    case get_task(store, id) do
      nil -> nil
      task -> Enum.find_index(child_ids(store, task.parent), &(&1 == id))
    end
  end

  @doc "Returns the links where the task is the source or the target."
  @spec links_for(t(), Task.id()) :: [Link.t()]
  def links_for(%__MODULE__{} = store, id) do
    store |> links() |> Enum.filter(&(&1.source == id or &1.target == id))
  end

  @doc """
  Returns `{earliest_start, latest_end}` across all tasks, or `nil` when empty.

      iex> store = GanttEx.Store.new!([%{id: 1, start_date: ~D[2025-01-03], duration: 2}, %{id: 2, start_date: ~D[2025-01-01], duration: 1}])
      iex> GanttEx.Store.date_range(store)
      {~N[2025-01-01 00:00:00], ~N[2025-01-05 00:00:00]}
  """
  @spec date_range(t()) :: {NaiveDateTime.t(), NaiveDateTime.t()} | nil
  def date_range(%__MODULE__{tasks: tasks}) when map_size(tasks) == 0, do: nil

  def date_range(%__MODULE__{tasks: tasks}) do
    Enum.reduce(Map.values(tasks), {nil, nil}, fn task, {min, max} ->
      {Dates.min(min, task.start_date), Dates.max(max, task.end_date)}
    end)
  end

  @doc """
  Returns the visible rows, in display order.

  ## Options

    * `:collapsed` - a `MapSet` of task ids whose children are hidden.
    * `:filter` - a 1-arity function; only matching tasks (and their ancestors,
      to keep the tree readable) are returned. Collapsed branches are expanded
      while filtering.
    * `:visible` - a `MapSet` of the ids of the tasks to show, such as the
      ones returned by `GanttEx.Filter.visible/4` (which include the
      ancestors). Expanded like `:filter`, and combined with it.
    * `:sort` - `{field, :asc | :desc}` to sort siblings by a task field or a
      `:meta` key. The tree structure is preserved.
    * `:group_by` - `{group_fun, label_fun}` to group tasks (projects with
      children excluded) under virtual group rows. `group_fun` returns the
      group of a task, a list of groups, or `nil`; `label_fun` returns the
      label of a group. Group rows have `group: true`, a virtual project task
      spanning its members and `count`; collapsed groups are identified by
      `{:group, value}` in `:collapsed`. Rows have a unique `uid`, as a task
      can appear in several groups.

  ## Examples

      iex> store = GanttEx.Store.new!([
      ...>   %{id: 1, text: "B", start_date: ~D[2025-01-01]},
      ...>   %{id: 2, text: "child", parent: 1, start_date: ~D[2025-01-01]},
      ...>   %{id: 3, text: "A", start_date: ~D[2025-01-01]}
      ...> ])
      iex> store |> GanttEx.Store.rows() |> Enum.map(&{&1.key, &1.level})
      [{"1", 0}, {"2", 1}, {"3", 0}]
      iex> store |> GanttEx.Store.rows(collapsed: MapSet.new([1])) |> Enum.map(& &1.key)
      ["1", "3"]
      iex> store |> GanttEx.Store.rows(sort: {:text, :asc}) |> Enum.map(& &1.task.text)
      ["A", "B", "child"]
      iex> store |> GanttEx.Store.rows(filter: &(&1.text == "child")) |> Enum.map(& &1.key)
      ["1", "2"]
      iex> store |> GanttEx.Store.rows(visible: MapSet.new([3])) |> Enum.map(& &1.key)
      ["3"]
  """
  @spec rows(t(), keyword()) :: [row()]
  def rows(%__MODULE__{} = store, opts \\ []) do
    filter = Keyword.get(opts, :filter)

    visible =
      case {filter && matching_with_ancestors(store, filter), Keyword.get(opts, :visible)} do
        {nil, visible} -> visible
        {matching, nil} -> matching
        {matching, visible} -> MapSet.intersection(matching, visible)
      end

    collapsed =
      if visible, do: MapSet.new(), else: Keyword.get(opts, :collapsed, MapSet.new())

    ctx = %{
      store: store,
      visible: visible,
      collapsed: collapsed,
      sort: Keyword.get(opts, :sort),
      wbs: wbs_codes(store)
    }

    case Keyword.get(opts, :group_by) do
      nil ->
        {rows, _index} = walk_rows(ctx, nil, nil, 0, {[], 0})
        Enum.reverse(rows)

      {group_fun, label_fun} ->
        grouped_rows(ctx, group_fun, label_fun)
    end
  end

  defp grouped_rows(ctx, group_fun, label_fun) do
    store = ctx.store

    members =
      for task <- tasks(store),
          not (task.type == :project and has_children?(store, task.id)),
          is_nil(ctx.visible) or MapSet.member?(ctx.visible, task.id),
          group <- List.wrap(group_fun.(task) || [nil]),
          do: {group, task}

    groups = members |> Enum.map(&elem(&1, 0)) |> Enum.uniq()

    {rows, _index} =
      Enum.reduce(groups, {[], 0}, fn group, {rows, index} ->
        tasks = for {^group, task} <- members, do: task
        tasks = sort_siblings(tasks, ctx.sort)
        id = {:group, group}
        group_key = "g:" <> if(is_nil(group), do: "none", else: key(group))
        open = not MapSet.member?(ctx.collapsed, id)

        header = %{
          task: group_task(id, label_fun.(group), tasks, store),
          key: group_key,
          uid: group_key,
          index: index,
          level: 0,
          parent_key: nil,
          has_children: true,
          open: open,
          wbs: "",
          group: true,
          count: length(tasks)
        }

        acc = {[header | rows], index + 1}

        if open do
          Enum.reduce(tasks, acc, fn task, {rows, index} ->
            key = key(task.id)

            row = %{
              task: task,
              key: key,
              uid: group_key <> "/" <> key,
              index: index,
              level: 1,
              parent_key: group_key,
              has_children: false,
              open: false,
              wbs: Map.fetch!(ctx.wbs, task.id),
              group: false,
              count: nil
            }

            {[row | rows], index + 1}
          end)
        else
          acc
        end
      end)

    Enum.reverse(rows)
  end

  defp group_task(id, label, tasks, store) do
    start = tasks |> Enum.map(& &1.start_date) |> Enum.reduce(nil, &Dates.min/2)
    finish = tasks |> Enum.map(& &1.end_date) |> Enum.reduce(nil, &Dates.max/2)

    %Task{
      id: id,
      text: to_string(label),
      type: :project,
      start_date: start,
      end_date: finish,
      duration: if(start && finish, do: Dates.diff(start, finish, store.duration_unit), else: 0),
      readonly: true
    }
  end

  defp walk_rows(ctx, parent, parent_key, level, acc) do
    ctx.store
    |> children(parent)
    |> sort_siblings(ctx.sort)
    |> Enum.reduce(acc, fn task, {rows, index} ->
      if ctx.visible && not MapSet.member?(ctx.visible, task.id) do
        {rows, index}
      else
        key = key(task.id)
        loaded = has_children?(ctx.store, task.id)
        # `has_children: true` marks a branch whose children are not loaded yet
        has_children = loaded or task.has_children
        open = loaded and not MapSet.member?(ctx.collapsed, task.id)

        row = %{
          task: task,
          key: key,
          index: index,
          level: level,
          parent_key: parent_key,
          has_children: has_children,
          open: open,
          wbs: Map.fetch!(ctx.wbs, task.id),
          uid: key,
          group: false,
          count: nil
        }

        acc = {[row | rows], index + 1}
        if open, do: walk_rows(ctx, task.id, key, level + 1, acc), else: acc
      end
    end)
  end

  @doc """
  Returns the WBS code (outline number) of every task, such as `"1.2.3"`.

  Codes follow the order of the tree, whatever the sorting or filtering of
  the rows.

      iex> store = GanttEx.Store.new!([%{id: 1, start_date: ~D[2025-01-01]}, %{id: 2, parent: 1, start_date: ~D[2025-01-01]}, %{id: 3, parent: 1, start_date: ~D[2025-01-01]}, %{id: 4, start_date: ~D[2025-01-01]}])
      iex> GanttEx.Store.wbs_codes(store)
      %{1 => "1", 2 => "1.1", 3 => "1.2", 4 => "2"}
  """
  @spec wbs_codes(t()) :: %{Task.id() => String.t()}
  def wbs_codes(%__MODULE__{} = store), do: wbs_codes(store, nil, "", %{})

  # One map for the whole walk: merging the maps of every branch is quadratic
  # in the number of children of a summary task
  defp wbs_codes(store, parent, prefix, acc) do
    store
    |> child_ids(parent)
    |> Enum.with_index(1)
    |> Enum.reduce(acc, fn {id, index}, acc ->
      code = prefix <> Integer.to_string(index)
      wbs_codes(store, id, code <> ".", Map.put(acc, id, code))
    end)
  end

  # Each ancestor is added once: the walk stops at the first one already in.
  defp matching_with_ancestors(store, filter) do
    Enum.reduce(store.tasks, MapSet.new(), fn {_id, task}, set ->
      if filter.(task), do: put_with_ancestors(store, task.id, set), else: set
    end)
  end

  defp put_with_ancestors(_store, nil, set), do: set

  defp put_with_ancestors(store, id, set) do
    if MapSet.member?(set, id),
      do: set,
      else: put_with_ancestors(store, store.tasks[id].parent, MapSet.put(set, id))
  end

  defp sort_siblings(tasks, nil), do: tasks

  defp sort_siblings(tasks, {field, direction}) do
    Enum.sort_by(tasks, &sort_value(&1, field), sorter(direction))
  end

  defp sort_value(task, field) do
    value =
      if Map.has_key?(task, field), do: Map.get(task, field), else: Map.get(task.meta, field)

    case value do
      nil -> {1, nil}
      %NaiveDateTime{} = dt -> {0, Dates.to_seconds(dt)}
      value when is_binary(value) -> {0, String.downcase(value)}
      value -> {0, value}
    end
  end

  # nils always last, whatever the direction
  defp sorter(:asc), do: fn {na, a}, {nb, b} -> {na, a} <= {nb, b} end
  defp sorter(:desc), do: fn {na, a}, {nb, b} -> na < nb or (na == nb and a >= b) end

  # -- task mutations ----------------------------------------------------------

  @doc """
  Adds a task. The parent is taken from the task's `:parent` field.

  ## Options

    * `:index` - position among its siblings. Defaults to appending.

  ## Examples

      iex> store = GanttEx.Store.new!([%{id: 1, type: :project, start_date: ~D[2025-01-01]}])
      iex> {:ok, store, changes} = GanttEx.Store.add_task(store, %{id: 2, parent: 1, start_date: ~D[2025-01-02], duration: 4})
      iex> Enum.map(changes, fn {type, task, _} -> {type, task.id} end)
      [task_created: 2, task_updated: 1]
      iex> GanttEx.Store.add_task(store, %{id: 3, parent: 99, start_date: ~D[2025-01-01]})
      {:error, :missing_parent}
  """
  @spec add_task(t(), term(), keyword()) :: {:ok, t(), [change()]} | {:error, error()}
  def add_task(%__MODULE__{} = store, attrs, opts \\ []) do
    with {:ok, task} <- Task.new(attrs),
         :ok <- check_new_id(store.tasks, task.id, :task),
         :ok <- check_parent_exists(store, task.parent),
         {:ok, task} <- schedule(task, store.duration_unit, [], calendar_for(store, task)) do
      store = %{
        store
        | tasks: Map.put(store.tasks, task.id, task),
          task_keys: Map.put(store.task_keys, key(task.id), task.id),
          children:
            Map.update(
              store.children,
              task.parent,
              [task.id],
              &insert_at(&1, task.id, opts[:index])
            )
      }

      {store, retyped} = retype(store, [task.parent])
      {store, rollups} = rollup(store, [task.parent])

      {:ok, store,
       [{:task_created, Map.fetch!(store.tasks, task.id), %{}} | compact(retyped ++ rollups)]}
    end
  end

  @doc """
  Updates a task with the given attributes.

  Dates are kept consistent: changing only the start moves the task (the
  duration is kept), changing the end or the duration resizes it. Changing
  `:parent` moves the task to the end of its new parent.

  ## Options

    * `:rollup` - recompute the dates of the ancestor projects. Defaults to
      `true`. When updating many tasks, pass `false` and call `rollup/2` with
      their parents once at the end.

      iex> store = GanttEx.Store.new!([%{id: 1, start_date: ~D[2025-01-01], duration: 2}])
      iex> {:ok, store, [{:task_updated, task, %{changes: changes}}]} = GanttEx.Store.update_task(store, 1, %{start_date: ~D[2025-01-10]})
      iex> {task.end_date, changes}
      {~N[2025-01-12 00:00:00], %{start_date: ~N[2025-01-10 00:00:00], end_date: ~N[2025-01-12 00:00:00]}}
      iex> GanttEx.Store.update_task(store, 1, %{end_date: ~D[2024-01-01]})
      {:error, {:invalid, :end_date}}
  """
  @spec update_task(t(), Task.id(), map() | keyword(), keyword()) ::
          {:ok, t(), [change()]} | {:error, error()}
  def update_task(%__MODULE__{} = store, id, attrs, opts \\ []) do
    {known, _meta} = Task.split(attrs)

    with {:ok, old} <- fetch(store.tasks, id),
         {:ok, changed} <- Task.change(old, Map.delete(known, :parent) |> merge_meta(attrs)),
         {:ok, changed} <-
           schedule(changed, store.duration_unit, Map.keys(known), calendar_for(store, changed),
             resize_snap: store.resize_snap
           ) do
      store = put_in(store.tasks[id], changed)

      {store, move_changes} =
        case Map.fetch(known, :parent) do
          {:ok, parent} when parent != old.parent -> move_for_update(store, id, parent)
          _ -> {store, []}
        end

      new = Map.fetch!(store.tasks, id)

      {store, rollups} =
        if Keyword.get(opts, :rollup, true), do: rollup(store, [new.parent]), else: {store, []}

      changes =
        case field_changes(old, %{new | parent: old.parent}, nil) do
          diff when diff == %{} -> []
          diff -> [{:task_updated, new, %{changes: diff}}]
        end

      {:ok, store, changes ++ move_changes ++ rollups}
    end
  end

  defp merge_meta(known, attrs) do
    {_known, meta} = Task.split(attrs)
    Map.put(known, :meta, meta)
  end

  defp move_for_update(store, id, parent) do
    case move_task(store, id, Task.new!(id: id, parent: parent).parent, nil) do
      {:ok, store, changes} -> {store, changes}
      {:error, _} -> {store, []}
    end
  end

  @doc """
  Replaces existing tasks with new data, as `new/3` would read it, without
  rebuilding the store: the cheap way to apply the changes made elsewhere
  (another user, another tab) to a large chart. The parent projects of the
  replaced tasks get their dates rolled up again.

  The tasks must already be in the store and keep their parent; otherwise
  it returns `{:error, :structure_changed}` and the store has to be built
  again with `new/3`.

      iex> store = GanttEx.Store.new!([%{id: 1, type: :project}, %{id: 2, parent: 1, start_date: ~D[2025-01-06], duration: 2}])
      iex> {:ok, store} = GanttEx.Store.put_tasks(store, [%{id: 2, parent: 1, start_date: ~D[2025-01-08], duration: 3, progress: 0.5}])
      iex> {GanttEx.Store.get_task(store, 2).progress, GanttEx.Store.get_task(store, 1).end_date}
      {0.5, ~N[2025-01-11 00:00:00]}
      iex> GanttEx.Store.put_tasks(store, [%{id: 2, start_date: ~D[2025-01-08]}])
      {:error, :structure_changed}
  """
  @spec put_tasks(t(), [term()]) :: {:ok, t()} | {:error, error() | :structure_changed}
  def put_tasks(%__MODULE__{} = store, items) do
    with {:ok, tasks} <- cast_all(items, &Task.new/1, :task),
         {:ok, tasks} <- schedule_all(tasks, store),
         :ok <- same_places(store, tasks) do
      ids = Enum.map(tasks, & &1.id)

      store =
        Enum.reduce(
          tasks,
          store,
          &put_in(&2.tasks[&1.id], %{&1 | parent: resolve_parent(&2, &1)})
        )

      {store, _changes} = retype(store, ids)
      {store, _changes} = rollup(store, ids)

      case Enum.find(tasks, &is_nil(&1.start_date)) do
        nil -> {:ok, store}
        task -> {:error, {:invalid_task, task.id, {:missing, :start_date}}}
      end
    end
  end

  # Every task is known and keeps its parent (as `new/3` resolves it)
  defp same_places(store, tasks) do
    if Enum.all?(tasks, fn task ->
         case Map.fetch(store.tasks, task.id) do
           {:ok, old} -> old.parent == resolve_parent(store, task)
           :error -> false
         end
       end),
       do: :ok,
       else: {:error, :structure_changed}
  end

  defp resolve_parent(store, task) do
    if task.parent != task.id and Map.has_key?(store.tasks, task.parent), do: task.parent
  end

  @doc """
  Deletes a task with all its descendants and every link attached to them.

  Changes are reported links first, then tasks from the deepest descendant up
  to the deleted task, then the updated parent projects.

      iex> store = GanttEx.Store.new!(
      ...>   [%{id: 1, start_date: ~D[2025-01-01]}, %{id: 2, parent: 1, start_date: ~D[2025-01-01]}, %{id: 3, start_date: ~D[2025-01-01]}],
      ...>   [%{id: 10, source: 2, target: 3}]
      ...> )
      iex> {:ok, store, changes} = GanttEx.Store.delete_task(store, 1)
      iex> Enum.map(changes, fn {type, entity, _} -> {type, entity.id} end)
      [link_deleted: 10, task_deleted: 2, task_deleted: 1]
      iex> GanttEx.Store.task_count(store)
      1
  """
  @spec delete_task(t(), Task.id()) :: {:ok, t(), [change()]} | {:error, error()}
  def delete_task(%__MODULE__{} = store, id) do
    with {:ok, task} <- fetch(store.tasks, id) do
      ids = [id | descendant_ids(store, id)]
      id_set = MapSet.new(ids)

      links =
        store
        |> links()
        |> Enum.filter(&(MapSet.member?(id_set, &1.source) or MapSet.member?(id_set, &1.target)))

      link_ids = Enum.map(links, & &1.id)
      deleted = ids |> Enum.reverse() |> Enum.map(&Map.fetch!(store.tasks, &1))

      store = %{
        store
        | tasks: Map.drop(store.tasks, ids),
          task_keys: Map.drop(store.task_keys, Enum.map(ids, &key/1)),
          children:
            store.children
            |> Map.drop(ids)
            |> Map.update(task.parent, [], &List.delete(&1, id)),
          links: Map.drop(store.links, link_ids),
          link_keys: Map.drop(store.link_keys, Enum.map(link_ids, &key/1)),
          link_order: store.link_order -- link_ids
      }

      {store, retyped} = retype(store, [task.parent])
      {store, rollups} = rollup(store, [task.parent])

      changes =
        Enum.map(links, &{:link_deleted, &1, %{}}) ++
          Enum.map(deleted, &{:task_deleted, &1, %{}}) ++ compact(retyped ++ rollups)

      {:ok, store, changes}
    end
  end

  @doc """
  Moves a task under `parent` (`nil` for the root) at `index` among its new
  siblings (`nil` appends). A task cannot be moved inside itself or one of its
  descendants.

      iex> store = GanttEx.Store.new!([%{id: 1, start_date: ~D[2025-01-01]}, %{id: 2, start_date: ~D[2025-01-01]}, %{id: 3, start_date: ~D[2025-01-01]}])
      iex> {:ok, store, [{:task_moved, _task, details}]} = GanttEx.Store.move_task(store, 3, nil, 0)
      iex> details
      %{parent: nil, index: 0, siblings: [3, 1, 2]}
      iex> {:ok, store, _} = GanttEx.Store.move_task(store, 2, 1, nil)
      iex> GanttEx.Store.move_task(store, 1, 2, nil)
      {:error, :invalid_parent}
  """
  @spec move_task(t(), Task.id(), Task.id() | nil, non_neg_integer() | nil) ::
          {:ok, t(), [change()]} | {:error, error()}
  def move_task(%__MODULE__{} = store, id, parent, index) do
    with {:ok, task} <- fetch(store.tasks, id),
         :ok <- check_parent_exists(store, parent),
         :ok <- check_not_descendant(store, id, parent) do
      old_siblings = child_ids(store, task.parent)
      children = Map.update!(store.children, task.parent, &List.delete(&1, id))
      new_siblings = children |> Map.get(parent, []) |> insert_at(id, index)

      if parent == task.parent and new_siblings == old_siblings do
        {:ok, store, []}
      else
        store = %{
          store
          | tasks: Map.put(store.tasks, id, %{task | parent: parent}),
            children: Map.put(children, parent, new_siblings)
        }

        {store, retyped} = retype(store, [task.parent, parent])
        {store, rollups} = rollup(store, [task.parent, parent])
        rollups = compact(retyped ++ rollups)

        moved =
          {:task_moved, Map.fetch!(store.tasks, id),
           %{
             parent: parent,
             index: Enum.find_index(new_siblings, &(&1 == id)),
             siblings: new_siblings
           }}

        {:ok, store, [moved | rollups]}
      end
    end
  end

  # -- link mutations ----------------------------------------------------------

  @doc """
  Returns why a link cannot be added, or `nil` when it is valid.

  A link is rejected when it connects a task to itself, references a missing
  task, duplicates an existing dependency between the same tasks, or would
  create a circular dependency.

      iex> store = GanttEx.Store.new!([%{id: 1, start_date: ~D[2025-01-01]}, %{id: 2, start_date: ~D[2025-01-01]}], [%{id: 1, source: 1, target: 2}])
      iex> GanttEx.Store.link_error(store, GanttEx.Link.new!(id: 2, source: 2, target: 1))
      :cycle
      iex> GanttEx.Store.link_error(store, GanttEx.Link.new!(id: 2, source: 1, target: 1))
      :self_link
      iex> GanttEx.Store.link_error(store, GanttEx.Link.new!(id: 2, source: 1, target: 2))
      :duplicate_link
      iex> GanttEx.Store.link_error(store, GanttEx.Link.new!(id: 2, source: 1, target: 2, type: :start_to_start))
      nil
  """
  @spec link_error(t(), Link.t()) :: nil | :self_link | :missing_task | :duplicate_link | :cycle
  def link_error(%__MODULE__{} = store, %Link{} = link) do
    others = store |> links() |> Enum.reject(&(&1.id == link.id))

    cond do
      link.source == link.target ->
        :self_link

      not Map.has_key?(store.tasks, link.source) or not Map.has_key?(store.tasks, link.target) ->
        :missing_task

      Enum.any?(
        others,
        &(&1.source == link.source and &1.target == link.target and &1.type == link.type)
      ) ->
        :duplicate_link

      reachable?(others, link.target, link.source) ->
        :cycle

      true ->
        nil
    end
  end

  defp reachable?(links, from, to) do
    graph = Enum.group_by(links, & &1.source, & &1.target)
    do_reachable?(graph, [from], to, MapSet.new())
  end

  defp do_reachable?(_graph, [], _to, _seen), do: false
  defp do_reachable?(_graph, [to | _], to, _seen), do: true

  defp do_reachable?(graph, [node | rest], to, seen) do
    if MapSet.member?(seen, node) do
      do_reachable?(graph, rest, to, seen)
    else
      do_reachable?(graph, Map.get(graph, node, []) ++ rest, to, MapSet.put(seen, node))
    end
  end

  @doc """
  Adds a link.

      iex> store = GanttEx.Store.new!([%{id: 1, start_date: ~D[2025-01-01]}, %{id: 2, start_date: ~D[2025-01-01]}])
      iex> {:ok, store, [{:link_created, link, %{}}]} = GanttEx.Store.add_link(store, %{id: "l1", source: 1, target: 2})
      iex> link.type
      :finish_to_start
      iex> GanttEx.Store.add_link(store, %{id: "l2", source: 2, target: 1})
      {:error, :cycle}
  """
  @spec add_link(t(), term()) :: {:ok, t(), [change()]} | {:error, error()}
  def add_link(%__MODULE__{} = store, attrs) do
    with {:ok, link} <- Link.new(attrs),
         :ok <- check_new_id(store.links, link.id, :link),
         nil <- link_error(store, link) do
      {:ok, do_put_link(store, link), [{:link_created, link, %{}}]}
    else
      reason when is_atom(reason) -> {:error, reason}
      error -> error
    end
  end

  @doc """
  Updates the `:type`, `:lag`, `:readonly`, `:color` or meta fields of a link.

      iex> store = GanttEx.Store.new!([%{id: 1, start_date: ~D[2025-01-01]}, %{id: 2, start_date: ~D[2025-01-01]}], [%{id: 1, source: 1, target: 2}])
      iex> {:ok, _store, [{:link_updated, link, %{changes: changes}}]} = GanttEx.Store.update_link(store, 1, %{lag: 2})
      iex> {link.lag, changes}
      {2, %{lag: 2}}
  """
  @spec update_link(t(), Task.id(), map() | keyword()) ::
          {:ok, t(), [change()]} | {:error, error()}
  def update_link(%__MODULE__{} = store, id, attrs) do
    with {:ok, old} <- fetch(store.links, id),
         {:ok, link} <- Link.change(old, attrs),
         nil <- link_error(store, link) do
      case field_changes(old, link, nil) do
        diff when diff == %{} -> {:ok, store, []}
        diff -> {:ok, put_in(store.links[id], link), [{:link_updated, link, %{changes: diff}}]}
      end
    else
      reason when is_atom(reason) -> {:error, reason}
      error -> error
    end
  end

  @doc """
  Deletes a link.

      iex> store = GanttEx.Store.new!([%{id: 1, start_date: ~D[2025-01-01]}, %{id: 2, start_date: ~D[2025-01-01]}], [%{id: 1, source: 1, target: 2}])
      iex> {:ok, store, [{:link_deleted, _link, %{}}]} = GanttEx.Store.delete_link(store, 1)
      iex> GanttEx.Store.links(store)
      []
  """
  @spec delete_link(t(), Task.id()) :: {:ok, t(), [change()]} | {:error, error()}
  def delete_link(%__MODULE__{} = store, id) do
    with {:ok, link} <- fetch(store.links, id) do
      store = %{
        store
        | links: Map.delete(store.links, id),
          link_keys: Map.delete(store.link_keys, key(id)),
          link_order: List.delete(store.link_order, id)
      }

      {:ok, store, [{:link_deleted, link, %{}}]}
    end
  end

  # -- diffing -----------------------------------------------------------------

  @doc """
  Returns the changes that turn `old` into `new`, in an order that can be
  applied to a database: deleted links, deleted tasks (deepest first),
  created tasks (parents first), updated tasks, moved tasks, created links
  and updated links.

  `GanttEx.History` uses it to report what undo and redo change.

      iex> old = GanttEx.Store.new!([%{id: 1, start_date: ~D[2025-01-01]}, %{id: 2, start_date: ~D[2025-01-02]}], [%{id: 1, source: 1, target: 2}])
      iex> {:ok, new, _} = GanttEx.Store.delete_task(old, 2)
      iex> new |> GanttEx.Store.diff(old) |> Enum.map(fn {type, entity, _} -> {type, entity.id} end)
      [task_created: 2, link_created: 1]
      iex> old |> GanttEx.Store.diff(new) |> Enum.map(fn {type, entity, _} -> {type, entity.id} end)
      [link_deleted: 1, task_deleted: 2]
  """
  @spec diff(t(), t()) :: [change()]
  def diff(%__MODULE__{} = old, %__MODULE__{} = new) do
    deleted_tasks =
      old.tasks
      |> Map.values()
      |> Enum.reject(&Map.has_key?(new.tasks, &1.id))
      |> Enum.sort_by(&(-level(old, &1.id)))
      |> Enum.map(&{:task_deleted, &1, %{}})

    created_tasks =
      new
      |> tasks()
      |> Enum.reject(&Map.has_key?(old.tasks, &1.id))
      |> Enum.map(&{:task_created, &1, %{}})

    common = new |> tasks() |> Enum.filter(&Map.has_key?(old.tasks, &1.id))

    updated_tasks =
      for task <- common,
          before = Map.fetch!(old.tasks, task.id),
          changes = field_changes(before, %{task | parent: before.parent}, nil),
          changes != %{},
          do: {:task_updated, task, %{changes: changes}}

    {deleted_links, created_links, updated_links} = diff_links(old, new)

    deleted_links ++
      deleted_tasks ++
      created_tasks ++
      updated_tasks ++ moved_tasks(old, new, common) ++ created_links ++ updated_links
  end

  # A task moved when its parent changed; a reordered branch reports its first
  # out-of-place task (the siblings list carries the whole new order).
  defp moved_tasks(old, new, common) do
    reparented =
      for task <- common, Map.fetch!(old.tasks, task.id).parent != task.parent, do: task.id

    reordered =
      for {parent, ids} <- new.children,
          old_ids = child_ids(old, parent),
          Enum.sort(ids) == Enum.sort(old_ids) and ids != old_ids,
          id = ids |> Enum.zip(old_ids) |> Enum.find_value(fn {a, b} -> if a != b, do: a end),
          do: id

    (reparented ++ reordered)
    |> Enum.uniq()
    |> Enum.map(fn id ->
      task = Map.fetch!(new.tasks, id)
      siblings = child_ids(new, task.parent)

      {:task_moved, task,
       %{parent: task.parent, index: Enum.find_index(siblings, &(&1 == id)), siblings: siblings}}
    end)
  end

  defp diff_links(old, new) do
    deleted =
      for link <- links(old), not Map.has_key?(new.links, link.id), do: {:link_deleted, link, %{}}

    created =
      for link <- links(new), not Map.has_key?(old.links, link.id), do: {:link_created, link, %{}}

    updated =
      for link <- links(new),
          before = Map.get(old.links, link.id),
          before,
          changes = field_changes(before, link, nil),
          changes != %{},
          do: {:link_updated, link, %{changes: changes}}

    {deleted, created, updated}
  end

  # -- serialization -----------------------------------------------------------

  @doc """
  Returns the data in the DHTMLX JSON shape: `%{data: [task_map], links: [link_map]}`.

      iex> store = GanttEx.Store.new!([%{id: 1, text: "A", start_date: ~D[2025-01-01]}])
      iex> %{data: [task], links: []} = GanttEx.Store.to_data(store)
      iex> Map.take(task, [:id, :text, :duration])
      %{id: 1, text: "A", duration: 1}
  """
  @spec to_data(t()) :: %{data: [map()], links: [map()]}
  def to_data(%__MODULE__{} = store) do
    %{data: Enum.map(tasks(store), &Task.to_map/1), links: Enum.map(links(store), &Link.to_map/1)}
  end

  # -- helpers -----------------------------------------------------------------

  defp do_put_link(store, link) do
    %{
      store
      | links: Map.put(store.links, link.id, link),
        link_keys: Map.put(store.link_keys, key(link.id), link.id),
        link_order:
          if(Map.has_key?(store.links, link.id),
            do: store.link_order,
            else: store.link_order ++ [link.id]
          )
    }
  end

  defp fetch(map, id) do
    case Map.fetch(map, id) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, :not_found}
    end
  end

  defp check_new_id(map, id, kind) do
    if Map.has_key?(map, id), do: {:error, {:duplicate_id, kind, id}}, else: :ok
  end

  defp check_parent_exists(_store, nil), do: :ok

  defp check_parent_exists(store, parent) do
    if Map.has_key?(store.tasks, parent), do: :ok, else: {:error, :missing_parent}
  end

  defp check_not_descendant(_store, _id, nil), do: :ok

  defp check_not_descendant(store, id, parent) do
    if parent == id or id in ancestor_ids(store, parent),
      do: {:error, :invalid_parent},
      else: :ok
  end

  defp insert_at(list, item, nil), do: list ++ [item]
  defp insert_at(list, item, index), do: List.insert_at(list, max(index, 0), item)

  # Returns the fields (all struct fields but :id when `fields` is nil) that differ.
  defp field_changes(old, new, fields) do
    fields = fields || old |> Map.from_struct() |> Map.keys() |> List.delete(:id)

    for field <- fields,
        Map.get(old, field) != Map.get(new, field),
        into: %{},
        do: {field, Map.get(new, field)}
  end
end
