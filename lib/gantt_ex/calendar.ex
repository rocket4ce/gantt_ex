defmodule GanttEx.Calendar do
  @moduledoc """
  Working-time calendars.

  A calendar defines the working days of the week, the working hours of a
  day and per-date exceptions (holidays or extra working days). When a chart
  uses working time, durations only count working time:

    * with the `:day` unit, a duration is a number of working days, and a
      task that starts on Friday with a duration of 2 ends on Tuesday
    * with the `:hour` and `:minute` units, only working hours count
    * larger units (`:week`, `:month`, ...) use plain calendar time

  ## Examples

      iex> calendar = GanttEx.Calendar.new!(holidays: [~D[2025-01-01]])
      iex> GanttEx.Calendar.working_day?(calendar, ~D[2025-01-01])
      false
      iex> GanttEx.Calendar.add(calendar, ~N[2025-01-03 00:00:00], 2, :day)
      ~N[2025-01-07 00:00:00]
      iex> GanttEx.Calendar.diff(calendar, ~N[2025-01-03 00:00:00], ~N[2025-01-07 00:00:00], :day)
      2
      iex> GanttEx.Calendar.add(calendar, ~N[2025-01-03 16:00:00], 3, :hour)
      ~N[2025-01-06 10:00:00]

  Calendars are given to `GanttEx.Live.Gantt` with the `calendar` attribute
  (the global calendar) and the `calendars` attribute (calendars that tasks
  reference with their `:calendar_id`), together with `work_time`.
  """

  alias GanttEx.Dates

  @typedoc "A working period of a day, in minutes from midnight: `{start, finish}`."
  @type range :: {non_neg_integer(), pos_integer()}

  defstruct id: "global",
            work_days: [1, 2, 3, 4, 5],
            hours: [{480, 720}, {780, 1020}],
            dates: %{},
            index: nil

  # `index` is derived from `dates` by `new/1`: the exceptions by day number
  # (`Date.to_gregorian_days/1`) and those numbers sorted, so the arithmetic
  # works on integers instead of dates.
  @type t :: %__MODULE__{
          id: term(),
          work_days: [1..7],
          hours: [range()],
          dates: %{Date.t() => [range()]},
          index: {%{integer() => [range()]}, tuple()} | nil
        }

  # Long tasks are walked day by day; this bounds the walk for safety.
  @max_days 36_500

  @doc """
  Builds a calendar.

  ## Options

    * `:id` - identifier referenced by tasks (`:calendar_id`). Defaults to `"global"`.
    * `:work_days` - ISO days of the week that are worked (`1` = Monday).
      Defaults to Monday to Friday.
    * `:hours` - working periods of a working day, as `{8, 12}` (hours),
      `{"08:30", "12:00"}`, `"08:30-12:00"` or `{~T[08:30:00], ~T[12:00:00]}`.
      Defaults to 08:00-12:00 and 13:00-17:00.
    * `:holidays` - dates that are not worked.
    * `:working_dates` - dates that are worked even if their weekday is not.
      A map of `date => hours` sets custom hours for those dates.

  ## Examples

      iex> {:ok, calendar} = GanttEx.Calendar.new(id: "night", work_days: [1, 2, 3, 4], hours: ["22:00-23:30"])
      iex> {calendar.work_days, calendar.hours}
      {[1, 2, 3, 4], [{1320, 1410}]}

      iex> GanttEx.Calendar.new(hours: ["9 to 5"])
      {:error, {:invalid, :hours}}
  """
  @spec new(keyword() | map() | t()) :: {:ok, t()} | {:error, {:invalid, atom()}}
  def new(%__MODULE__{} = calendar), do: {:ok, index(calendar)}
  def new(opts) when is_map(opts), do: opts |> Map.to_list() |> new()

  def new(opts) when is_list(opts) do
    opts = Enum.map(opts, fn {key, value} -> {to_key(key), value} end)

    with {:ok, work_days} <- cast_days(Keyword.get(opts, :work_days, [1, 2, 3, 4, 5])),
         {:ok, hours} <- cast_hours(Keyword.get(opts, :hours, [{8, 12}, {13, 17}])),
         {:ok, holidays} <- cast_dates(Keyword.get(opts, :holidays, [])),
         {:ok, working} <- cast_working_dates(Keyword.get(opts, :working_dates, []), hours) do
      dates = holidays |> Map.new(&{&1, []}) |> Map.merge(working)

      {:ok,
       index(%__MODULE__{
         id: Keyword.get(opts, :id, "global"),
         work_days: work_days,
         hours: hours,
         dates: dates
       })}
    end
  end

  defp index(%__MODULE__{dates: dates} = calendar) do
    days = Map.new(dates, fn {date, hours} -> {Date.to_gregorian_days(date), hours} end)
    %{calendar | index: {days, days |> Map.keys() |> Enum.sort() |> List.to_tuple()}}
  end

  # Calendars built as structs get their index on first use
  defp indexed(%__MODULE__{dates: dates, index: {days, _sorted}} = calendar)
       when map_size(days) == map_size(dates),
       do: calendar

  defp indexed(calendar), do: index(calendar)

  @doc "Like `new/1` but raises `ArgumentError`."
  @spec new!(keyword() | map() | t()) :: t()
  def new!(opts \\ []) do
    case new(opts) do
      {:ok, calendar} ->
        calendar

      {:error, reason} ->
        raise ArgumentError, "invalid calendar #{inspect(reason)}: #{inspect(opts)}"
    end
  end

  defp to_key(key) when is_atom(key), do: key

  defp to_key(key) when is_binary(key) do
    Enum.find(
      [:id, :work_days, :hours, :holidays, :working_dates],
      key,
      &(Atom.to_string(&1) == key)
    )
  end

  defp cast_days(days) do
    days = days |> Enum.to_list() |> Enum.uniq() |> Enum.sort()
    if Enum.all?(days, &(&1 in 1..7)), do: {:ok, days}, else: {:error, {:invalid, :work_days}}
  end

  defp cast_hours(hours) do
    hours
    |> Enum.reduce_while({:ok, []}, fn range, {:ok, acc} ->
      case cast_range(range) do
        {:ok, range} -> {:cont, {:ok, [range | acc]}}
        :error -> {:halt, {:error, {:invalid, :hours}}}
      end
    end)
    |> case do
      {:ok, ranges} -> {:ok, ranges |> Enum.sort() |> merge_ranges()}
      error -> error
    end
  end

  defp cast_range({from, to}) do
    with {:ok, from} <- cast_minute(from),
         {:ok, to} <- cast_minute(to),
         true <- from < to do
      {:ok, {from, to}}
    else
      _ -> :error
    end
  end

  defp cast_range(text) when is_binary(text) do
    case String.split(text, "-", parts: 2) do
      [from, to] -> cast_range({String.trim(from), String.trim(to)})
      _ -> :error
    end
  end

  defp cast_range(_range), do: :error

  defp cast_minute(hour) when is_integer(hour) and hour in 0..24, do: {:ok, hour * 60}
  defp cast_minute(%Time{hour: h, minute: m}), do: {:ok, h * 60 + m}

  defp cast_minute(text) when is_binary(text) do
    case Regex.run(~r/^(\d{1,2}):(\d{2})$/, text) do
      [_, h, m] ->
        {h, m} = {String.to_integer(h), String.to_integer(m)}
        if m < 60 and h * 60 + m <= 1440, do: {:ok, h * 60 + m}, else: :error

      _ ->
        :error
    end
  end

  defp cast_minute(_value), do: :error

  defp merge_ranges([{a, b}, {c, d} | rest]) when c <= b,
    do: merge_ranges([{a, max(b, d)} | rest])

  defp merge_ranges([range | rest]), do: [range | merge_ranges(rest)]
  defp merge_ranges([]), do: []

  defp cast_dates(dates) do
    Enum.reduce_while(dates, {:ok, []}, fn date, {:ok, acc} ->
      case cast_date(date) do
        {:ok, date} -> {:cont, {:ok, [date | acc]}}
        :error -> {:halt, {:error, {:invalid, :dates}}}
      end
    end)
  end

  defp cast_working_dates(dates, _default_hours) when is_map(dates) do
    Enum.reduce_while(dates, {:ok, %{}}, fn {date, hours}, {:ok, acc} ->
      with {:ok, date} <- cast_date(date),
           {:ok, hours} <- cast_hours(hours) do
        {:cont, {:ok, Map.put(acc, date, hours)}}
      else
        _ -> {:halt, {:error, {:invalid, :working_dates}}}
      end
    end)
  end

  defp cast_working_dates(dates, default_hours) do
    with {:ok, dates} <- cast_dates(dates), do: {:ok, Map.new(dates, &{&1, default_hours})}
  end

  defp cast_date(%Date{} = date), do: {:ok, date}

  defp cast_date(value) do
    case Dates.cast(value) do
      {:ok, %NaiveDateTime{} = datetime} -> {:ok, NaiveDateTime.to_date(datetime)}
      _ -> :error
    end
  end

  # -- queries -----------------------------------------------------------------

  @doc """
  Returns the working periods of a date.

      iex> calendar = GanttEx.Calendar.new!()
      iex> GanttEx.Calendar.hours_for(calendar, ~D[2025-01-06])
      [{480, 720}, {780, 1020}]
      iex> GanttEx.Calendar.hours_for(calendar, ~D[2025-01-05])
      []
  """
  @spec hours_for(t(), Date.t() | NaiveDateTime.t()) :: [range()]
  def hours_for(%__MODULE__{} = calendar, %NaiveDateTime{} = datetime),
    do: hours_for(calendar, NaiveDateTime.to_date(datetime))

  def hours_for(%__MODULE__{} = calendar, %Date{} = date) do
    case Map.fetch(calendar.dates, date) do
      {:ok, hours} -> hours
      :error -> if Date.day_of_week(date) in calendar.work_days, do: calendar.hours, else: []
    end
  end

  @doc """
  Returns `true` if any time of the date is worked.

      iex> GanttEx.Calendar.working_day?(GanttEx.Calendar.new!(), ~D[2025-01-04])
      false
  """
  @spec working_day?(t(), Date.t() | NaiveDateTime.t()) :: boolean()
  def working_day?(calendar, date), do: hours_for(calendar, date) != []

  @doc """
  Returns the number of working minutes of a date.

      iex> GanttEx.Calendar.working_minutes(GanttEx.Calendar.new!(), ~D[2025-01-06])
      480
  """
  @spec working_minutes(t(), Date.t()) :: non_neg_integer()
  def working_minutes(calendar, date) do
    calendar |> hours_for(date) |> Enum.map(fn {from, to} -> to - from end) |> Enum.sum()
  end

  @doc """
  Returns `true` if `datetime` falls inside working time.

      iex> calendar = GanttEx.Calendar.new!()
      iex> GanttEx.Calendar.working_time?(calendar, ~N[2025-01-06 12:30:00])
      false
      iex> GanttEx.Calendar.working_time?(calendar, ~N[2025-01-06 13:00:00])
      true
  """
  @spec working_time?(t(), NaiveDateTime.t()) :: boolean()
  def working_time?(calendar, %NaiveDateTime{} = datetime) do
    minute = minute_of_day(datetime)
    Enum.any?(hours_for(calendar, datetime), fn {from, to} -> minute >= from and minute < to end)
  end

  @doc """
  Moves `datetime` forward to the next working time: the start of the next
  working day for the `:day` unit, the next working minute otherwise.

      iex> calendar = GanttEx.Calendar.new!()
      iex> GanttEx.Calendar.next_working(calendar, ~N[2025-01-04 10:00:00], :day)
      ~N[2025-01-06 00:00:00]
      iex> GanttEx.Calendar.next_working(calendar, ~N[2025-01-06 12:15:00], :hour)
      ~N[2025-01-06 13:00:00]
  """
  @spec next_working(t(), NaiveDateTime.t(), Dates.unit()) :: NaiveDateTime.t()
  def next_working(calendar, datetime, unit) when unit in [:hour, :minute] do
    if working_time?(calendar, datetime),
      do: datetime,
      else: calendar |> indexed() |> walk_forward(datetime, 0)
  end

  def next_working(calendar, datetime, :day) do
    calendar = indexed(calendar)
    day = day_number(datetime)

    if hours_on(calendar, day) != [],
      do: datetime,
      else: calendar |> nth_working_day(day + 1, 1, 1) |> at_midnight()
  end

  def next_working(_calendar, datetime, _unit), do: datetime

  # -- arithmetic --------------------------------------------------------------

  @doc """
  Adds `amount` units of working time. Negative amounts move backwards: that
  is how a start date is computed from an end date.

      iex> calendar = GanttEx.Calendar.new!()
      iex> GanttEx.Calendar.add(calendar, ~N[2025-01-10 00:00:00], 1, :day)
      ~N[2025-01-11 00:00:00]
      iex> GanttEx.Calendar.add(calendar, ~N[2025-01-14 00:00:00], -2, :day)
      ~N[2025-01-10 00:00:00]
      iex> GanttEx.Calendar.add(calendar, ~N[2025-01-06 11:00:00], 2, :hour)
      ~N[2025-01-06 14:00:00]
      iex> GanttEx.Calendar.add(calendar, ~N[2025-01-06 09:00:00], 1, :month)
      ~N[2025-02-06 09:00:00]
  """
  @spec add(t(), NaiveDateTime.t(), number(), Dates.unit()) :: NaiveDateTime.t()
  def add(_calendar, datetime, amount, _unit) when amount == 0, do: datetime

  def add(calendar, datetime, amount, :day) when amount > 0 do
    calendar
    |> indexed()
    |> nth_working_day(day_number(datetime), round(amount), 1)
    |> Kernel.+(1)
    |> at_midnight()
  end

  def add(calendar, datetime, amount, :day) do
    # the last day before `datetime`, walking backwards
    last = datetime |> Dates.add(-1, :minute) |> day_number()
    calendar |> indexed() |> nth_working_day(last, round(-amount), -1) |> at_midnight()
  end

  def add(calendar, datetime, amount, unit) when unit in [:hour, :minute] do
    minutes = round(amount * if(unit == :hour, do: 60, else: 1))
    calendar = indexed(calendar)

    if minutes > 0,
      do: walk_forward(calendar, datetime, minutes),
      else: walk_backward(calendar, datetime, -minutes)
  end

  def add(_calendar, datetime, amount, unit), do: Dates.add(datetime, amount, unit)

  @doc """
  Returns the working time between two datetimes in `unit`, rounded.

      iex> calendar = GanttEx.Calendar.new!()
      iex> GanttEx.Calendar.diff(calendar, ~N[2025-01-06 00:00:00], ~N[2025-01-13 00:00:00], :day)
      5
      iex> GanttEx.Calendar.diff(calendar, ~N[2025-01-06 10:00:00], ~N[2025-01-07 10:00:00], :hour)
      8
      iex> GanttEx.Calendar.diff(calendar, ~N[2025-01-13 00:00:00], ~N[2025-01-06 00:00:00], :day)
      -5
  """
  @spec diff(t(), NaiveDateTime.t(), NaiveDateTime.t(), Dates.unit()) :: integer()
  def diff(calendar, from, to, unit) do
    case NaiveDateTime.compare(to, from) do
      :lt -> -diff(calendar, to, from, unit)
      :eq -> 0
      :gt -> calendar |> indexed() |> do_diff(from, to, unit)
    end
  end

  defp do_diff(calendar, from, to, :day) do
    # a day counts when the range reaches into it
    last = to |> NaiveDateTime.add(-1, :second) |> day_number()
    sum_days(calendar, day_number(from), last, &if(&1 == [], do: 0, else: 1))
  end

  defp do_diff(calendar, from, to, unit) when unit in [:hour, :minute] do
    first = day_number(from)
    last = day_number(to)

    minutes =
      if first == last do
        clipped_minutes(calendar, first, minute_of_day(from), minute_of_day(to))
      else
        clipped_minutes(calendar, first, minute_of_day(from), 1440) +
          sum_days(calendar, first + 1, last - 1, &hours_minutes/1) +
          clipped_minutes(calendar, last, 0, minute_of_day(to))
      end

    round(if unit == :hour, do: minutes / 60, else: minutes)
  end

  defp do_diff(_calendar, from, to, unit), do: Dates.diff(from, to, unit)

  @doc """
  Returns the non-working dates between two datetimes (useful to highlight them).

      iex> calendar = GanttEx.Calendar.new!(holidays: [~D[2025-01-08]])
      iex> GanttEx.Calendar.non_working_dates(calendar, ~N[2025-01-06 00:00:00], ~N[2025-01-13 00:00:00])
      [~D[2025-01-08], ~D[2025-01-11], ~D[2025-01-12]]
  """
  @spec non_working_dates(t(), NaiveDateTime.t(), NaiveDateTime.t()) :: [Date.t()]
  def non_working_dates(calendar, from, to) do
    last = to |> NaiveDateTime.add(-1, :second) |> NaiveDateTime.to_date()

    if NaiveDateTime.compare(to, from) == :gt do
      Date.range(NaiveDateTime.to_date(from), last) |> Enum.reject(&working_day?(calendar, &1))
    else
      []
    end
  end

  # Sums `value.(hours)` over the working periods of the days from `first`
  # to `last` (day numbers). Long ranges count whole weeks at once and then
  # correct the days with exceptions, instead of visiting every day.
  defp sum_days(_calendar, first, last, _value) when last < first, do: 0

  defp sum_days(calendar, first, last, value) when last - first < 14 do
    Enum.reduce(first..last, 0, &(value.(hours_on(calendar, &1)) + &2))
  end

  defp sum_days(%{index: {days, sorted}} = calendar, first, last, value) do
    total = last - first + 1
    weekly = &value.(weekday_hours(calendar, &1))
    # ISO day of the week of `first`, from 0 (Monday) to 6
    offset = weekday(first) - 1
    week = Enum.sum_by(1..7, weekly)
    rest = Enum.sum_by(0..(rem(total, 7) - 1)//1, &weekly.(rem(offset + &1, 7) + 1))

    exceptions =
      sorted
      |> exceptions_from(first_at_least(sorted, first), last)
      |> Enum.reduce(0, &(&2 + value.(Map.fetch!(days, &1)) - weekly.(weekday(&1))))

    div(total, 7) * week + rest + exceptions
  end

  # The hours of an ISO day of the week, ignoring the exceptions of the calendar.
  defp weekday_hours(calendar, day),
    do: if(day in calendar.work_days, do: calendar.hours, else: [])

  defp hours_minutes(hours), do: Enum.sum_by(hours, fn {from, to} -> to - from end)

  # The working minutes of `day` between the minutes `low` and `high`.
  defp clipped_minutes(calendar, day, low, high) do
    calendar
    |> hours_on(day)
    |> Enum.sum_by(fn {a, b} -> max(min(b, high) - max(a, low), 0) end)
  end

  # -- day numbers -------------------------------------------------------------

  defp day_number(%NaiveDateTime{} = datetime),
    do: datetime |> NaiveDateTime.to_date() |> Date.to_gregorian_days()

  # ISO day of the week (1 = Monday): day 0 (0000-01-01) is a Saturday
  defp weekday(day), do: rem(day + 5, 7) + 1

  defp hours_on(%{index: {days, _sorted}} = calendar, day) do
    case days do
      %{^day => hours} -> hours
      _ -> weekday_hours(calendar, weekday(day))
    end
  end

  # Position of the first exception on `day` or later (binary search)
  defp first_at_least(sorted, day), do: first_at_least(sorted, day, 0, tuple_size(sorted))

  defp first_at_least(_sorted, _day, low, high) when low >= high, do: low

  defp first_at_least(sorted, day, low, high) do
    middle = div(low + high, 2)

    if elem(sorted, middle) < day,
      do: first_at_least(sorted, day, middle + 1, high),
      else: first_at_least(sorted, day, low, middle)
  end

  defp exceptions_from(sorted, position, last) do
    if position < tuple_size(sorted) and elem(sorted, position) <= last,
      do: [elem(sorted, position) | exceptions_from(sorted, position + 1, last)],
      else: []
  end

  defp exception_between?(%{index: {_days, sorted}}, first, last) do
    position = first_at_least(sorted, first)
    position < tuple_size(sorted) and elem(sorted, position) <= last
  end

  # -- walking -----------------------------------------------------------------

  # The `n`th working day from `day` (included), walking by `step` (1 or -1).
  # Whole weeks without exceptions are skipped at once: any 7 days hold every
  # working day of the week once.
  defp nth_working_day(calendar, day, n, step), do: nth_working_day(calendar, day, n, step, 0)

  defp nth_working_day(_calendar, day, _n, _step, guard) when guard > @max_days, do: day

  defp nth_working_day(calendar, day, n, step, guard) do
    per_week = if calendar.hours == [], do: 0, else: length(calendar.work_days)
    weeks = if per_week > 0, do: div(n - 1, per_week), else: 0
    skipped = day + step * (weeks * 7 - 1)

    cond do
      weeks > 0 and not exception_between?(calendar, min(day, skipped), max(day, skipped)) ->
        nth_working_day(calendar, skipped + step, n - weeks * per_week, step, guard + weeks * 7)

      hours_on(calendar, day) == [] ->
        nth_working_day(calendar, day + step, n, step, guard + 1)

      n <= 1 ->
        day

      true ->
        nth_working_day(calendar, day + step, n - 1, step, guard + 1)
    end
  end

  # Consumes `minutes` of working time from `datetime` forward. With 0 minutes
  # it returns the next working minute.
  defp walk_forward(calendar, datetime, minutes),
    do: walk_forward(calendar, day_number(datetime), minute_of_day(datetime), minutes, 0)

  defp walk_forward(_calendar, day, minute, _minutes, guard) when guard > @max_days,
    do: at_minute(day, minute)

  defp walk_forward(calendar, day, minute, minutes, guard) do
    result =
      calendar
      |> hours_on(day)
      |> Enum.reduce_while(minutes, fn {from, to}, left ->
        start = max(from, minute)

        cond do
          start >= to -> {:cont, left}
          left == 0 -> {:halt, {:at, start}}
          start + left <= to -> {:halt, {:at, start + left}}
          true -> {:cont, left - (to - start)}
        end
      end)

    case result do
      {:at, minute} -> at_minute(day, minute)
      left -> walk_forward(calendar, day + 1, 0, left, guard + 1)
    end
  end

  defp walk_backward(calendar, datetime, minutes) do
    case minute_of_day(datetime) do
      0 -> walk_backward(calendar, day_number(datetime) - 1, 1440, minutes, 0)
      minute -> walk_backward(calendar, day_number(datetime), minute, minutes, 0)
    end
  end

  defp walk_backward(_calendar, day, minute, _minutes, guard) when guard > @max_days,
    do: at_minute(day, minute)

  defp walk_backward(calendar, day, minute, minutes, guard) do
    result =
      calendar
      |> hours_on(day)
      |> Enum.reverse()
      |> Enum.reduce_while(minutes, fn {from, to}, left ->
        finish = min(to, minute)

        cond do
          finish <= from -> {:cont, left}
          finish - left >= from -> {:halt, {:at, finish - left}}
          true -> {:cont, left - (finish - from)}
        end
      end)

    case result do
      {:at, minute} -> at_minute(day, minute)
      left -> walk_backward(calendar, day - 1, 1440, left, guard + 1)
    end
  end

  defp minute_of_day(%NaiveDateTime{hour: h, minute: m}), do: h * 60 + m

  defp at_midnight(day), do: NaiveDateTime.new!(Date.from_gregorian_days(day), ~T[00:00:00])

  defp at_minute(day, 1440), do: at_midnight(day + 1)

  defp at_minute(day, minute) do
    NaiveDateTime.new!(
      Date.from_gregorian_days(day),
      Time.new!(div(minute, 60), rem(minute, 60), 0)
    )
  end
end
