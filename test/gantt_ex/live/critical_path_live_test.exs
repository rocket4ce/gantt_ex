defmodule GanttEx.Live.CriticalPathLiveTest do
  use GanttEx.LiveCase, async: true

  test "the toolbar toggles the critical path", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn)
    refute has_element?(view, ".gx-bar--critical")

    view |> element("#gantt-critical-path") |> render_click()

    assert has_element?(view, "#gantt-critical-path[aria-pressed=true]")
    # Build ends two days before Launch, so only Launch is critical
    assert has_element?(view, "#gantt-bar-4.gx-bar--critical")
    refute has_element?(view, "#gantt-bar-3.gx-bar--critical")

    # Build now ends on Jan 16: Design -> Build -> Launch becomes critical
    view
    |> element("#gantt")
    |> render_hook("gx:drag", %{"key" => "3", "mode" => "end", "x" => 384, "width" => 336})

    assert has_element?(view, "#gantt-bar-2.gx-bar--critical")
    assert has_element?(view, "#gantt-bar-3.gx-bar--critical")
    assert has_element?(view, "#gantt-bar-1.gx-bar--critical")
    assert has_element?(view, "g.gx-link--critical[data-gx-link='1']")
    assert has_element?(view, "g.gx-link--critical[data-gx-link='2']")

    view |> element("#gantt-critical-path") |> render_click()
    refute has_element?(view, ".gx-bar--critical")
  end

  test "tasks with little slack are marked as near-critical", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn, critical_path: true, near_critical: 2, legend: true)

    # Design and Build have two days of slack before Launch, which is critical
    assert has_element?(view, "#gantt-bar-2.gx-bar--near-critical")
    assert has_element?(view, "#gantt-bar-3.gx-bar--near-critical")
    refute has_element?(view, "#gantt-bar-4.gx-bar--near-critical")
    refute has_element?(view, "#gantt-bar-1.gx-bar--near-critical")
    assert has_element?(view, "#gantt-legend-near-critical", "Near-critical (≤ 2 days)")

    # hidden with the critical path
    view |> element("#gantt-critical-path") |> render_click()
    refute has_element?(view, ".gx-bar--near-critical")
    refute has_element?(view, "#gantt-legend-near-critical")

    # one day of slack is not enough to mark them
    {:ok, view, _html} = mount_gantt(conn, critical_path: true, near_critical: 1)
    refute has_element?(view, ".gx-bar--near-critical")
  end

  test "free slack is drawn after the bars", %{conn: conn} do
    # Build ends on Jan 14, Launch is on Jan 16: two days of free slack
    {:ok, view, _html} = mount_gantt(conn, show_slack: true)
    assert has_element?(view, "#gantt-bar-3 .gx-slack[style='width: 96px']")
    refute has_element?(view, "#gantt-bar-2 .gx-slack")
  end
end
