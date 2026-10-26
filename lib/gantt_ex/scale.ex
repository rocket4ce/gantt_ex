defmodule GanttEx.Scale do
  @moduledoc """
  One row of the time scale header.

  A scale has a `:unit` (see `GanttEx.Dates.units/0`), a `:step` (a scale of
  `unit: :hour, step: 6` shows one cell every 6 hours) and a `:format`, which
  can be a named pattern, a strftime pattern or a function (see
  `GanttEx.I18n`). An optional `:class` function returns extra CSS classes for
  a cell given its start date.

      iex> GanttEx.Scale.new(unit: :week, format: "W%V")
      {:ok, %GanttEx.Scale{unit: :week, step: 1, format: "W%V", class: nil}}

      iex> GanttEx.Scale.new(%{"unit" => "month"})
      {:ok, %GanttEx.Scale{unit: :month, step: 1, format: :month, class: nil}}

      iex> GanttEx.Scale.new(unit: :decade)
      {:error, {:invalid, :unit}}
  """

  alias GanttEx.Dates

  defstruct unit: :day, step: 1, format: :day, class: nil

  @type t :: %__MODULE__{
          unit: Dates.unit(),
          step: pos_integer(),
          format: GanttEx.I18n.pattern(),
          class: (NaiveDateTime.t() -> String.t() | nil) | nil
        }

  @default_formats %{
    minute: :time,
    hour: :time,
    day: :day,
    week: :day_month,
    month: :month,
    quarter: :quarter,
    year: :year
  }

  @doc """
  Builds a scale from a keyword list, a map or a `GanttEx.Scale`.
  """
  @spec new(t() | keyword() | map()) :: {:ok, t()} | {:error, {:invalid, atom()}}
  def new(%__MODULE__{} = scale), do: {:ok, scale}
  def new(attrs) when is_list(attrs), do: attrs |> Map.new() |> new()

  def new(attrs) when is_map(attrs) do
    get = fn key -> Map.get(attrs, key, Map.get(attrs, Atom.to_string(key))) end

    with {:ok, unit} <- cast(Dates.cast_unit(get.(:unit) || :day), :unit),
         {:ok, step} <- cast_step(get.(:step) || 1) do
      {:ok,
       %__MODULE__{
         unit: unit,
         step: step,
         format: get.(:format) || Map.fetch!(@default_formats, unit),
         class: get.(:class)
       }}
    end
  end

  @doc """
  Like `new/1` but raises on invalid attributes.

      iex> GanttEx.Scale.new!(unit: :day).format
      :day
  """
  @spec new!(t() | keyword() | map()) :: t()
  def new!(attrs) do
    case new(attrs) do
      {:ok, scale} ->
        scale

      {:error, reason} ->
        raise ArgumentError, "invalid scale #{inspect(reason)}: #{inspect(attrs)}"
    end
  end

  defp cast({:ok, value}, _field), do: {:ok, value}
  defp cast(:error, field), do: {:error, {:invalid, field}}

  defp cast_step(step) when is_integer(step) and step > 0, do: {:ok, step}
  defp cast_step(_step), do: {:error, {:invalid, :step}}
end
