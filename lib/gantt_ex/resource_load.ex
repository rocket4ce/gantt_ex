defmodule GanttEx.ResourceLoad do
  @moduledoc """
  Computes how loaded each resource is, column by column of the timeline.

  For every column, the load of a resource is the sum, over the tasks
  assigned to it, of the assigned units per day multiplied by the days the
  task overlaps the column. The capacity is the resource capacity multiplied
  by the days of the column. With working time both only count working time,
  using the task calendars and the global calendar.

  An assignment without a value uses the whole capacity of the resource.

      iex> store = GanttEx.Store.new!([
      ...>   %{id: 1, start_date: ~D[2025-01-06], duration: 2, resources: [%{resource_id: "ana", value: 6}]},
      ...>   %{id: 2, start_date: ~D[2025-01-07], duration: 2, resources: ["ana"]}
      ...> ])
      iex> timeline = GanttEx.Timeline.new(scales: [[unit: :day]], start_date: ~N[2025-01-06 00:00:00], end_date: ~N[2025-01-10 00:00:00], column_width: 40)
      iex> [row] = GanttEx.ResourceLoad.compute(store, [%{id: "ana", text: "Ana"}], timeline)
      iex> Enum.map(row.cells, &{&1.start.day, &1.load, &1.overload})
      [{6, 6.0, false}, {7, 14.0, true}, {8, 8.0, false}]
      iex> row.overloaded
      true
  """

  alias GanttEx.{Calendar, Dates, Dependency, Resource, Store, Timeline}

  @typedoc "The load of a resource in one column (only columns with load are returned)."
  @type cell :: %{
          start: NaiveDateTime.t(),
          end: NaiveDateTime.t(),
          x: number(),
          width: number(),
          load: float(),
          capacity: float(),
          overload: boolean(),
          tasks: [GanttEx.Task.id()]
        }

  @type row :: %{resource: Resource.t(), cells: [cell()], overloaded: boolean()}

  @doc """
  Returns one row per resource, in the given order.
  """
  @spec compute(Store.t(), [term()], Timeline.t()) :: [row()]
  def compute(%Store{} = store, resources, %Timeline{} = timeline) do
    resources = Enum.map(resources, &Resource.new!/1)
    columns = Timeline.columns(timeline)

    assignments =
      for task <- Store.tasks(store),
          Dependency.schedulable?(store, task),
          task.type != :milestone,
          assignment <- task.resources,
          do: {assignment.id, task, assignment.value}

    by_resource = Enum.group_by(assignments, &elem(&1, 0), &Tuple.delete_at(&1, 0))

    for resource <- resources do
      items = Map.get(by_resource, resource.id, [])

      cells =
        for column <- columns,
            overlapping = Enum.filter(items, fn {task, _value} -> overlaps?(task, column) end),
            overlapping != [] do
          load =
            overlapping
            |> Enum.map(fn {task, value} ->
              (value || resource.capacity) *
                days(
                  store,
                  task,
                  Dates.max(task.start_date, column.start),
                  Dates.min(task.end_date, column.end)
                )
            end)
            |> Enum.sum()

          capacity = resource.capacity * days(store, nil, column.start, column.end)

          %{
            start: column.start,
            end: column.end,
            x: column.x,
            width: column.width,
            load: Float.round(load / 1, 2),
            capacity: Float.round(capacity / 1, 2),
            overload: load > capacity + 0.001,
            tasks: Enum.map(overlapping, fn {task, _} -> task.id end)
          }
        end

      %{resource: resource, cells: cells, overloaded: Enum.any?(cells, & &1.overload)}
    end
  end

  defp overlaps?(task, column) do
    NaiveDateTime.compare(task.start_date, column.end) == :lt and
      NaiveDateTime.compare(task.end_date, column.start) == :gt
  end

  # Days between two datetimes: working days (as a fraction of a full working
  # day) with working time, calendar days otherwise.
  defp days(store, task, from, to) do
    case Store.calendar_for(store, task) do
      nil ->
        max(NaiveDateTime.diff(to, from), 0) / 86_400

      calendar ->
        day_minutes = calendar.hours |> Enum.map(fn {a, b} -> b - a end) |> Enum.sum() |> max(1)
        max(Calendar.diff(calendar, from, to, :minute), 0) / day_minutes
    end
  end
end
