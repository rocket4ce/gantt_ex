defmodule GanttEx.Live.AutoSchedulingTest do
  use GanttEx.LiveCase, async: true

  alias GanttEx.Event

  defp hook(view, event, params), do: view |> element("#gantt") |> render_hook(event, params)

  test "moving a task pushes its successors", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn, auto_scheduling: true)

    # Design: Jan 6 -> Jan 8 (ends Jan 11); Build must now start on Jan 11
    hook(view, "gx:drag", %{"key" => "2", "mode" => "move", "x" => 336, "width" => 144})

    assert_gantt_event(%Event{
      type: :task_updated,
      task: %{id: 2, start_date: ~N[2025-01-08 00:00:00]}
    })

    assert_gantt_event(%Event{
      type: :task_updated,
      task: %{id: 3, start_date: ~N[2025-01-11 00:00:00]}
    })

    refute_received {:gantt_event, %Event{type: :task_updated, task: %{id: 4}}}

    # one undo step restores both tasks
    hook(view, "undo", %{})

    assert_gantt_event(%Event{
      type: :task_updated,
      task: %{id: 2, start_date: ~N[2025-01-06 00:00:00]}
    })

    assert_gantt_event(%Event{
      type: :task_updated,
      task: %{id: 3, start_date: ~N[2025-01-09 00:00:00]}
    })
  end

  test "without auto-scheduling dependencies are not enforced", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn)

    hook(view, "gx:drag", %{"key" => "2", "mode" => "move", "x" => 336, "width" => 144})
    assert_gantt_event(%Event{type: :task_updated, task: %{id: 2}})
    refute_received {:gantt_event, %Event{type: :task_updated, task: %{id: 3}}}
  end

  test "the lightbox sets constraints", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn, auto_scheduling: true)

    hook(view, "gx:dblclick", %{"key" => "4"})
    assert has_element?(view, "#gantt-lightbox select[name='task[constraint_type]']")

    view
    |> element("#gantt-lightbox-form")
    |> render_change(%{"task" => %{"text" => "Launch", "constraint_type" => "mso"}})

    assert has_element?(view, "#gantt-lightbox input[name='task[constraint_date]']")

    view
    |> element("#gantt-lightbox-form")
    |> render_submit(%{
      "task" => %{"text" => "Launch", "constraint_type" => "mso", "constraint_date" => ""}
    })

    assert has_element?(view, "#gantt-lightbox .gx-error", "can't be blank")

    view
    |> element("#gantt-lightbox-form")
    |> render_submit(%{
      "task" => %{
        "text" => "Launch",
        "constraint_type" => "mso",
        "constraint_date" => "2025-01-20"
      }
    })

    assert_gantt_event(%Event{type: :task_updated, task: task})
    assert {task.constraint_type, task.start_date} == {:mso, ~N[2025-01-20 00:00:00]}
    assert has_element?(view, "#gantt-bar-4 .gx-constraint--mso")
  end

  test "new links schedule their target", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn, auto_scheduling: true)

    hook(view, "gx:link", %{"source" => "4", "from" => "end", "target" => "2", "to" => "start"})
    # Launch -> Design would be circular (Design -> Build -> Launch): rejected, nothing moves
    refute_received {:gantt_event, %Event{type: :task_updated}}
  end
end
