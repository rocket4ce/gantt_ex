defmodule GanttEx.Live.RenderingTest do
  use GanttEx.LiveCase, async: true

  test "renders the grid, the bars and the links", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn)

    for id <- 1..4 do
      assert has_element?(view, "#gantt-row-#{id}[role=row]")
      assert has_element?(view, "#gantt-bar-#{id}[data-gx-bar='#{id}']")
    end

    assert has_element?(view, "#gantt-bar-1.gx-bar--project[data-gx-drag=none]")
    assert has_element?(view, "#gantt-bar-2.gx-bar--task[data-gx-drag=move]")
    assert has_element?(view, "#gantt-bar-4.gx-bar--milestone")
    assert has_element?(view, "g[data-gx-link='1'] path.gx-link-line")
    assert has_element?(view, "g[data-gx-link='2'] path.gx-link-arrow")
  end

  test "renders the hook root with its configuration", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn)

    assert has_element?(view, "#gantt[phx-hook='GanttEx.Live.Hook.Gantt'][data-gx-snap='48.0']")
    assert has_element?(view, "#gantt[data-gx-reorder=true][data-gx-readonly=false]")
    assert has_element?(view, "#gantt-viewport[tabindex='0'][phx-keydown=key]")
  end

  test "renders the time scale with the today and weekend cells", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn)

    assert has_element?(view, ".gx-scale-row:first-child .gx-scale-cell", "January 2025")
    assert has_element?(view, ".gx-scale-cell--today", "Wed 8")
    assert has_element?(view, ".gx-scale-cell--weekend", "Sat 11")
    assert has_element?(view, ".gx-highlight")
  end

  test "renders custom columns with slots and meta values", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn)

    assert has_element?(view, "[role=columnheader]", "Owner")
    assert has_element?(view, "#gantt-row-2 .owner", "Ana")
    # end dates are displayed inclusive: Design runs from the 6th to the 8th
    assert has_element?(view, "#gantt-row-2 [role=gridcell]", "01/08/2025")
  end

  test "renders tree semantics", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn)

    assert has_element?(view, "#gantt-grid[role=treegrid]")
    assert has_element?(view, "#gantt-row-1[aria-level='1'][aria-expanded=true]")
    assert has_element?(view, "#gantt-row-2[aria-level='2']")
  end

  test "renders translated labels", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn, locale: "es")

    assert has_element?(view, "#gantt-add-task", "Añadir tarea")
    assert has_element?(view, ".gx-scale-row:first-child .gx-scale-cell", "enero 2025")
    assert has_element?(view, "#gantt-row-2 [role=gridcell]", "06/01/2025")
  end

  test "readonly charts cannot be edited", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn, readonly: true)

    refute has_element?(view, "#gantt-add-task")
    refute has_element?(view, ".gx-handle")
    refute has_element?(view, ".gx-link-point")
    assert has_element?(view, "#gantt-bar-2[data-gx-drag=none]")
  end

  test "shows an empty state", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn, tasks: [], links: [])

    assert has_element?(view, ".gx-empty", "No tasks yet")
  end

  test "reloads data from the parent and keeps the UI state", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn)

    view |> element("#gantt-row-1 .gx-toggle") |> render_click()
    refute has_element?(view, "#gantt-row-2")

    tasks = sample_tasks() ++ [%{id: 5, text: "Retro", start_date: ~D[2025-01-20]}]
    send(view.pid, {:assign, tasks: tasks})

    assert has_element?(view, "#gantt-row-5", "Retro")
    refute has_element?(view, "#gantt-row-2")
  end
end
