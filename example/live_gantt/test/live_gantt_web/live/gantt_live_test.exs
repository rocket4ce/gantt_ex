defmodule LiveGanttWeb.GanttLiveTest do
  use LiveGanttWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import LiveGantt.PlanningFixtures

  alias LiveGantt.Planning.Task
  alias LiveGantt.Repo

  setup do
    project_fixture()
  end

  defp dom_id(task), do: "#project-gantt-row-#{task.id}"

  # The chart notifies the LiveView with a message; wait until it was handled.
  defp sync(view), do: _ = :sys.get_state(view.pid)

  test "renders the chart with the persisted tasks", %{conn: conn, design: design, build: build} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#project-gantt[phx-hook]")
    assert has_element?(view, dom_id(design), "Design")
    assert has_element?(view, dom_id(build), "Build")
    assert has_element?(view, "#{dom_id(design)} [role=gridcell]", "Ana")
    assert has_element?(view, "#stat-tasks", "2")
  end

  test "dragging a bar persists the new dates", %{conn: conn, build: build} do
    {:ok, view, _html} = live(conn, ~p"/")

    # In the day zoom the timeline starts on 2025-01-01 with 48px days: x = 576 is Jan 13
    view
    |> element("#project-gantt")
    |> render_hook("gx:drag", %{"key" => build.id, "mode" => "move", "x" => 576, "width" => 192})

    sync(view)

    assert %Task{start_date: ~N[2025-01-13 00:00:00], duration: 4} = Repo.reload!(build)
    assert has_element?(view, "#activity li", "Build")
  end

  test "creating a task from the lightbox persists it", %{conn: conn, project: project} do
    {:ok, view, _html} = live(conn, ~p"/")

    view |> element("#project-gantt-add-task") |> render_click()

    view
    |> element("#project-gantt-lightbox-form")
    |> render_submit(%{
      "task" => %{
        "text" => "Launch party",
        "type" => "milestone",
        "parent" => project.id,
        "start_date" => "2025-01-20",
        "owner" => "Sofía"
      }
    })

    sync(view)

    assert %Task{type: :milestone, duration: 0, owner: "Sofía"} =
             Repo.get_by!(Task, text: "Launch party")

    assert has_element?(view, ".gx-row", "Launch party")
  end

  test "advanced features can be switched on", %{conn: conn, design: design} do
    {:ok, view, _html} = live(conn, ~p"/")

    view |> element("#settings-form") |> render_change(%{"settings" => %{"group" => "true"}})
    assert has_element?(view, "[data-gx-row='g:Ana']", "Ana")

    view |> element("#settings-form") |> render_change(%{"settings" => %{"workload" => "true"}})
    assert has_element?(view, "#project-gantt-resource-Ana")

    view |> element("#settings-form") |> render_change(%{"settings" => %{"baselines" => "false"}})
    refute has_element?(view, ".gx-baseline")
    assert has_element?(view, "[data-gx-row='#{design.id}']")
  end

  test "baselines and deadlines are persisted", %{conn: conn, build: build} do
    {:ok, view, _html} = live(conn, ~p"/")

    view |> element("#project-gantt") |> render_hook("gx:dblclick", %{"key" => build.id})

    view
    |> element("#project-gantt-lightbox-form")
    |> render_submit(%{"task" => %{"text" => "Build", "deadline" => "2025-01-10"}})

    sync(view)
    assert %Task{deadline: ~N[2025-01-10 00:00:00]} = Repo.reload!(build)
    assert has_element?(view, "[data-gx-bar='#{build.id}'].gx-bar--overdue")
  end

  test "settings change the language, filter and readonly mode", %{conn: conn, design: design} do
    {:ok, view, _html} = live(conn, ~p"/")

    view |> element("#settings-form") |> render_change(%{"settings" => %{"locale" => "de"}})
    assert has_element?(view, "#project-gantt-add-task", "Aufgabe hinzufügen")
    assert has_element?(view, "[role=columnheader]", "Verantwortlich")

    view
    |> element("#settings-form")
    |> render_change(%{"settings" => %{"locale" => "en", "query" => "build"}})

    refute has_element?(view, dom_id(design))

    view |> element("#settings-form") |> render_change(%{"settings" => %{"readonly" => "true"}})
    refute has_element?(view, "#project-gantt-add-task")
  end
end
