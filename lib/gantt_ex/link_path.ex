defmodule GanttEx.LinkPath do
  @moduledoc """
  Routes dependency arrows between two task bars.

  Links are drawn with orthogonal segments, like DHTMLX Gantt: the line leaves
  the source edge horizontally, travels vertically in a "lane" next to the
  bars and enters the target edge horizontally, ending with an arrow head.
  When the target edge is behind the source edge, the line detours through the
  boundary between rows.

  Boxes describe the *row* of each task: `x` and `width` of the bar, `y` (top
  of the row) and the `row_height`.

      iex> source = %{x: 0, width: 100, y: 0}
      iex> target = %{x: 150, width: 80, y: 36}
      iex> path = GanttEx.LinkPath.route(source, target, :finish_to_start, row_height: 36)
      iex> path.points
      [{100, 18.0}, {112, 18.0}, {112, 54.0}, {144, 54.0}]
      iex> path.d
      "M100 18L112 18L112 54L144 54"

      iex> source = %{x: 100, width: 100, y: 0}
      iex> target = %{x: 50, width: 40, y: 36}
      iex> GanttEx.LinkPath.route(source, target, :finish_to_start, row_height: 36).points
      [{200, 18.0}, {212, 18.0}, {212, 36}, {38, 36}, {38, 54.0}, {44, 54.0}]
  """

  alias GanttEx.Link

  @type point :: {number(), number()}
  @type box :: %{x: number(), width: number(), y: number()}
  @type t :: %{points: [point()], arrow: [point()], d: String.t(), arrow_d: String.t()}

  @doc """
  Computes the path of a link of `type` from `source` to `target`.

  ## Options

    * `:row_height` - height of a row in pixels. Defaults to `36`.
    * `:gap` - horizontal distance between a bar edge and the vertical lane. Defaults to `12`.
    * `:arrow` - size of the arrow head. Defaults to `6`.
  """
  @spec route(box(), box(), Link.type(), keyword()) :: t()
  def route(source, target, type, opts \\ []) do
    row_height = Keyword.get(opts, :row_height, 36)
    gap = Keyword.get(opts, :gap, 12)
    arrow = Keyword.get(opts, :arrow, 6)

    {from, to} = Link.sides(type)
    sx = if from == :end, do: source.x + source.width, else: source.x
    tx = if to == :start, do: target.x, else: target.x + target.width
    sy = source.y + row_height / 2
    ty = target.y + row_height / 2

    # direction of travel when leaving the source and when entering the target
    dir_s = if from == :end, do: 1, else: -1
    dir_t = if to == :start, do: 1, else: -1
    lane_s = sx + dir_s * gap
    lane_t = tx - dir_t * gap
    tip_base = tx - dir_t * arrow

    middle =
      cond do
        dir_s != dir_t ->
          lane = if dir_s == 1, do: max(lane_s, lane_t), else: min(lane_s, lane_t)
          [{lane, sy}, {lane, ty}]

        (lane_t - lane_s) * dir_s >= 0 ->
          [{lane_s, sy}, {lane_s, ty}]

        true ->
          boundary = if ty > sy, do: source.y + row_height, else: source.y
          [{lane_s, sy}, {lane_s, boundary}, {lane_t, boundary}, {lane_t, ty}]
      end

    points = dedup([{sx, sy} | middle] ++ [{tip_base, ty}])
    arrow_points = [{tx, ty}, {tip_base, ty - arrow * 0.75}, {tip_base, ty + arrow * 0.75}]

    %{points: points, arrow: arrow_points, d: to_d(points), arrow_d: to_d(arrow_points) <> "Z"}
  end

  @doc """
  Converts points into an SVG path.

      iex> GanttEx.LinkPath.to_d([{0, 0}, {10.25, 5}])
      "M0 0L10.3 5"
  """
  @spec to_d([point()]) :: String.t()
  def to_d([{x, y} | rest]) do
    Enum.reduce(rest, "M#{format_number(x)} #{format_number(y)}", fn {x, y}, acc ->
      acc <> "L#{format_number(x)} #{format_number(y)}"
    end)
  end

  @doc """
  Formats a coordinate with at most one decimal.

      iex> GanttEx.LinkPath.format_number(12.0)
      "12"

      iex> GanttEx.LinkPath.format_number(12.34)
      "12.3"
  """
  @spec format_number(number()) :: String.t()
  def format_number(value) when is_integer(value), do: Integer.to_string(value)

  def format_number(value) when is_float(value) do
    rounded = Float.round(value, 1)

    if rounded == Float.round(rounded),
      do: Integer.to_string(trunc(rounded)),
      else: Float.to_string(rounded)
  end

  defp dedup(points) do
    points
    |> Enum.chunk_by(& &1)
    |> Enum.map(&hd/1)
  end
end
