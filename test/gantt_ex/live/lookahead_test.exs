defmodule GanttEx.Live.LookaheadTest do
  use GanttEx.LiveCase, async: true

  alias GanttEx.Event

  # Today is Wednesday 2025-01-08: the current week starts on Monday the 6th
  # (Sunday the 5th with `week_start: 7`). Design: 6-8, Build: 9-13,
  # Launch: 16.

  defp shown_rows(view) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(".gx-row")
    |> Enum.map(&(&1 |> LazyHTML.attribute("data-gx-row") |> hd()))
  end

  defp pick(view, weeks), do: view |> element("#gantt-lookahead-#{weeks}") |> render_click()

  test "shows the tasks of the chosen weeks from the current week", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn, filters: [:search, :lookahead], zoom: :week)
    assert has_element?(view, "#gantt-lookahead-toggle", "Lookahead")
    assert has_element?(view, "#gantt-lookahead-off[aria-checked=true]", "Whole schedule")
    refute has_element?(view, "#gantt-filters-toggle")

    pick(view, 1)

    assert shown_rows(view) == ["1", "2", "3"]
    assert_gantt_event(%Event{type: :filters_changed, filters: %{lookahead: 1}})
    assert has_element?(view, "#gantt-lookahead-1[aria-checked=true]")
    assert has_element?(view, "#gantt-lookahead-toggle .gx-badge", "1 week")

    assert has_element?(
             view,
             "#gantt-filter-lookahead-active",
             "1 week · 01/06/2025 – 01/12/2025"
           )

    # only the week is shown, day by day
    assert has_element?(view, "#gantt.gx-root--windowed")
    assert has_element?(view, "#gantt-zoom-day[aria-pressed=true]")
    assert has_element?(view, "#gantt-chart[style*='width: 336px']")

    pick(view, 2)
    assert_gantt_event(%Event{filters: %{lookahead: 2}})
    assert shown_rows(view) == ["1", "2", "3", "4"]
    assert has_element?(view, "#gantt-chart[style*='width: 672px']")

    view |> element("#gantt-lookahead-off") |> render_click()
    assert_gantt_event(%Event{type: :filters_changed, filters: filters})
    assert filters == %{}
    refute has_element?(view, "#gantt.gx-root--windowed")
    refute has_element?(view, "#gantt-filter-bar")
  end

  test "weeks start on the first day of the week of the chart", %{conn: conn} do
    {:ok, view, _html} =
      mount_gantt(conn, filters: [:lookahead], week_start: 7, filter_values: %{lookahead: 1})

    assert has_element?(view, "#gantt-filter-lookahead-active", "01/05/2025 – 01/11/2025")
    assert shown_rows(view) == ["1", "2", "3"]
  end

  test "is restored from the filter values and kept by the filter panel", %{conn: conn} do
    {:ok, view, _html} =
      mount_gantt(conn,
        filters: [:type, %{id: :lookahead, weeks: [2, 4]}],
        filter_values: %{lookahead: 2}
      )

    assert has_element?(view, "#gantt-lookahead-2[aria-checked=true]")
    refute has_element?(view, "#gantt-lookahead-1")
    assert has_element?(view, "#gantt-lookahead-4")

    # the panel has no lookahead field: changing it keeps the lookahead
    view |> element("#gantt-filters-toggle") |> render_click()
    refute has_element?(view, "#gantt-filter-lookahead")

    view
    |> element("#gantt-filters-form")
    |> render_change(%{"filters" => %{"type" => ["task"]}})

    assert_gantt_event(%Event{filters: %{lookahead: 2, type: [:task]}})
    assert shown_rows(view) == ["1", "2", "3"]
    assert has_element?(view, "#gantt-filters-toggle .gx-badge", "1")
  end

  test "a restored lookahead is shown day by day too", %{conn: conn} do
    {:ok, view, _html} =
      mount_gantt(conn, filters: [:lookahead], filter_values: %{lookahead: 1}, zoom: :week)

    assert has_element?(view, "#gantt-zoom-day[aria-pressed=true]")
  end

  test "its days fill the width of the viewport", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn, filters: [:lookahead], filter_values: %{lookahead: 1})
    assert has_element?(view, "#gantt-chart[style*='width: 336px']")

    view |> element("#gantt") |> render_hook("gx:width", %{"width" => 2000})

    [_, width] = Regex.run(~r/--gx-column-width: (\d+)px/, render(view))
    width = String.to_integer(width)
    assert width > 48
    assert has_element?(view, "#gantt-chart[style*='width: #{width * 7}px']")
  end

  test "without a lookahead the width of the viewport changes nothing", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn)
    html = render(view)
    view |> element("#gantt") |> render_hook("gx:width", %{"width" => 2000})
    assert render(view) =~ "--gx-column-width: 48px"
    assert html =~ "--gx-column-width: 48px"
  end

  test "is not offered by default", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn)
    refute has_element?(view, "#gantt-lookahead")
  end
end
