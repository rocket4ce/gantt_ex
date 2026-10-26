defmodule GanttEx.Live.SmartRenderingTest do
  use GanttEx.LiveCase, async: true

  defp many_tasks(count) do
    for id <- 1..count do
      %{
        id: id,
        text: "Task #{id}",
        start_date: Date.add(~D[2025-01-06], rem(id, 20)),
        duration: 2
      }
    end
  end

  defp rendered_rows(view) do
    view |> render() |> LazyHTML.from_fragment() |> LazyHTML.query(".gx-row") |> Enum.count()
  end

  test "large charts only render the rows around the viewport", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn, tasks: many_tasks(500), links: [])

    assert has_element?(view, "#gantt[data-gx-window='0:50:500']")
    assert has_element?(view, "#gantt-row-1")
    refute has_element?(view, "#gantt-row-200")
    assert rendered_rows(view) == 51
    # the spacer keeps the scroll height of the missing rows
    assert has_element?(view, ".gx-spacer[style='height: #{449 * 36}px']")
  end

  test "scrolling renders a new window", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn, tasks: many_tasks(500), links: [])

    view |> element("#gantt") |> render_hook("gx:viewport", %{"top" => 7200, "height" => 720})

    # rows 200..220 are visible; 25 rows of buffer on each side
    assert has_element?(view, "#gantt[data-gx-window='175:245:500']")
    assert has_element?(view, "#gantt-row-200")
    assert has_element?(view, "#gantt-bar-200")
    refute has_element?(view, "#gantt-row-1")
    refute has_element?(view, "#gantt-bar-1")
  end

  test "links crossing the window are rendered", %{conn: conn} do
    links = [%{id: 1, source: 1, target: 300}, %{id: 2, source: 2, target: 3}]
    {:ok, view, _html} = mount_gantt(conn, tasks: many_tasks(500), links: links)

    view |> element("#gantt") |> render_hook("gx:viewport", %{"top" => 7200, "height" => 720})

    assert has_element?(view, "g[data-gx-link='1']")
    refute has_element?(view, "g[data-gx-link='2']")
  end

  test "small charts and disabled smart rendering render everything", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn)
    refute has_element?(view, "#gantt[data-gx-window]")

    {:ok, view, _html} =
      mount_gantt(conn, tasks: many_tasks(200), links: [], smart_rendering: false)

    assert rendered_rows(view) == 200
  end

  test "keyboard navigation moves the selection across windows", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn, tasks: many_tasks(500), links: [])

    view |> element("#gantt-viewport") |> render_keydown(%{"key" => "End"})
    assert_push_event(view, "gantt_ex:scroll", %{y: 17964})
  end

  test "invalid viewports are ignored", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn, tasks: many_tasks(500), links: [])

    view |> element("#gantt") |> render_hook("gx:viewport", %{"top" => "x", "height" => -1})
    assert has_element?(view, "#gantt[data-gx-window='0:50:500']")
  end
end
