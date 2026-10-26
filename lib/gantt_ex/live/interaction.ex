defmodule GanttEx.Live.Interaction do
  @moduledoc """
  Translates user gestures into task and link attributes.

  `GanttEx.Live.Gantt` receives raw client values (pixels, strings) from the
  hook and from inline editors. This module turns them into validated
  attributes for `GanttEx.Store`, so the conversion rules can be tested on
  their own. Every function returns `nil` (or `:error`) for values that do
  not make sense, which the component simply ignores.
  """

  alias GanttEx.{Dates, Store, Task, TaskForm, Timeline}

  @typedoc "What the conversions need to know about the chart."
  @type context :: %{
          store: Store.t(),
          timeline: Timeline.t(),
          unit: Dates.unit(),
          week_start: 1..7
        }

  @doc """
  Returns the attributes that result from dragging a bar.

  `mode` is `"move"`, `"start"`, `"end"` (resizing) or `"progress"`.
  `params` holds the final `"x"` and `"width"` of the bar in pixels, or the
  `"progress"` between 0 and 1. Dates snap to the duration unit and a task
  keeps at least one unit. Project bars with children cannot be moved or
  resized: their dates come from their children.

      iex> store = GanttEx.Store.new!([%{id: 1, start_date: ~D[2025-01-06], duration: 3}])
      iex> timeline = GanttEx.Timeline.new(scales: [[unit: :day]], start_date: ~N[2025-01-01 00:00:00], end_date: ~N[2025-02-01 00:00:00], column_width: 40)
      iex> ctx = %{store: store, timeline: timeline, unit: :day, week_start: 1}
      iex> task = GanttEx.Store.get_task(store, 1)
      iex> GanttEx.Live.Interaction.drag_attrs(task, "move", %{"x" => 318, "width" => 120}, ctx)
      %{start_date: ~N[2025-01-09 00:00:00]}
      iex> GanttEx.Live.Interaction.drag_attrs(task, "end", %{"x" => 200, "width" => 2}, ctx)
      %{end_date: ~N[2025-01-07 00:00:00]}
      iex> GanttEx.Live.Interaction.drag_attrs(task, "progress", %{"progress" => "0.456"}, ctx)
      %{progress: 0.46}
      iex> GanttEx.Live.Interaction.drag_attrs(task, "fly", %{}, ctx)
      nil
  """
  @spec drag_attrs(Task.t(), String.t(), map(), context()) :: map() | nil
  def drag_attrs(%Task{} = task, mode, params, ctx) do
    x = number(params["x"])
    width = number(params["width"])
    summary = task.type == :project and Store.has_children?(ctx.store, task.id)

    case mode do
      "progress" when task.type != :milestone ->
        with progress when is_number(progress) <- number(params["progress"]) do
          %{progress: progress |> max(0) |> min(1) |> Kernel.*(100) |> round() |> Kernel./(100)}
        end

      "move" when is_number(x) and is_number(width) and not summary ->
        anchor = if task.type == :milestone, do: x + width / 2, else: x
        %{start_date: date_at(ctx, anchor)}

      "start" when is_number(x) and not summary ->
        latest = Dates.add(task.end_date, -1, ctx.unit)
        %{start_date: Dates.min(date_at(ctx, x), latest), end_date: task.end_date}

      "end" when is_number(x) and is_number(width) and not summary ->
        earliest = Dates.add(task.start_date, 1, ctx.unit)
        %{end_date: Dates.max(date_at(ctx, x + width), earliest)}

      _ ->
        nil
    end
  end

  @doc """
  Returns the snapped datetime at a horizontal position of the timeline.
  """
  @spec date_at(context(), number()) :: NaiveDateTime.t()
  def date_at(ctx, x) do
    ctx.timeline |> Timeline.date_at(x) |> Dates.round(ctx.unit, week_start: ctx.week_start)
  end

  @doc """
  Returns `{start, end}` for a task drawn on the timeline from `x` to
  `x + width`, lasting at least one unit.
  """
  @spec span_at(context(), number(), number()) :: {NaiveDateTime.t(), NaiveDateTime.t()}
  def span_at(ctx, x, width) do
    start = date_at(ctx, x)
    {start, Dates.max(date_at(ctx, x + width), Dates.add(start, 1, ctx.unit))}
  end

  @doc """
  Returns `{parent, index}` for dropping `task` `"before"`, `"after"` or
  `"inside"` the `target` row, or `nil` when the drop would put the task
  inside its own subtree.

      iex> store = GanttEx.Store.new!([%{id: 1, start_date: ~D[2025-01-01]}, %{id: 2, parent: 1, start_date: ~D[2025-01-01]}, %{id: 3, start_date: ~D[2025-01-01]}])
      iex> [one, two, three] = GanttEx.Store.tasks(store)
      iex> GanttEx.Live.Interaction.drop_position(store, three, two, "after")
      {1, 1}
      iex> GanttEx.Live.Interaction.drop_position(store, three, one, "before")
      {nil, 0}
      iex> GanttEx.Live.Interaction.drop_position(store, one, two, "inside")
      nil
  """
  @spec drop_position(Store.t(), Task.t(), Task.t(), String.t()) ::
          {Task.id() | nil, non_neg_integer() | nil} | nil
  def drop_position(store, task, target, "inside"), do: valid_drop(store, task, target.id, nil)

  def drop_position(store, task, target, position) when position in ["before", "after"] do
    siblings = Store.child_ids(store, target.parent) -- [task.id]
    index = Enum.find_index(siblings, &(&1 == target.id))
    valid_drop(store, task, target.parent, if(position == "before", do: index, else: index + 1))
  end

  def drop_position(_store, _task, _target, _position), do: nil

  defp valid_drop(store, task, parent, index) do
    if parent && (parent == task.id or task.id in Store.ancestor_ids(store, parent)),
      do: nil,
      else: {parent, index}
  end

  @doc """
  Returns the attributes for an inline edit of `column`, or `nil` when the
  value is invalid. Fields that are not task fields are stored in `:meta`,
  reusing the existing key type (atom or string).

      iex> task = GanttEx.Task.new!(id: 1, start_date: ~D[2025-01-06], owner: "Ana")
      iex> GanttEx.Live.Interaction.cell_attrs(%{field: :end_date}, "2025-01-08", task, :day)
      %{end_date: ~N[2025-01-09 00:00:00]}
      iex> GanttEx.Live.Interaction.cell_attrs(%{field: :progress}, "120", task, :day)
      nil
      iex> GanttEx.Live.Interaction.cell_attrs(%{field: :owner}, "Luis", task, :day)
      %{meta: %{owner: "Luis"}}
  """
  @spec cell_attrs(map(), term(), Task.t(), Dates.unit()) :: map() | nil
  def cell_attrs(%{field: :text}, value, _task, _unit) do
    case String.trim(to_string(value)) do
      "" -> nil
      text -> %{text: text}
    end
  end

  def cell_attrs(%{field: field}, value, _task, unit) when field in [:start_date, :end_date] do
    case Dates.cast(value) do
      {:ok, %NaiveDateTime{} = date} when field == :start_date -> %{start_date: date}
      {:ok, %NaiveDateTime{} = date} -> %{end_date: TaskForm.parse_end(date, unit)}
      _ -> nil
    end
  end

  def cell_attrs(%{field: :duration}, value, _task, _unit) do
    case Integer.parse(to_string(value)) do
      {duration, ""} when duration >= 0 -> %{duration: duration}
      _ -> nil
    end
  end

  def cell_attrs(%{field: :progress}, value, _task, _unit) do
    case Integer.parse(to_string(value)) do
      {percent, ""} when percent in 0..100 -> %{progress: percent / 100}
      _ -> nil
    end
  end

  def cell_attrs(%{field: :type}, value, _task, _unit) do
    case Task.cast_type(value) do
      {:ok, type} -> %{type: type}
      :error -> nil
    end
  end

  def cell_attrs(%{field: field}, value, task, _unit) do
    %{meta: %{meta_key(task.meta, field) => value}}
  end

  @doc """
  Converts the params of custom lightbox fields into meta attributes, reusing
  the key type already present in `meta`.

      iex> GanttEx.Live.Interaction.extra_params(%{"text" => "A", "owner" => "Ana", "_target" => "x"}, %{owner: nil})
      %{owner: "Ana"}
  """
  @spec extra_params(map(), map()) :: map()
  def extra_params(params, meta) do
    params
    |> Map.drop(~w(text type start_date duration progress parent))
    |> Enum.reject(fn {key, _} -> String.starts_with?(key, "_") end)
    |> Map.new(fn {key, value} -> {meta_key(meta, key), value} end)
  end

  defp meta_key(meta, key) when is_binary(key) do
    Enum.find(Map.keys(meta), key, &(is_atom(&1) and Atom.to_string(&1) == key))
  end

  defp meta_key(meta, key) when is_atom(key) do
    if not Map.has_key?(meta, key) and Map.has_key?(meta, Atom.to_string(key)),
      do: Atom.to_string(key),
      else: key
  end

  defp meta_key(_meta, key), do: key

  @doc """
  Casts a link edge sent by the client.

      iex> GanttEx.Live.Interaction.side("end")
      {:ok, :end}

      iex> GanttEx.Live.Interaction.side("middle")
      :error
  """
  @spec side(term()) :: {:ok, :start | :end} | :error
  def side("start"), do: {:ok, :start}
  def side("end"), do: {:ok, :end}
  def side(_side), do: :error

  @doc """
  Parses a number sent by the client.

      iex> GanttEx.Live.Interaction.number("12.5")
      12.5

      iex> GanttEx.Live.Interaction.number("12px")
      nil
  """
  @spec number(term()) :: number() | nil
  def number(value) when is_number(value), do: value

  def number(value) when is_binary(value) do
    case Float.parse(value) do
      {number, ""} -> number
      _ -> nil
    end
  end

  def number(_value), do: nil
end
