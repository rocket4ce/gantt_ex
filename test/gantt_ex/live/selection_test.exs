defmodule GanttEx.Live.SelectionTest do
  use GanttEx.LiveCase, async: true

  alias GanttEx.Event

  defp hook(view, event, params), do: view |> element("#gantt") |> render_hook(event, params)

  test "ctrl+click toggles tasks in the selection", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn)

    view |> element("#gantt-row-2") |> render_click()
    hook(view, "gx:select", %{"key" => "4", "mode" => "toggle"})

    assert has_element?(view, "#gantt-row-2.gx-row--selected")
    assert has_element?(view, "#gantt-row-4.gx-row--selected")
    assert has_element?(view, "#gantt-bar-4.gx-bar--selected")
    assert_gantt_event(%Event{type: :task_selected, task: %{id: 4}, selection: selection})
    assert Enum.sort(selection) == [2, 4]

    hook(view, "gx:select", %{"key" => "2", "mode" => "toggle"})
    refute has_element?(view, "#gantt-row-2.gx-row--selected")
    assert has_element?(view, "#gantt-row-4.gx-row--selected")
  end

  test "shift+click selects a range of rows", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn)

    view |> element("#gantt-row-1") |> render_click()
    hook(view, "gx:select", %{"key" => "3", "mode" => "range"})

    for id <- 1..3, do: assert(has_element?(view, "#gantt-row-#{id}.gx-row--selected"))
    refute has_element?(view, "#gantt-row-4.gx-row--selected")
  end

  test "a plain click goes back to a single selection", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn)

    view |> element("#gantt-row-2") |> render_click()
    hook(view, "gx:select", %{"key" => "3", "mode" => "toggle"})
    view |> element("#gantt-row-4") |> render_click()

    refute has_element?(view, "#gantt-row-2.gx-row--selected")
    refute has_element?(view, "#gantt-row-3.gx-row--selected")
  end

  test "deletes the selected tasks at once", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn)

    view |> element("#gantt-row-3") |> render_click()
    hook(view, "gx:select", %{"key" => "4", "mode" => "toggle"})
    view |> element("#gantt-viewport") |> render_keydown(%{"key" => "Delete"})

    assert has_element?(view, "#gantt-confirm", "Are you sure you want to delete these 2 tasks?")
    view |> element("#gantt-confirm-yes") |> render_click()

    refute has_element?(view, "#gantt-row-3")
    refute has_element?(view, "#gantt-row-4")
    assert_gantt_event(%Event{type: :task_deleted, task: %{id: 3}})
    assert_gantt_event(%Event{type: :task_deleted, task: %{id: 4}})

    # a single undo step brings both back
    hook(view, "undo", %{})
    assert has_element?(view, "#gantt-row-3")
    assert has_element?(view, "#gantt-row-4")
  end

  test "dragging a selected bar moves the whole selection", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn)

    view |> element("#gantt-row-2") |> render_click()
    hook(view, "gx:select", %{"key" => "4", "mode" => "toggle"})

    # Design moves two days later: from Jan 6 (240px) to Jan 8 (336px)
    hook(view, "gx:drag", %{"key" => "2", "mode" => "move", "x" => 336, "width" => 144})

    assert_gantt_event(%Event{
      type: :task_updated,
      task: %{id: 2, start_date: ~N[2025-01-08 00:00:00]}
    })

    assert_gantt_event(%Event{
      type: :task_updated,
      task: %{id: 4, start_date: ~N[2025-01-18 00:00:00]}
    })
  end
end
