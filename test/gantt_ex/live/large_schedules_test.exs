defmodule GanttEx.Live.LargeSchedulesTest do
  # What keeps charts of thousands of tasks responsive: one event per user
  # action, and new data applied to the store without building it again.
  # In the default day zoom the timeline starts on 2025-01-01 and each day is
  # 48px wide.
  use GanttEx.LiveCase, async: true

  alias GanttEx.Event

  defp hook(view, event, params), do: view |> element("#gantt") |> render_hook(event, params)

  defp bar_style(view, key) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("#gantt-bar-#{key}")
    |> LazyHTML.attribute("style")
    |> hd()
  end

  describe "batch_events" do
    test "a move with auto-scheduling is reported as one batch", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn, auto_scheduling: true, batch_events: true)

      # Design moves to Jan 8, so Build must start on Jan 11
      hook(view, "gx:drag", %{"key" => "2", "mode" => "move", "x" => 336, "width" => 144})

      assert_gantt_event(%Event{type: :batch, gantt_id: "gantt", events: events})

      assert [
               %Event{type: :task_updated, task: %{id: 2, start_date: ~N[2025-01-08 00:00:00]}}
               | _
             ] = events

      assert Enum.any?(
               events,
               &match?(%Event{task: %{id: 3, start_date: ~N[2025-01-11 00:00:00]}}, &1)
             )

      refute_received {:gantt_event, %Event{type: :task_updated}}
    end

    test "other events are still sent one by one", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn, batch_events: true)

      hook(view, "gx:select", %{"key" => "4", "mode" => "toggle"})

      assert_gantt_event(%Event{type: :task_selected, task: %{id: 4}})
      refute_received {:gantt_event, %Event{type: :batch}}
    end
  end

  describe "new data" do
    test "changed tasks are applied to the chart", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)
      assert bar_style(view, "3") =~ "--gx-x: 384px"

      tasks =
        Enum.map(sample_tasks(), fn
          %{id: 3} = task -> %{task | start_date: ~D[2025-01-13], duration: 2}
          task -> task
        end)

      send(view.pid, {:assign, tasks: tasks})

      # Build starts on Jan 13 (12 days * 48) and the project (from Jan 6)
      # ends with it on Jan 15
      assert bar_style(view, "3") =~ "--gx-x: 576px"
      assert bar_style(view, "1") =~ "--gx-w: 432px"
    end

    test "the chart keeps its state when tasks change", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)

      view |> element("#gantt-row-1 .gx-toggle") |> render_click()
      refute has_element?(view, "#gantt-bar-2")

      tasks = Enum.map(sample_tasks(), &if(&1.id == 4, do: %{&1 | text: "Go live"}, else: &1))
      send(view.pid, {:assign, tasks: tasks})

      assert render(view) =~ "Go live"
      refute has_element?(view, "#gantt-bar-2")
    end

    test "new tasks and new parents build the chart again", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)

      tasks =
        Enum.map(sample_tasks(), &if(&1.id == 4, do: Map.put(&1, :parent, 1), else: &1)) ++
          [%{id: 5, text: "Retro", start_date: ~D[2025-01-20], duration: 1}]

      send(view.pid, {:assign, tasks: tasks})

      assert has_element?(view, "#gantt-bar-5")
      # the launch (Jan 16) moved into the project, which now ends with it
      assert bar_style(view, "1") =~ "--gx-w: 480px"
    end
  end
end
