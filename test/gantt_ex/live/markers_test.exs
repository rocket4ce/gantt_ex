defmodule GanttEx.Live.MarkersTest do
  use GanttEx.LiveCase, async: true

  test "renders custom and today markers inside the timeline", %{conn: conn} do
    markers = [
      %{id: "freeze", date: ~D[2025-01-13], text: "Code freeze", color: "#0ea5e9"},
      # outside of the visible range: not rendered
      %{id: "old", date: ~D[2020-01-01], text: "Old"}
    ]

    {:ok, view, _html} = mount_gantt(conn, markers: markers, today_marker: true)

    # Jan 13 is 12 days after the start of the timeline (48px per day)
    assert has_element?(view, "#gantt-marker-freeze[style*='left: 576px']", "Code freeze")
    assert has_element?(view, "#gantt-marker-freeze[style*='--gx-marker-color: #0ea5e9']")
    assert has_element?(view, "#gantt-marker-today.gx-marker--today", "Today")
    refute has_element?(view, "#gantt-marker-old")
  end

  test "markers are off by default", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn)
    refute has_element?(view, ".gx-marker")
  end
end
