defmodule GanttEx.Live.UndoTest do
  use GanttEx.LiveCase, async: true

  alias GanttEx.Event

  defp hook(view, event, params \\ %{}),
    do: view |> element("#gantt") |> render_hook(event, params)

  test "undo reverts a drag and redo applies it again", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn)
    assert has_element?(view, "#gantt-undo[disabled]")

    hook(view, "gx:drag", %{"key" => "2", "mode" => "move", "x" => 340, "width" => 144})

    assert_gantt_event(%Event{
      type: :task_updated,
      task: %{id: 2, start_date: ~N[2025-01-08 00:00:00]}
    })

    refute has_element?(view, "#gantt-undo[disabled]")

    view |> element("#gantt-undo") |> render_click()

    assert_gantt_event(%Event{
      type: :task_updated,
      task: %{id: 2},
      changes: %{start_date: ~N[2025-01-06 00:00:00]}
    })

    assert has_element?(view, "#gantt-undo[disabled]")
    refute has_element?(view, "#gantt-redo[disabled]")

    view |> element("#gantt-redo") |> render_click()

    assert_gantt_event(%Event{
      type: :task_updated,
      task: %{id: 2},
      changes: %{start_date: ~N[2025-01-08 00:00:00]}
    })
  end

  test "undoing a deletion restores the task and its links", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn)

    view |> element("#gantt-bar-3") |> render_click()
    view |> element("#gantt-quick-info-delete") |> render_click()
    view |> element("#gantt-confirm-yes") |> render_click()
    refute has_element?(view, "#gantt-row-3")

    hook(view, "undo")

    assert has_element?(view, "#gantt-row-3")
    assert has_element?(view, "g[data-gx-link='1']")
    assert_gantt_event(%Event{type: :task_created, task: %{id: 3}})
    assert_gantt_event(%Event{type: :link_created, link: %{id: 1}})
    assert_gantt_event(%Event{type: :link_created, link: %{id: 2}})
  end

  test "a new change clears the redo steps", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn)

    hook(view, "gx:drag", %{"key" => "2", "mode" => "progress", "progress" => 0.9})
    hook(view, "undo")
    hook(view, "gx:drag", %{"key" => "3", "mode" => "progress", "progress" => 0.2})

    assert has_element?(view, "#gantt-redo[disabled]")
  end

  test "undo can be disabled", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn, undo: false)

    refute has_element?(view, "#gantt-undo")
    hook(view, "gx:drag", %{"key" => "2", "mode" => "progress", "progress" => 0.9})
    assert_gantt_event(%Event{type: :task_updated})
    hook(view, "undo")
    refute_receive {:gantt_event, %Event{type: :task_updated}}, 50
  end
end
