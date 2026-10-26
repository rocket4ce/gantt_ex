defmodule GanttEx.Timeline do
  @moduledoc """
  Maps time to pixels.

  The timeline is divided into columns of the *last* (most detailed) scale.
  Every column has the same width (`:column_width`), even when the underlying
  periods do not (months have 28 to 31 days): positions are interpolated
  inside each column, exactly like DHTMLX Gantt does.

      iex> timeline = GanttEx.Timeline.new(
      ...>   scales: [[unit: :month], [unit: :day]],
      ...>   start_date: ~N[2025-01-01 00:00:00],
      ...>   end_date: ~N[2025-02-01 00:00:00],
      ...>   column_width: 40
      ...> )
      iex> GanttEx.Timeline.column_count(timeline)
      31
      iex> GanttEx.Timeline.x(timeline, ~N[2025-01-03 12:00:00])
      100.0
      iex> GanttEx.Timeline.date_at(timeline, 100)
      ~N[2025-01-03 12:00:00]
      iex> GanttEx.Timeline.width(timeline)
      1240
  """

  alias GanttEx.{Dates, Scale}

  defstruct start_date: nil,
            end_date: nil,
            scales: [],
            column_width: 60,
            week_start: 1,
            boundaries: {}

  @type t :: %__MODULE__{
          start_date: NaiveDateTime.t(),
          end_date: NaiveDateTime.t(),
          scales: [Scale.t(), ...],
          column_width: pos_integer(),
          week_start: 1..7,
          boundaries: tuple()
        }

  @typedoc "A cell of a scale row or a column of the chart."
  @type cell :: %{
          start: NaiveDateTime.t(),
          end: NaiveDateTime.t(),
          x: float(),
          width: float(),
          label: String.t() | nil
        }

  @doc """
  Builds a timeline.

  ## Options

    * `:scales` - list of scales (anything accepted by `GanttEx.Scale.new/1`). Required.
    * `:start_date`, `:end_date` - the visible range. Required. The start is
      aligned to the most detailed scale.
    * `:column_width` - width of a column in pixels. Defaults to `60`.
    * `:week_start` - first ISO day of the week (`1` = Monday). Defaults to `1`.
  """
  @spec new(keyword()) :: t()
  def new(opts) do
    scales = opts |> Keyword.fetch!(:scales) |> Enum.map(&Scale.new!/1)
    week_start = Keyword.get(opts, :week_start, 1)
    minor = List.last(scales)
    start = opts |> Keyword.fetch!(:start_date) |> Dates.floor(minor.unit, week_start: week_start)
    finish = Dates.max(Keyword.fetch!(opts, :end_date), Dates.add(start, minor.step, minor.unit))

    boundaries =
      Stream.iterate(0, &(&1 + 1))
      |> Stream.map(&Dates.add(start, &1 * minor.step, minor.unit))
      |> Enum.reduce_while([], fn boundary, acc ->
        if NaiveDateTime.compare(boundary, finish) == :lt,
          do: {:cont, [boundary | acc]},
          else: {:halt, [boundary | acc]}
      end)
      |> Enum.reverse()

    %__MODULE__{
      start_date: start,
      end_date: List.last(boundaries),
      scales: scales,
      column_width: Keyword.get(opts, :column_width, 60),
      week_start: week_start,
      boundaries: boundaries |> Enum.map(&Dates.to_seconds/1) |> List.to_tuple()
    }
  end

  @doc """
  Computes a comfortable visible range for the given date range.

  The range is padded by one column on each side and aligned to the first
  (least detailed) scale, so the top header always shows complete periods.
  It is then widened to at least `:min_columns` columns (defaults to `12`).
  When `range` is `nil` (no tasks) the range around `:today` is used.

      iex> GanttEx.Timeline.fit({~N[2025-01-10 00:00:00], ~N[2025-01-20 00:00:00]}, [[unit: :month], [unit: :day]])
      {~N[2025-01-01 00:00:00], ~N[2025-02-01 00:00:00]}

      iex> GanttEx.Timeline.fit({~N[2025-01-01 00:00:00], ~N[2025-01-31 00:00:00]}, [[unit: :month], [unit: :day]])
      {~N[2024-12-01 00:00:00], ~N[2025-02-01 00:00:00]}
  """
  @spec fit({NaiveDateTime.t(), NaiveDateTime.t()} | nil, [term()], keyword()) ::
          {NaiveDateTime.t(), NaiveDateTime.t()}
  def fit(range, scales, opts \\ []) do
    scales = Enum.map(scales, &Scale.new!/1)
    top = hd(scales)
    minor = List.last(scales)
    week_opts = [week_start: Keyword.get(opts, :week_start, 1)]

    {first, last} =
      range ||
        (
          today =
            opts |> Keyword.get_lazy(:today, &NaiveDateTime.local_now/0) |> Dates.floor(:day)

          {today, Dates.add(today, 1, :day)}
        )

    start =
      first
      |> Dates.add(-minor.step, minor.unit)
      |> Dates.floor(top.unit, week_opts)
      |> Dates.floor(minor.unit, week_opts)

    finish =
      last
      |> Dates.add(minor.step, minor.unit)
      |> Dates.ceil(top.unit, week_opts)
      |> Dates.ceil(minor.unit, week_opts)

    min_finish = Dates.add(start, Keyword.get(opts, :min_columns, 12) * minor.step, minor.unit)
    {start, Dates.max(finish, min_finish)}
  end

  @doc "Returns the number of columns."
  @spec column_count(t()) :: non_neg_integer()
  def column_count(%__MODULE__{boundaries: boundaries}), do: tuple_size(boundaries) - 1

  @doc "Returns the total width in pixels."
  @spec width(t()) :: non_neg_integer()
  def width(%__MODULE__{} = timeline), do: column_count(timeline) * timeline.column_width

  @doc """
  Returns the horizontal position (in pixels) of a datetime. Dates outside the
  range are extrapolated.
  """
  @spec x(t(), NaiveDateTime.t()) :: float()
  def x(%__MODULE__{boundaries: b, column_width: w} = timeline, %NaiveDateTime{} = datetime) do
    s = Dates.to_seconds(datetime)
    n = column_count(timeline)

    cond do
      s <= elem(b, 0) ->
        (s - elem(b, 0)) / (elem(b, 1) - elem(b, 0)) * w

      s >= elem(b, n) ->
        n * w + (s - elem(b, n)) / (elem(b, n) - elem(b, n - 1)) * w

      true ->
        i = search(b, s, 0, n)
        (i + (s - elem(b, i)) / (elem(b, i + 1) - elem(b, i))) * w
    end
  end

  # finds i such that b[i] <= s < b[i + 1]
  defp search(b, s, low, high) when high - low <= 1,
    do: if(s >= elem(b, high), do: high, else: low)

  defp search(b, s, low, high) do
    mid = div(low + high, 2)
    if elem(b, mid) <= s, do: search(b, s, mid, high), else: search(b, s, low, mid)
  end

  @doc """
  Returns the datetime at a horizontal position (the inverse of `x/2`).
  """
  @spec date_at(t(), number()) :: NaiveDateTime.t()
  def date_at(%__MODULE__{boundaries: b, column_width: w} = timeline, x) do
    n = column_count(timeline)
    i = x |> Kernel./(w) |> Float.floor() |> trunc() |> max(0) |> min(n - 1)
    fraction = x / w - i
    Dates.from_seconds(elem(b, i) + fraction * (elem(b, i + 1) - elem(b, i)))
  end

  @doc """
  Returns the columns of the most detailed scale.

      iex> timeline = GanttEx.Timeline.new(scales: [[unit: :day]], start_date: ~N[2025-01-01 00:00:00], end_date: ~N[2025-01-03 00:00:00], column_width: 50)
      iex> timeline |> GanttEx.Timeline.columns() |> Enum.map(&{&1.start.day, &1.x, &1.width})
      [{1, 0, 50}, {2, 50, 50}]
  """
  @spec columns(t()) :: [cell()]
  def columns(%__MODULE__{boundaries: b, column_width: w} = timeline) do
    for i <- 0..(column_count(timeline) - 1)//1 do
      %{
        start: Dates.from_seconds(elem(b, i)),
        end: Dates.from_seconds(elem(b, i + 1)),
        x: i * w,
        width: w,
        label: nil
      }
    end
  end

  @doc """
  Returns the cells of a scale row, clipped to the timeline range and
  labelled with `formatter` (see `GanttEx.I18n.formatter/1`).

      iex> timeline = GanttEx.Timeline.new(scales: [[unit: :month], [unit: :day]], start_date: ~N[2025-01-30 00:00:00], end_date: ~N[2025-02-02 00:00:00], column_width: 10)
      iex> [month, _day] = timeline.scales
      iex> timeline |> GanttEx.Timeline.cells(month, GanttEx.I18n.formatter("en")) |> Enum.map(&{&1.label, &1.x, &1.width})
      [{"Jan", 0.0, 20.0}, {"Feb", 20.0, 10.0}]
  """
  @spec cells(t(), Scale.t(), (NaiveDateTime.t(), term() -> String.t())) :: [cell()]
  def cells(%__MODULE__{} = timeline, %Scale{} = scale, formatter) do
    first = Dates.floor(timeline.start_date, scale.unit, week_start: timeline.week_start)

    Stream.iterate(0, &(&1 + 1))
    |> Stream.map(
      &{Dates.add(first, &1 * scale.step, scale.unit),
       Dates.add(first, (&1 + 1) * scale.step, scale.unit)}
    )
    |> Enum.take_while(fn {start, _} ->
      NaiveDateTime.compare(start, timeline.end_date) == :lt
    end)
    |> Enum.map(fn {start, finish} ->
      x = x(timeline, Dates.max(start, timeline.start_date))
      x_end = x(timeline, Dates.min(finish, timeline.end_date))
      %{start: start, end: finish, x: x, width: x_end - x, label: formatter.(start, scale.format)}
    end)
  end

  @doc """
  Returns how many pixels one `unit` spans, when it can be known (the unit
  and the columns have a fixed length), or `nil`.

      iex> timeline = GanttEx.Timeline.new(scales: [[unit: :week]], start_date: ~N[2025-01-06 00:00:00], end_date: ~N[2025-02-03 00:00:00], column_width: 70)
      iex> GanttEx.Timeline.unit_width(timeline, :day)
      10.0
  """
  @spec unit_width(t(), Dates.unit()) :: float() | nil
  def unit_width(%__MODULE__{scales: scales, column_width: w}, unit) do
    minor = List.last(scales)

    with column when is_integer(column) <- Dates.unit_seconds(minor.unit),
         seconds when is_integer(seconds) <- Dates.unit_seconds(unit) do
      w * seconds / (column * minor.step)
    end
  end
end
