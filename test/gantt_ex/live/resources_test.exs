defmodule GanttEx.Live.ResourcesTest do
  use GanttEx.LiveCase, async: true

  alias GanttEx.Event

  @resources [%{id: "ana", text: "Ana", capacity: 8}, %{id: "luis", text: "Luis", capacity: 8}]

  defp tasks do
    sample_tasks()
    |> List.update_at(1, &Map.put(&1, :resources, [%{resource_id: "ana", value: 6}]))
    |> List.update_at(2, &Map.put(&1, :resources, ["ana"]))
  end

  test "the resource panel shows the load of every resource", %{conn: conn} do
    {:ok, view, _html} =
      mount_gantt(conn, tasks: tasks(), resources: @resources, resource_panel: true)

    assert has_element?(view, "#gantt-resource-ana .gx-resources-name", "Ana")
    assert has_element?(view, "#gantt-resource-ana .gx-load", "6")
    assert has_element?(view, "#gantt-resource-ana .gx-load", "8")
    refute has_element?(view, "#gantt-resource-luis .gx-load")
  end

  test "overloaded resources are highlighted", %{conn: conn} do
    overlapping = List.update_at(tasks(), 2, &Map.put(&1, :start_date, ~D[2025-01-08]))

    {:ok, view, _html} =
      mount_gantt(conn, tasks: overlapping, resources: @resources, resource_panel: true)

    assert has_element?(view, "#gantt-resource-ana.gx-resources-row--overloaded")
    assert has_element?(view, "#gantt-resource-ana .gx-load--over", "14")
  end

  test "the lightbox assigns resources", %{conn: conn} do
    {:ok, view, _html} =
      mount_gantt(conn,
        tasks: tasks(),
        resources: @resources,
        lightbox_sections: [:text, :resources]
      )

    view |> element("#gantt") |> render_hook("gx:dblclick", %{"key" => "2"})
    assert has_element?(view, "#gantt-lightbox input[type=checkbox][value=ana][checked]")
    refute has_element?(view, "#gantt-lightbox input[type=checkbox][value=luis][checked]")

    view
    |> element("#gantt-lightbox-form")
    |> render_submit(%{"task" => %{"text" => "Design", "resources" => ["", "ana", "luis"]}})

    assert_gantt_event(%Event{type: :task_updated, task: task, changes: %{resources: _}})
    # the value of the existing assignment is kept
    assert task.resources == [%{id: "ana", value: 6}, %{id: "luis", value: nil}]
  end
end
