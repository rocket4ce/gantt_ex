defmodule GanttEx.Live.StatusIndicatorsTest do
  use GanttEx.LiveCase, async: true

  defp tasks do
    sample_tasks()
    |> List.update_at(1, &Map.put(&1, :blocked, true))
    |> List.update_at(2, &Map.put(&1, :restrictions, 3))
  end

  test "blocked tasks show a lock and a hatched bar", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn, tasks: tasks())

    assert has_element?(
             view,
             "#gantt-row-2.gx-row--blocked .gx-cell--tree .gx-flag--blocked[title=Blocked][aria-label=Blocked]"
           )

    assert has_element?(view, "#gantt-bar-2.gx-bar--blocked")
    refute has_element?(view, "#gantt-row-3 .gx-flag--blocked")
    refute has_element?(view, "#gantt-bar-3.gx-bar--blocked")
  end

  test "tasks with open restrictions show how many", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn, tasks: tasks())

    assert has_element?(
             view,
             "#gantt-row-3.gx-row--restricted .gx-flag--restricted[title='3 open restrictions']",
             "3"
           )

    assert has_element?(view, "#gantt-bar-3.gx-bar--restricted")
    refute has_element?(view, "#gantt-row-2 .gx-flag--restricted")
  end

  test "tooltips, the quick info and bar labels mention them", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn, tasks: tasks())

    assert has_element?(view, "#gantt-bar-2 .gx-tooltip .gx-tag--blocked", "Blocked")
    assert has_element?(view, "#gantt-bar-2[aria-label$=', Blocked']")
    assert has_element?(view, "#gantt-bar-3[aria-label$=', 3 open restrictions']")

    view |> element("#gantt-bar-3") |> render_click()
    assert has_element?(view, "#gantt-quick-info .gx-tag--restricted", "3 open restrictions")
    refute has_element?(view, "#gantt-quick-info .gx-tag--blocked")
  end

  test "are translated", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn, tasks: tasks(), locale: "es")

    assert has_element?(view, "#gantt-row-2 .gx-flag--blocked[title=Bloqueada]")

    assert has_element?(
             view,
             "#gantt-row-3 .gx-flag--restricted[title='3 restricciones abiertas']"
           )
  end

  test "follow the data of the parent", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn, tasks: tasks())

    send(view.pid, {:assign, tasks: sample_tasks()})

    refute has_element?(view, ".gx-flag")
    refute has_element?(view, ".gx-bar--blocked")
  end
end
