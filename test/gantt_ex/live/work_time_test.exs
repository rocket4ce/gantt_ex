defmodule GanttEx.Live.WorkTimeTest do
  use GanttEx.LiveCase, async: true

  alias GanttEx.Event

  @calendar [holidays: [~D[2025-01-07]]]

  test "durations count working days and starts snap to working days", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn, work_time: true, calendar: @calendar)

    # Design: Mon 6 + 3 working days, Tue 7 is a holiday -> ends Thu 9 (exclusive Fri 10)
    assert has_element?(view, "#gantt-row-2 [role=gridcell]", "01/09/2025")

    # dropped on Saturday 11 (10 * 48 = 480): starts on Monday 13
    view
    |> element("#gantt")
    |> render_hook("gx:drag", %{"key" => "2", "mode" => "move", "x" => 480, "width" => 144})

    assert_gantt_event(%Event{type: :task_updated, task: task})
    assert {task.start_date, task.end_date} == {~N[2025-01-13 00:00:00], ~N[2025-01-16 00:00:00]}
  end

  # Design is Mon 6 - Wed 8 (end Thu 9 at 00:00); a day is 48px from Jan 1
  test "a bar resized onto a weekend grows to the next working day", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn, work_time: true)

    # the end over Saturday 11 (Sunday 12 at 00:00 is 11 * 48 = 528): ends on Monday 13
    view
    |> element("#gantt")
    |> render_hook("gx:drag", %{"key" => "2", "mode" => "end", "x" => 240, "width" => 288})

    assert_gantt_event(%Event{type: :task_updated, task: task})
    assert {task.end_date, task.duration} == {~N[2025-01-14 00:00:00], 6}

    # the start back to Sunday 5 (4 * 48 = 192): starts on Friday 3
    view
    |> element("#gantt")
    |> render_hook("gx:drag", %{"key" => "2", "mode" => "start", "x" => 192, "width" => 432})

    assert_gantt_event(%Event{type: :task_updated, task: task})
    assert {task.start_date, task.duration} == {~N[2025-01-03 00:00:00], 7}
  end

  test "with resize_snap: :shrink it shrinks to the previous working day", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn, work_time: true, resize_snap: :shrink)

    view
    |> element("#gantt")
    |> render_hook("gx:drag", %{"key" => "2", "mode" => "end", "x" => 240, "width" => 288})

    assert_gantt_event(%Event{type: :task_updated, task: task})
    assert {task.end_date, task.duration} == {~N[2025-01-11 00:00:00], 5}

    # the start back to Sunday 5 stays on Monday 6: nothing changes
    view
    |> element("#gantt")
    |> render_hook("gx:drag", %{"key" => "2", "mode" => "start", "x" => 192, "width" => 336})

    refute_receive {:gantt_event, %Event{type: :task_updated}}, 100
  end

  test "holidays are highlighted like weekends", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn, work_time: true, calendar: @calendar)

    assert has_element?(view, ".gx-scale-cell--weekend", "Tue 7")
    refute has_element?(view, ".gx-scale-cell--weekend", "Mon 6")
  end
end
