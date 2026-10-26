defmodule GanttEx.Live.GroupingTest do
  use GanttEx.LiveCase, async: true

  alias GanttEx.Event

  defp row_order(view) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(".gx-row")
    |> Enum.map(&(&1 |> LazyHTML.attribute("data-gx-row") |> hd()))
  end

  test "groups tasks by a meta field", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn, group_by: :owner)

    assert row_order(view) == ["g:Ana", "2", "g:Luis", "3", "g:none", "4"]
    assert has_element?(view, "[data-gx-row='g:Ana'] .gx-count", "1")
    assert has_element?(view, "[data-gx-row='g:none']", "Unassigned")
    # projects with children are not grouped, reordering is disabled
    refute has_element?(view, "[data-gx-row='1']")
    assert has_element?(view, "#gantt[data-gx-reorder=false]")
    # group summary bars cannot be dragged nor linked
    assert has_element?(view, "[data-gx-bar='g:Ana'][data-gx-drag=none]")
    refute has_element?(view, "[data-gx-bar='g:Ana'] .gx-link-point")
  end

  test "tasks appear under each of their resources", %{conn: conn} do
    tasks =
      sample_tasks()
      |> List.update_at(1, &Map.put(&1, :resources, ["ana", "luis"]))
      |> List.update_at(2, &Map.put(&1, :resources, ["luis"]))

    resources = [%{id: "ana", text: "Ana"}, %{id: "luis", text: "Luis"}]

    {:ok, view, _html} =
      mount_gantt(conn, tasks: tasks, resources: resources, group_by: :resources)

    assert row_order(view) == ["g:ana", "2", "g:luis", "2", "3", "g:none", "4"]
    assert has_element?(view, "[data-gx-row='g:luis']", "Luis")
    # the same task gets one bar per group
    assert view
           |> render()
           |> LazyHTML.from_fragment()
           |> LazyHTML.query("[data-gx-bar='2']")
           |> Enum.count() == 2
  end

  test "groups collapse and keyboard navigation skips them", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn, group_by: :owner)

    view |> element("[data-gx-row='g:Ana'] .gx-toggle") |> render_click()
    refute has_element?(view, "[data-gx-row='2']")

    view |> element("#gantt-viewport") |> render_keydown(%{"key" => "ArrowDown"})
    assert has_element?(view, "[data-gx-row='3'].gx-row--selected")
  end

  test "tasks in groups are still editable", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn, group_by: :owner)

    view
    |> element("#gantt")
    |> render_hook("gx:drag", %{"key" => "3", "mode" => "progress", "progress" => 0.5})

    assert_gantt_event(%Event{type: :task_updated, task: %{id: 3, progress: 0.5}})
  end
end
