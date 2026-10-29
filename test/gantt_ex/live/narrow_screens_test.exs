defmodule GanttEx.Live.NarrowScreensTest do
  @moduledoc """
  The timeline stays usable on narrow screens: the grid takes at most 60% of
  the chart (its saved width is kept), and on a phone it shows the names
  only, with a toggle for the whole grid. Resizing there saves nothing.
  """
  use GanttEx.LiveCase, async: true

  alias GanttEx.Event

  @layout %{order: [], hidden: [], widths: %{}, grid_width: 752}

  defp grid_width(view) do
    [_, width] = Regex.run(~r/--gx-grid-width: (\d+)px/, render(view))
    String.to_integer(width)
  end

  defp width(view, width),
    do: view |> element("#gantt") |> render_hook("gx:width", %{"width" => width})

  test "the grid takes at most 60% of the chart, keeping its saved width", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn, column_layout: @layout)
    assert grid_width(view) == 752

    width(view, 900)
    assert grid_width(view) <= 540

    width(view, 1600)
    assert grid_width(view) == 752
    refute_received {:gantt_event, %Event{type: :columns_changed}}
  end

  test "on a phone the grid shows the names, and the whole grid on demand", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn, column_layout: @layout, progress_column: true)
    refute has_element?(view, "#gantt-grid-toggle")

    width(view, 390)
    # the timeline keeps at least 70% of the width
    assert grid_width(view) <= 117
    assert has_element?(view, "#gantt-grid-toggle[aria-pressed=false]")
    assert has_element?(view, ".gx-row", "Design")
    refute render(view) =~ "--gx-col-1:"

    view |> element("#gantt-grid-toggle") |> render_click()
    assert has_element?(view, "#gantt-grid-toggle[aria-pressed=true]")
    assert render(view) =~ "--gx-col-1:"
    assert grid_width(view) <= 351

    view |> element("#gantt-grid-toggle") |> render_click()
    refute render(view) =~ "--gx-col-1:"
  end

  test "resizing the grid on a phone doesn't change the saved layout", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn, column_layout: @layout)
    width(view, 390)

    view |> element("#gantt") |> render_hook("gx:resize", %{"column" => "__grid", "width" => 200})
    assert grid_width(view) == 200

    view |> element("#gantt") |> render_hook("gx:resize", %{"column" => "text", "width" => 300})
    refute_received {:gantt_event, %Event{type: :columns_changed}}

    # back on a wide screen, the saved width
    width(view, 1600)
    assert grid_width(view) == 752
  end
end
