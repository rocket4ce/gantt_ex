defmodule GanttEx.Zoom do
  @moduledoc """
  Zoom levels: named combinations of scales and column width.

  Levels are ordered from the most detailed to the least detailed. The
  default levels are `:hour`, `:day`, `:week`, `:month`, `:quarter` and `:year`.

  Custom levels can be given to `GanttEx.Live.Gantt` through its `zoom_levels`
  attribute:

      [
        %{name: :sprint, column_width: 60, scales: [[unit: :month, format: :month_year], [unit: :week, step: 2]]},
        %{name: :month, column_width: 80, scales: [[unit: :year], [unit: :month]]}
      ]

  ## Examples

      iex> levels = GanttEx.Zoom.default_levels()
      iex> Enum.map(levels, & &1.name)
      [:hour, :day, :week, :month, :quarter, :year]
      iex> GanttEx.Zoom.zoom_in(levels, :week)
      :day
      iex> GanttEx.Zoom.zoom_out(levels, :year)
      :year
  """

  alias GanttEx.Scale

  @typedoc "A zoom level."
  @type level :: %{name: atom(), column_width: pos_integer(), scales: [Scale.t(), ...]}

  @defaults [
    %{
      name: :hour,
      column_width: 44,
      scales: [[unit: :day, format: :weekday_date], [unit: :hour, format: :time]]
    },
    %{
      name: :day,
      column_width: 48,
      scales: [[unit: :month, format: :month_year], [unit: :day, format: :weekday_day]]
    },
    %{
      name: :week,
      column_width: 80,
      scales: [[unit: :month, format: :month_year], [unit: :week, format: :day_month]]
    },
    %{
      name: :month,
      column_width: 80,
      scales: [[unit: :year, format: :year], [unit: :month, format: :month]]
    },
    %{
      name: :quarter,
      column_width: 90,
      scales: [[unit: :year, format: :year], [unit: :quarter, format: :quarter]]
    },
    %{name: :year, column_width: 100, scales: [[unit: :year, format: :year]]}
  ]

  @doc "Returns the default zoom levels."
  @spec default_levels() :: [level()]
  def default_levels, do: normalize!(@defaults)

  @doc """
  Validates and normalizes a list of levels, building `GanttEx.Scale` structs.

      iex> [level] = GanttEx.Zoom.normalize!([%{name: :custom, scales: [[unit: :day]]}])
      iex> {level.column_width, hd(level.scales).unit}
      {60, :day}
  """
  @spec normalize!([map()]) :: [level()]
  def normalize!([_ | _] = levels) do
    Enum.map(levels, fn level ->
      level = Map.new(level)

      %{
        name: Map.fetch!(level, :name),
        column_width: Map.get(level, :column_width, 60),
        scales: level |> Map.fetch!(:scales) |> Enum.map(&Scale.new!/1)
      }
    end)
  end

  def normalize!(levels),
    do: raise(ArgumentError, "expected a non-empty list of zoom levels, got: #{inspect(levels)}")

  @doc """
  Finds a level by name, falling back to the first level.

      iex> GanttEx.Zoom.find(GanttEx.Zoom.default_levels(), :month).column_width
      80
  """
  @spec find([level()], atom()) :: level()
  def find(levels, name), do: Enum.find(levels, hd(levels), &(&1.name == name))

  @doc "Returns the name of the next, more detailed level."
  @spec zoom_in([level()], atom()) :: atom()
  def zoom_in(levels, name), do: neighbour(levels, name, -1)

  @doc "Returns the name of the next, less detailed level."
  @spec zoom_out([level()], atom()) :: atom()
  def zoom_out(levels, name), do: neighbour(levels, name, 1)

  @doc """
  Returns `true` if `name` can be zoomed further in the given direction.

      iex> GanttEx.Zoom.can_zoom?(GanttEx.Zoom.default_levels(), :hour, :in)
      false
  """
  @spec can_zoom?([level()], atom(), :in | :out) :: boolean()
  def can_zoom?(levels, name, :in), do: zoom_in(levels, name) != name
  def can_zoom?(levels, name, :out), do: zoom_out(levels, name) != name

  defp neighbour(levels, name, offset) do
    index = Enum.find_index(levels, &(&1.name == name)) || 0
    levels |> Enum.at(min(max(index + offset, 0), length(levels) - 1)) |> Map.fetch!(:name)
  end
end
