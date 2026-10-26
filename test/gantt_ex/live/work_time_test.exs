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

  test "holidays are highlighted like weekends", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn, work_time: true, calendar: @calendar)

    assert has_element?(view, ".gx-scale-cell--weekend", "Tue 7")
    refute has_element?(view, ".gx-scale-cell--weekend", "Mon 6")
  end
end
