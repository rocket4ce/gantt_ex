defmodule GanttEx.Marker do
  @moduledoc """
  A vertical line on the timeline marking a date (a release, a freeze, today...).

  Markers are given to `GanttEx.Live.Gantt` with the `markers` attribute;
  `today_marker` adds one for the current date.

      iex> {:ok, marker} = GanttEx.Marker.new(%{date: "2025-03-01", text: "Release", color: "#e11d48"})
      iex> {marker.date, marker.text, marker.color}
      {~N[2025-03-01 00:00:00], "Release", "#e11d48"}

      iex> GanttEx.Marker.new(text: "No date")
      {:error, {:invalid, :date}}
  """

  alias GanttEx.{Dates, Task}

  defstruct [:id, :date, text: "", class: nil, color: nil]

  @type t :: %__MODULE__{
          id: term(),
          date: NaiveDateTime.t(),
          text: String.t(),
          class: String.t() | nil,
          color: String.t() | nil
        }

  @doc "Builds a marker from a map or keyword list."
  @spec new(map() | keyword() | t()) :: {:ok, t()} | {:error, {:invalid, atom()}}
  def new(%__MODULE__{} = marker), do: {:ok, marker}
  def new(attrs) when is_list(attrs), do: attrs |> Map.new() |> new()

  def new(attrs) when is_map(attrs) do
    get = fn key -> Map.get(attrs, key, Map.get(attrs, Atom.to_string(key))) end

    with {:ok, date} <- cast_date(get.(:date)),
         {:ok, color} <- cast_color(get.(:color)) do
      {:ok,
       %__MODULE__{
         id: get.(:id) || Dates.to_seconds(date),
         date: date,
         text: to_string(get.(:text) || ""),
         class: get.(:class),
         color: color
       }}
    end
  end

  defp cast_date(value) do
    case Dates.cast(value) do
      {:ok, %NaiveDateTime{} = date} -> {:ok, date}
      _ -> {:error, {:invalid, :date}}
    end
  end

  defp cast_color(value) do
    case Task.cast_color(value) do
      {:ok, color} -> {:ok, color}
      :error -> {:error, {:invalid, :color}}
    end
  end

  @doc "Like `new/1` but raises `ArgumentError`."
  @spec new!(map() | keyword() | t()) :: t()
  def new!(attrs) do
    case new(attrs) do
      {:ok, marker} ->
        marker

      {:error, reason} ->
        raise ArgumentError, "invalid marker #{inspect(reason)}: #{inspect(attrs)}"
    end
  end
end
