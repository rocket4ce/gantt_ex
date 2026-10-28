defmodule GanttEx.Live.NavigationTest do
  use GanttEx.LiveCase, async: true

  test "clicking a row selects the task and notifies the parent", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn)

    view |> element("#gantt-row-2") |> render_click()

    assert has_element?(view, "#gantt-row-2.gx-row--selected[aria-selected=true]")
    assert has_element?(view, "#gantt-bar-2.gx-bar--selected")
    assert_gantt_event(%GanttEx.Event{type: :task_selected, gantt_id: "gantt", task: %{id: 2}})
  end

  test "clicking a bar opens the quick info", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn)

    view |> element("#gantt-bar-3") |> render_click()
    assert has_element?(view, "#gantt-quick-info", "Build")

    view |> element("#gantt-quick-info .gx-popup-close") |> render_click()
    refute has_element?(view, "#gantt-quick-info")
  end

  test "the quick info opens where the bar was clicked", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn)
    bar_x = style_px(view, "#gantt-bar-3", "--gx-x")

    # The hook sends where the bar was clicked, from its start
    view |> element("#gantt-bar-3") |> render_click(%{"offset" => "40"})
    assert style_px(view, "#gantt-quick-info", "left") == bar_x + 40

    # Without it (no JavaScript, or a forged value) the popup opens at the start of the bar
    view |> element("#gantt-bar-3") |> render_click(%{"offset" => "wide"})
    assert style_px(view, "#gantt-quick-info", "left") == bar_x
  end

  test "branches can be collapsed and expanded", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn)

    view |> element("#gantt-row-1 .gx-toggle") |> render_click()
    refute has_element?(view, "#gantt-row-2")
    refute has_element?(view, "#gantt-bar-2")
    assert has_element?(view, "#gantt-row-1[aria-expanded=false]")

    view |> element("#gantt-expand-all") |> render_click()
    assert has_element?(view, "#gantt-row-2")

    view |> element("#gantt-collapse-all") |> render_click()
    refute has_element?(view, "#gantt-row-3")
  end

  test "tasks with open: false start collapsed", %{conn: conn} do
    tasks = List.update_at(sample_tasks(), 0, &Map.put(&1, :open, false))
    {:ok, view, _html} = mount_gantt(conn, tasks: tasks)

    refute has_element?(view, "#gantt-row-2")
  end

  test "zoom levels change the scale", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn)

    view |> element("#gantt-zoom-month") |> render_click()
    assert has_element?(view, "#gantt-zoom-month.gx-segment--active")
    assert has_element?(view, ".gx-scale-cell", "Jan")

    view |> element("#gantt-zoom-in") |> render_click()
    assert has_element?(view, "#gantt-zoom-week.gx-segment--active")
  end

  test "columns can be sorted", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn)

    view |> element("[role=columnheader] button.gx-sort", "Task name") |> render_click()
    assert has_element?(view, "[role=columnheader][aria-sort=ascending]")
    # sorting disables row reordering
    assert has_element?(view, "#gantt[data-gx-reorder=false]")

    view |> element("[role=columnheader] button.gx-sort", "Task name") |> render_click()
    assert has_element?(view, "[role=columnheader][aria-sort=descending]")
  end

  describe "keyboard" do
    test "arrows move the selection", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)

      view |> element("#gantt-viewport") |> render_keydown(%{"key" => "ArrowDown"})
      assert has_element?(view, "#gantt-row-1.gx-row--selected")

      view |> element("#gantt-viewport") |> render_keydown(%{"key" => "ArrowDown"})
      assert has_element?(view, "#gantt-row-2.gx-row--selected")
      assert_push_event(view, "gantt_ex:scroll", %{id: "gantt", y: 36, height: 36})

      view |> element("#gantt-viewport") |> render_keydown(%{"key" => "End"})
      assert has_element?(view, "#gantt-row-4.gx-row--selected")
    end

    test "left and right collapse and expand", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)

      view |> element("#gantt-row-1") |> render_click()
      view |> element("#gantt-viewport") |> render_keydown(%{"key" => "ArrowLeft"})
      refute has_element?(view, "#gantt-row-2")

      view |> element("#gantt-viewport") |> render_keydown(%{"key" => "ArrowRight"})
      assert has_element?(view, "#gantt-row-2")
    end

    test "enter opens the lightbox and delete asks for confirmation", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)

      view |> element("#gantt-row-3") |> render_click()
      view |> element("#gantt-viewport") |> render_keydown(%{"key" => "Enter"})
      assert has_element?(view, "#gantt-lightbox")

      view |> element("#gantt-lightbox-form") |> render_submit(%{"task" => %{"text" => "Build"}})
      view |> element("#gantt-viewport") |> render_keydown(%{"key" => "Delete"})
      assert has_element?(view, "#gantt-confirm")
    end
  end

  test "the today button scrolls the chart", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn)

    view |> element("#gantt-today") |> render_click()
    # January 8th, 10:00 in a day-scale that starts on January 1st (48px columns)
    assert_push_event(view, "gantt_ex:scroll", %{id: "gantt", x: 356.0})
  end

  test "exports push a download to the browser", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn)

    view |> element("#gantt-export-csv") |> render_click()

    assert_push_event(view, "gantt_ex:download", %{
      filename: "gantt.csv",
      mime: "text/csv",
      content: csv
    })

    assert csv =~ "Design"

    view |> element("#gantt-export-png") |> render_click()

    assert_push_event(view, "gantt_ex:download", %{
      filename: "gantt.png",
      convert: "png",
      content: "<svg" <> _
    })

    view |> element("#gantt-export-json") |> render_click()
    assert_push_event(view, "gantt_ex:download", %{filename: "gantt.json", content: json})
    assert %{"data" => [_, _, _, _], "links" => [_, _]} = JSON.decode!(json)
  end

  test "the parent can control the chart", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn)

    run_in_parent(view, fn -> GanttEx.Live.Gantt.zoom("gantt", :quarter) end)
    assert has_element?(view, "#gantt-zoom-quarter.gx-segment--active")

    run_in_parent(view, fn -> GanttEx.Live.Gantt.select("gantt", 3) end)
    assert has_element?(view, "#gantt-row-3.gx-row--selected")
  end

  defp style_px(view, selector, property) do
    [style] =
      view
      |> element(selector)
      |> render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.attribute("style")

    [_, value] = Regex.run(~r/(?:^|;)\s*#{Regex.escape(property)}:\s*(-?[\d.]+)px/, style)
    {number, ""} = Float.parse(value)
    number
  end
end
