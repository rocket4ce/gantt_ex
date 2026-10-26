defmodule GanttEx.Dates do
  @moduledoc """
  Date arithmetic used across GanttEx.

  GanttEx works with `NaiveDateTime` values internally, the same way the
  original DHTMLX Gantt works with local `Date` objects: a Gantt chart shows
  wall-clock time, so time zones are left to the host application.

  Durations are always expressed as an integer amount of a *unit*:

    * `:minute`, `:hour`, `:day` and `:week` have a fixed length
    * `:month`, `:quarter` and `:year` follow the calendar (a month can have
      28 to 31 days)

  ## Examples

      iex> GanttEx.Dates.add(~N[2025-01-30 00:00:00], 1, :month)
      ~N[2025-02-28 00:00:00]

      iex> GanttEx.Dates.diff(~N[2025-01-01 00:00:00], ~N[2025-01-04 00:00:00], :day)
      3

      iex> GanttEx.Dates.floor(~N[2025-05-14 13:45:00], :week)
      ~N[2025-05-12 00:00:00]
  """

  import Kernel, except: [min: 2, max: 2]

  @typedoc "A duration unit."
  @type unit :: :minute | :hour | :day | :week | :month | :quarter | :year

  @units [:minute, :hour, :day, :week, :month, :quarter, :year]
  @fixed_seconds %{minute: 60, hour: 3_600, day: 86_400, week: 604_800}

  @doc """
  Returns all supported units, from the smallest to the largest.

      iex> GanttEx.Dates.units()
      [:minute, :hour, :day, :week, :month, :quarter, :year]
  """
  @spec units() :: [unit()]
  def units, do: @units

  @doc """
  Returns `true` if `unit` is a supported duration unit.

      iex> GanttEx.Dates.unit?(:day)
      true

      iex> GanttEx.Dates.unit?(:fortnight)
      false
  """
  @spec unit?(term()) :: boolean()
  def unit?(unit), do: unit in @units

  @doc """
  Casts a unit given as atom or string.

      iex> GanttEx.Dates.cast_unit("hour")
      {:ok, :hour}

      iex> GanttEx.Dates.cast_unit(:day)
      {:ok, :day}

      iex> GanttEx.Dates.cast_unit("decade")
      :error
  """
  @spec cast_unit(term()) :: {:ok, unit()} | :error
  def cast_unit(unit) when unit in @units, do: {:ok, unit}

  def cast_unit(unit) when is_binary(unit) do
    case Enum.find(@units, &(Atom.to_string(&1) == unit)) do
      nil -> :error
      unit -> {:ok, unit}
    end
  end

  def cast_unit(_unit), do: :error

  @doc """
  Casts a date-like value into a `NaiveDateTime` truncated to seconds.

  Accepts `NaiveDateTime`, `DateTime` (converted to its wall-clock time),
  `Date` (midnight), ISO 8601 strings (`"2025-01-31"`, `"2025-01-31 10:30"`,
  `"2025-01-31T10:30:00"`) and the DHTMLX default format (`"31-01-2025"`,
  `"31-01-2025 10:30"`). `nil` is returned as `{:ok, nil}`.

  ## Examples

      iex> GanttEx.Dates.cast(~D[2025-03-01])
      {:ok, ~N[2025-03-01 00:00:00]}

      iex> GanttEx.Dates.cast("2025-03-01 08:30")
      {:ok, ~N[2025-03-01 08:30:00]}

      iex> GanttEx.Dates.cast("01-03-2025")
      {:ok, ~N[2025-03-01 00:00:00]}

      iex> GanttEx.Dates.cast(nil)
      {:ok, nil}

      iex> GanttEx.Dates.cast("yesterday")
      :error
  """
  @spec cast(term()) :: {:ok, NaiveDateTime.t() | nil} | :error
  def cast(nil), do: {:ok, nil}
  def cast(%NaiveDateTime{} = dt), do: {:ok, NaiveDateTime.truncate(dt, :second)}
  def cast(%DateTime{} = dt), do: dt |> DateTime.to_naive() |> cast()
  def cast(%Date{} = date), do: {:ok, NaiveDateTime.new!(date, ~T[00:00:00])}
  def cast(""), do: {:ok, nil}

  def cast(value) when is_binary(value) do
    value = String.trim(value)

    cond do
      match?({:ok, _}, NaiveDateTime.from_iso8601(value)) ->
        value |> NaiveDateTime.from_iso8601!() |> cast()

      Regex.match?(~r/^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}$/, value) ->
        cast(value <> ":00")

      match?({:ok, _}, Date.from_iso8601(value)) ->
        value |> Date.from_iso8601!() |> cast()

      captures = Regex.run(~r/^(\d{2})-(\d{2})-(\d{4})(?: (\d{2}):(\d{2}))?$/, value) ->
        cast_dhtmlx(captures)

      true ->
        :error
    end
  end

  def cast(_value), do: :error

  defp cast_dhtmlx([_, day, month, year | time]) do
    [hour, minute] = if time == [], do: ["0", "0"], else: time

    with {:ok, date} <- Date.new(to_int(year), to_int(month), to_int(day)),
         {:ok, time} <- Time.new(to_int(hour), to_int(minute), 0) do
      {:ok, NaiveDateTime.new!(date, time)}
    else
      _ -> :error
    end
  end

  defp to_int(string), do: String.to_integer(string)

  @doc """
  Like `cast/1` but raises `ArgumentError` on invalid input.

      iex> GanttEx.Dates.cast!("2025-01-01")
      ~N[2025-01-01 00:00:00]
  """
  @spec cast!(term()) :: NaiveDateTime.t() | nil
  def cast!(value) do
    case cast(value) do
      {:ok, dt} -> dt
      :error -> raise ArgumentError, "cannot cast #{inspect(value)} to a NaiveDateTime"
    end
  end

  @doc """
  Adds `amount` units to `datetime`. Negative amounts move backwards.

  Calendar units clamp the day when the target month is shorter.

  ## Examples

      iex> GanttEx.Dates.add(~N[2025-01-01 00:00:00], 36, :hour)
      ~N[2025-01-02 12:00:00]

      iex> GanttEx.Dates.add(~N[2025-01-31 00:00:00], 1, :quarter)
      ~N[2025-04-30 00:00:00]

      iex> GanttEx.Dates.add(~N[2025-01-10 00:00:00], -1, :week)
      ~N[2025-01-03 00:00:00]
  """
  @spec add(NaiveDateTime.t(), number(), unit()) :: NaiveDateTime.t()
  def add(%NaiveDateTime{} = datetime, amount, unit) when is_map_key(@fixed_seconds, unit) do
    NaiveDateTime.add(datetime, round(amount * Map.fetch!(@fixed_seconds, unit)), :second)
  end

  def add(%NaiveDateTime{} = datetime, amount, :month),
    do: NaiveDateTime.shift(datetime, month: round(amount))

  def add(%NaiveDateTime{} = datetime, amount, :quarter),
    do: NaiveDateTime.shift(datetime, month: round(amount) * 3)

  def add(%NaiveDateTime{} = datetime, amount, :year),
    do: NaiveDateTime.shift(datetime, year: round(amount))

  @doc """
  Returns the duration between `from` and `to` in `unit`, rounded to the
  nearest integer. The result is negative when `to` is before `from`.

  ## Examples

      iex> GanttEx.Dates.diff(~N[2025-01-01 00:00:00], ~N[2025-01-01 18:00:00], :day)
      1

      iex> GanttEx.Dates.diff(~N[2025-01-15 00:00:00], ~N[2025-03-15 00:00:00], :month)
      2

      iex> GanttEx.Dates.diff(~N[2025-01-01 00:00:00], ~N[2024-12-31 00:00:00], :hour)
      -24
  """
  @spec diff(NaiveDateTime.t(), NaiveDateTime.t(), unit()) :: integer()
  def diff(from, to, unit), do: round(diff_float(from, to, unit))

  @doc """
  Like `diff/3` but returns the exact (fractional) amount.

      iex> GanttEx.Dates.diff_float(~N[2025-01-01 00:00:00], ~N[2025-01-01 12:00:00], :day)
      0.5
  """
  @spec diff_float(NaiveDateTime.t(), NaiveDateTime.t(), unit()) :: float()
  def diff_float(from, to, unit) when is_map_key(@fixed_seconds, unit) do
    NaiveDateTime.diff(to, from, :second) / Map.fetch!(@fixed_seconds, unit)
  end

  def diff_float(from, to, :quarter), do: diff_float(from, to, :month) / 3
  def diff_float(from, to, :year), do: diff_float(from, to, :month) / 12

  def diff_float(from, to, :month) do
    if NaiveDateTime.compare(to, from) == :lt do
      -diff_float(to, from, :month)
    else
      whole = (to.year - from.year) * 12 + to.month - from.month

      whole =
        if NaiveDateTime.compare(add(from, whole, :month), to) == :gt, do: whole - 1, else: whole

      base = add(from, whole, :month)
      next = add(from, whole + 1, :month)
      whole + NaiveDateTime.diff(to, base) / NaiveDateTime.diff(next, base)
    end
  end

  @doc """
  Returns the length in seconds of a fixed-length unit.

      iex> GanttEx.Dates.unit_seconds(:hour)
      3600

      iex> GanttEx.Dates.unit_seconds(:month)
      nil
  """
  @spec unit_seconds(unit()) :: pos_integer() | nil
  def unit_seconds(unit), do: Map.get(@fixed_seconds, unit)

  @doc """
  Rounds `datetime` down to the start of `unit`.

  Weeks start on Monday by default; pass `week_start: 7` to start on Sunday
  (ISO day numbers, `1` = Monday ... `7` = Sunday).

  ## Examples

      iex> GanttEx.Dates.floor(~N[2025-05-14 13:45:10], :hour)
      ~N[2025-05-14 13:00:00]

      iex> GanttEx.Dates.floor(~N[2025-05-14 13:45:10], :quarter)
      ~N[2025-04-01 00:00:00]

      iex> GanttEx.Dates.floor(~N[2025-05-14 13:45:10], :week, week_start: 7)
      ~N[2025-05-11 00:00:00]
  """
  @spec floor(NaiveDateTime.t(), unit(), keyword()) :: NaiveDateTime.t()
  def floor(datetime, unit, opts \\ [])

  def floor(%NaiveDateTime{} = dt, :minute, _opts), do: %{dt | second: 0, microsecond: {0, 0}}
  def floor(%NaiveDateTime{} = dt, :hour, opts), do: %{floor(dt, :minute, opts) | minute: 0}
  def floor(%NaiveDateTime{} = dt, :day, opts), do: %{floor(dt, :hour, opts) | hour: 0}

  def floor(%NaiveDateTime{} = dt, :week, opts) do
    week_start = Keyword.get(opts, :week_start, 1)
    day = floor(dt, :day, opts)
    offset = Integer.mod(Date.day_of_week(day) - week_start, 7)
    add(day, -offset, :day)
  end

  def floor(%NaiveDateTime{} = dt, :month, opts), do: %{floor(dt, :day, opts) | day: 1}

  def floor(%NaiveDateTime{} = dt, :quarter, opts),
    do: %{floor(dt, :month, opts) | month: div(dt.month - 1, 3) * 3 + 1}

  def floor(%NaiveDateTime{} = dt, :year, opts), do: %{floor(dt, :month, opts) | month: 1}

  @doc """
  Rounds `datetime` up to the start of the next `unit`, unless it is already
  aligned.

  ## Examples

      iex> GanttEx.Dates.ceil(~N[2025-05-14 13:45:10], :day)
      ~N[2025-05-15 00:00:00]

      iex> GanttEx.Dates.ceil(~N[2025-05-01 00:00:00], :month)
      ~N[2025-05-01 00:00:00]
  """
  @spec ceil(NaiveDateTime.t(), unit(), keyword()) :: NaiveDateTime.t()
  def ceil(%NaiveDateTime{} = datetime, unit, opts \\ []) do
    floored = floor(datetime, unit, opts)

    if NaiveDateTime.compare(floored, NaiveDateTime.truncate(datetime, :second)) == :eq do
      floored
    else
      add(floored, 1, unit)
    end
  end

  @doc """
  Rounds `datetime` to the nearest boundary of `unit`.

      iex> GanttEx.Dates.round(~N[2025-05-14 13:00:00], :day)
      ~N[2025-05-15 00:00:00]

      iex> GanttEx.Dates.round(~N[2025-05-14 11:59:00], :day)
      ~N[2025-05-14 00:00:00]
  """
  @spec round(NaiveDateTime.t(), unit(), keyword()) :: NaiveDateTime.t()
  def round(%NaiveDateTime{} = datetime, unit, opts \\ []) do
    lower = floor(datetime, unit, opts)
    upper = add(lower, 1, unit)

    if NaiveDateTime.diff(datetime, lower) * 2 >= NaiveDateTime.diff(upper, lower),
      do: upper,
      else: lower
  end

  @doc """
  Converts a `NaiveDateTime` into gregorian seconds (useful for fast math).

      iex> GanttEx.Dates.to_seconds(~N[0000-01-01 00:01:00])
      60
  """
  @spec to_seconds(NaiveDateTime.t()) :: integer()
  def to_seconds(%NaiveDateTime{} = dt) do
    dt |> NaiveDateTime.to_erl() |> :calendar.datetime_to_gregorian_seconds()
  end

  @doc """
  Converts gregorian seconds back into a `NaiveDateTime`.

      iex> GanttEx.Dates.from_seconds(60)
      ~N[0000-01-01 00:01:00]
  """
  @spec from_seconds(number()) :: NaiveDateTime.t()
  def from_seconds(seconds) do
    seconds
    |> Kernel.round()
    |> :calendar.gregorian_seconds_to_datetime()
    |> NaiveDateTime.from_erl!()
  end

  @doc """
  Returns the earliest of two datetimes (ignoring `nil`).

      iex> GanttEx.Dates.min(~N[2025-01-02 00:00:00], ~N[2025-01-01 00:00:00])
      ~N[2025-01-01 00:00:00]

      iex> GanttEx.Dates.min(nil, ~N[2025-01-01 00:00:00])
      ~N[2025-01-01 00:00:00]
  """
  @spec min(NaiveDateTime.t() | nil, NaiveDateTime.t() | nil) :: NaiveDateTime.t() | nil
  def min(nil, b), do: b
  def min(a, nil), do: a
  def min(a, b), do: if(NaiveDateTime.compare(a, b) == :gt, do: b, else: a)

  @doc """
  Returns the latest of two datetimes (ignoring `nil`).

      iex> GanttEx.Dates.max(~N[2025-01-02 00:00:00], ~N[2025-01-01 00:00:00])
      ~N[2025-01-02 00:00:00]
  """
  @spec max(NaiveDateTime.t() | nil, NaiveDateTime.t() | nil) :: NaiveDateTime.t() | nil
  def max(nil, b), do: b
  def max(a, nil), do: a
  def max(a, b), do: if(NaiveDateTime.compare(a, b) == :lt, do: b, else: a)

  @doc """
  Returns the ISO 8601 week number of `datetime`.

      iex> GanttEx.Dates.iso_week(~N[2025-01-01 00:00:00])
      1

      iex> GanttEx.Dates.iso_week(~N[2024-12-30 00:00:00])
      1
  """
  @spec iso_week(NaiveDateTime.t() | Date.t()) :: 1..53
  def iso_week(%{year: y, month: m, day: d}) do
    {_year, week} = :calendar.iso_week_number({y, m, d})
    week
  end
end
