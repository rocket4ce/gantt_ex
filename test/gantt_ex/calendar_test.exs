defmodule GanttEx.CalendarTest do
  use ExUnit.Case, async: true

  alias GanttEx.{Calendar, Store}

  setup do
    {:ok, calendar: Calendar.new!(holidays: ["2025-01-08"], working_dates: ["2025-01-11"])}
  end

  test "holidays and extra working dates override the week", %{calendar: calendar} do
    refute Calendar.working_day?(calendar, ~D[2025-01-08])
    assert Calendar.working_day?(calendar, ~D[2025-01-11])
    refute Calendar.working_day?(calendar, ~D[2025-01-12])
  end

  test "custom hours for a working date" do
    calendar = Calendar.new!(working_dates: %{~D[2025-01-11] => ["09:00-13:00"]})
    assert Calendar.working_minutes(calendar, ~D[2025-01-11]) == 240
  end

  test "day arithmetic skips non-working days in both directions", %{calendar: calendar} do
    # Tue 7 -> (Wed 8 is a holiday) -> Thu 9
    assert Calendar.add(calendar, ~N[2025-01-07 00:00:00], 2, :day) == ~N[2025-01-10 00:00:00]
    # Fri 10, Sat 11 (worked), Mon 13
    assert Calendar.add(calendar, ~N[2025-01-10 00:00:00], 3, :day) == ~N[2025-01-14 00:00:00]
    assert Calendar.add(calendar, ~N[2025-01-10 00:00:00], -2, :day) == ~N[2025-01-07 00:00:00]
    assert Calendar.diff(calendar, ~N[2025-01-07 00:00:00], ~N[2025-01-14 00:00:00], :day) == 5
  end

  test "long ranges count whole weeks and then the exceptions", %{calendar: calendar} do
    # a holiday on a Sunday changes nothing
    calendar = %{calendar | dates: Map.put(calendar.dates, ~D[2025-01-12], [])}

    for last <- Date.range(~D[2025-01-06], ~D[2025-04-30]) do
      expected =
        Enum.count(Date.range(~D[2025-01-06], last), &Calendar.working_day?(calendar, &1))

      to = NaiveDateTime.new!(Date.add(last, 1), ~T[00:00:00])
      assert Calendar.diff(calendar, ~N[2025-01-06 00:00:00], to, :day) == expected
    end

    # Mon 6 from 10:00 (6h), 41 full working days (328h), Wed Mar 5 until 10:00 (2h)
    assert Calendar.diff(calendar, ~N[2025-01-06 10:00:00], ~N[2025-03-05 10:00:00], :hour) ==
             336
  end

  test "hour arithmetic walks across days and lunch breaks" do
    calendar = Calendar.new!()
    assert Calendar.add(calendar, ~N[2025-01-10 15:00:00], 4, :hour) == ~N[2025-01-13 10:00:00]
    assert Calendar.add(calendar, ~N[2025-01-13 10:00:00], -4, :hour) == ~N[2025-01-10 15:00:00]
    assert Calendar.diff(calendar, ~N[2025-01-10 15:00:00], ~N[2025-01-13 10:00:00], :hour) == 4
    assert Calendar.add(calendar, ~N[2025-01-06 08:00:00], 8, :hour) == ~N[2025-01-06 17:00:00]
  end

  test "end of day boundaries" do
    calendar = Calendar.new!(hours: [{0, 24}], work_days: 1..7)
    assert Calendar.add(calendar, ~N[2025-01-06 20:00:00], 4, :hour) == ~N[2025-01-07 00:00:00]
    assert Calendar.add(calendar, ~N[2025-01-07 00:00:00], -4, :hour) == ~N[2025-01-06 20:00:00]
  end

  test "rejects invalid options" do
    assert {:error, {:invalid, :work_days}} = Calendar.new(work_days: [0, 8])
    assert {:error, {:invalid, :hours}} = Calendar.new(hours: [{12, 8}])
    assert {:error, {:invalid, :hours}} = Calendar.new(hours: ["25:00-26:00"])
    assert {:error, {:invalid, :dates}} = Calendar.new(holidays: ["someday"])
  end

  test "tasks use their own calendar" do
    store =
      Store.new!(
        [
          %{id: 1, start_date: ~D[2025-01-10], duration: 2},
          %{id: 2, start_date: ~D[2025-01-10], duration: 2, calendar_id: "weekends"}
        ],
        [],
        work_time: true,
        calendars: [[id: "weekends", work_days: 1..7]]
      )

    assert Store.get_task(store, 1).end_date == ~N[2025-01-14 00:00:00]
    assert Store.get_task(store, 2).end_date == ~N[2025-01-12 00:00:00]
  end

  test "moving a task keeps its working duration" do
    store = Store.new!([%{id: 1, start_date: ~D[2025-01-06], duration: 5}], [], work_time: true)
    {:ok, store, _changes} = Store.update_task(store, 1, %{start_date: ~D[2025-01-09]})
    task = Store.get_task(store, 1)

    assert {task.start_date, task.end_date, task.duration} ==
             {~N[2025-01-09 00:00:00], ~N[2025-01-16 00:00:00], 5}
  end

  test "long durations skip whole weeks, but not the exceptions inside them" do
    calendar = Calendar.new!(holidays: [~D[2025-03-03]], working_dates: [~D[2025-03-15]])
    start = ~N[2025-01-06 00:00:00]

    # 60 working days from Monday Jan 6 are 12 weeks (the last day is Friday
    # Mar 28): the Saturday worked and the holiday cancel out
    assert Calendar.add(calendar, start, 60, :day) == ~N[2025-03-29 00:00:00]
    assert Calendar.diff(calendar, start, ~N[2025-03-29 00:00:00], :day) == 60
    assert Calendar.add(calendar, ~N[2025-03-29 00:00:00], -60, :day) == start

    # without exceptions, the same 60 days end at the same place
    plain = Calendar.new!()
    assert Calendar.add(plain, start, 60, :day) == ~N[2025-03-29 00:00:00]

    # a struct built by hand works too
    hand_made = %Calendar{dates: %{~D[2025-01-07] => []}}
    assert Calendar.add(hand_made, start, 2, :day) == ~N[2025-01-09 00:00:00]
  end
end
