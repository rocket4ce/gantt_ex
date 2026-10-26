defmodule GanttEx.Live.BaselinesTest do
  use GanttEx.LiveCase, async: true

  alias GanttEx.Event

  defp tasks do
    sample_tasks()
    |> List.update_at(
      1,
      &Map.merge(&1, %{
        planned_start: ~D[2025-01-06],
        planned_end: ~D[2025-01-08],
        deadline: ~D[2025-01-07]
      })
    )
    |> List.update_at(2, &Map.put(&1, :deadline, ~D[2025-01-20]))
  end

  test "baselines are drawn below the bars", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn, tasks: tasks(), baselines: true)

    # Jan 6 (240px) to Jan 8 (336px), below the bar of row 1
    assert has_element?(view, ".gx-baseline[style*='left: 240px'][style*='width: 96px']")
    refute has_element?(view, ".gx-baseline[style*='left: 384px']")
  end

  test "deadlines mark overdue tasks", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn, tasks: tasks())

    # Design ends on Jan 9 but is due on Jan 7
    assert has_element?(view, "#gantt-bar-2.gx-bar--overdue")
    assert has_element?(view, ".gx-deadline.gx-deadline--overdue[style*='left: 336px']")
    refute has_element?(view, "#gantt-bar-3.gx-bar--overdue")
    assert has_element?(view, "#gantt-bar-2 .gx-tooltip", "Deadline")
  end

  test "the lightbox edits baselines and deadlines", %{conn: conn} do
    {:ok, view, _html} =
      mount_gantt(conn, lightbox_sections: [:text, :time, :baseline, :deadline])

    view |> element("#gantt") |> render_hook("gx:dblclick", %{"key" => "3"})

    view
    |> element("#gantt-lightbox-form")
    |> render_submit(%{
      "task" => %{
        "text" => "Build",
        "planned_start" => "2025-01-09",
        "planned_end" => "2025-01-13",
        "deadline" => "2025-01-15"
      }
    })

    assert_gantt_event(%Event{type: :task_updated, task: task})

    assert {task.planned_start, task.planned_end, task.deadline} ==
             {~N[2025-01-09 00:00:00], ~N[2025-01-14 00:00:00], ~N[2025-01-15 00:00:00]}
  end
end
