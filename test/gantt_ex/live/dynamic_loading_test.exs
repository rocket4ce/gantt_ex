defmodule GanttEx.Live.DynamicLoadingTest do
  use GanttEx.LiveCase, async: true

  alias GanttEx.Event

  @lazy [%{id: 1, text: "Archive", start_date: ~D[2025-01-06], duration: 2, has_children: true}]

  test "expanding a lazy branch requests its children", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn, tasks: @lazy, links: [])

    assert has_element?(view, "#gantt-row-1 .gx-toggle")
    view |> element("#gantt-row-1 .gx-toggle") |> render_click()

    assert_gantt_event(%Event{type: :branch_requested, task: %{id: 1}})
    assert has_element?(view, "#gantt-row-1 .gx-toggle--loading")

    # clicking again while loading does not ask twice
    view |> element("#gantt-row-1 .gx-toggle") |> render_click()
    refute_received {:gantt_event, %Event{type: :branch_requested}}

    children = [%{id: 2, text: "2024 report", parent: 1, start_date: ~D[2025-01-06], duration: 1}]
    send(view.pid, {:assign, tasks: @lazy ++ children})

    assert has_element?(view, "#gantt-row-2", "2024 report")
    refute has_element?(view, "#gantt-row-1 .gx-toggle--loading")
    assert has_element?(view, "#gantt-row-1[aria-expanded=true]")
  end

  test "auto types turn parents into projects", %{conn: conn} do
    tasks =
      List.update_at(
        sample_tasks(),
        0,
        &Map.merge(&1, %{type: :task, start_date: ~D[2025-01-01]})
      )

    {:ok, view, _html} = mount_gantt(conn, tasks: tasks, auto_types: true)

    assert has_element?(view, "#gantt-bar-1.gx-bar--project")
  end
end
