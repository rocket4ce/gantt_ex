defmodule GanttEx.Live.DragTest do
  # Hook events, as pushed by GanttEx.Live.Hook. In the default day zoom the
  # timeline starts on 2025-01-01 and each day is 48px wide.
  use GanttEx.LiveCase, async: true

  alias GanttEx.Event

  defp hook(view, event, params), do: view |> element("#gantt") |> render_hook(event, params)

  describe "bars" do
    test "moving keeps the duration and snaps to days", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)

      # Design (Jan 6, 3 days) dropped around Jan 8 (7 days * 48 = 336, + a bit)
      hook(view, "gx:drag", %{"key" => "2", "mode" => "move", "x" => 340, "width" => 144})

      assert_gantt_event(%Event{type: :task_updated, task: task, changes: changes})

      assert {task.start_date, task.end_date, task.duration} ==
               {~N[2025-01-08 00:00:00], ~N[2025-01-11 00:00:00], 3}

      assert Map.keys(changes) |> Enum.sort() == [:end_date, :start_date]
    end

    test "resizing the end changes the duration", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)

      # Build starts Jan 9 (x = 384); make it end on Jan 16 (x = 720)
      hook(view, "gx:drag", %{"key" => "3", "mode" => "end", "x" => 384, "width" => 336})

      assert_gantt_event(%Event{type: :task_updated, task: %{id: 3, duration: 7}})
      # the parent project follows
      assert_gantt_event(%Event{
        type: :task_updated,
        task: %{id: 1, end_date: ~N[2025-01-16 00:00:00]}
      })
    end

    test "resizing the start keeps the end", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)

      hook(view, "gx:drag", %{"key" => "3", "mode" => "start", "x" => 336, "width" => 288})

      assert_gantt_event(%Event{type: :task_updated, task: task})

      assert {task.start_date, task.end_date, task.duration} ==
               {~N[2025-01-08 00:00:00], ~N[2025-01-14 00:00:00], 6}
    end

    test "a task keeps at least one unit when resized", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)

      hook(view, "gx:drag", %{"key" => "3", "mode" => "end", "x" => 384, "width" => 2})

      assert_gantt_event(%Event{type: :task_updated, task: %{id: 3, duration: 1}})
    end

    test "dragging the progress handle", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)

      hook(view, "gx:drag", %{"key" => "3", "mode" => "progress", "progress" => 0.734})

      assert_gantt_event(%Event{type: :task_updated, task: %{id: 3, progress: 0.73}})
    end

    test "milestones move by their center", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)

      # 24px diamond centered on Jan 18 (17 * 48 = 816)
      hook(view, "gx:drag", %{"key" => "4", "mode" => "move", "x" => 804, "width" => 24})

      assert_gantt_event(%Event{
        type: :task_updated,
        task: %{id: 4, start_date: ~N[2025-01-18 00:00:00]}
      })
    end

    test "project bars and readonly charts ignore drags", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)
      hook(view, "gx:drag", %{"key" => "1", "mode" => "move", "x" => 0, "width" => 100})
      refute_received {:gantt_event, %Event{type: :task_updated}}

      {:ok, view, _html} = mount_gantt(conn, readonly: true)
      hook(view, "gx:drag", %{"key" => "2", "mode" => "move", "x" => 0, "width" => 100})
      refute_received {:gantt_event, %Event{type: :task_updated}}
    end

    test "unknown keys and malformed payloads are ignored", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)

      hook(view, "gx:drag", %{"key" => "999", "mode" => "move", "x" => 0, "width" => 1})
      hook(view, "gx:drag", %{"key" => "2", "mode" => "move", "x" => "nope", "width" => 1})
      hook(view, "gx:drag", %{"key" => "2", "mode" => "teleport", "x" => 0, "width" => 1})

      refute_received {:gantt_event, %Event{type: :task_updated}}
    end
  end

  describe "links" do
    test "drawing from an end to a start creates a finish-to-start link", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)

      hook(view, "gx:link", %{"source" => "2", "from" => "end", "target" => "4", "to" => "start"})

      assert_gantt_event(%Event{type: :link_created, link: link})
      assert {link.source, link.target, link.type} == {2, 4, :finish_to_start}
      assert has_element?(view, ~s(g[data-gx-link="#{link.id}"]))
    end

    test "start to start", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)

      hook(view, "gx:link", %{
        "source" => "2",
        "from" => "start",
        "target" => "3",
        "to" => "start"
      })

      assert_gantt_event(%Event{type: :link_created, link: %{type: :start_to_start}})
    end

    test "circular dependencies are rejected", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)

      hook(view, "gx:link", %{"source" => "4", "from" => "end", "target" => "2", "to" => "start"})

      refute_received {:gantt_event, %Event{type: :link_created}}
      assert has_element?(view, ".gx-notice", "This dependency is not allowed")
    end
  end

  describe "rows" do
    test "reordering before a sibling", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)

      hook(view, "gx:reorder", %{"key" => "3", "target" => "2", "position" => "before"})

      assert_gantt_event(%Event{
        type: :task_moved,
        task: %{id: 3},
        parent: 1,
        index: 0,
        siblings: [3, 2]
      })
    end

    test "dropping inside another task re-parents it", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)

      hook(view, "gx:reorder", %{"key" => "4", "target" => "1", "position" => "inside"})

      assert_gantt_event(%Event{
        type: :task_moved,
        task: %{id: 4, parent: 1},
        siblings: [2, 3, 4]
      })

      assert has_element?(view, "#gantt-row-4[aria-level='2']")
    end

    test "a task cannot be moved inside its own subtree", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)

      hook(view, "gx:reorder", %{"key" => "1", "target" => "2", "position" => "inside"})

      refute_received {:gantt_event, %Event{type: :task_moved}}
    end
  end

  describe "timeline" do
    test "dragging on the timeline opens the lightbox for a new task", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn, drag_create: true)

      # Jan 20 (19 * 48 = 912) to Jan 23 (22 * 48 = 1056)
      hook(view, "gx:create", %{"x" => 912, "width" => 144, "row" => 4})

      assert has_element?(
               view,
               "#gantt-lightbox input[name='task[start_date]'][value='2025-01-20']"
             )

      assert has_element?(view, "#gantt-lightbox input[name='task[duration]'][value='3']")
    end

    test "without lightbox the task is created right away", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn, drag_create: true, lightbox: false)

      hook(view, "gx:create", %{"x" => 912, "width" => 144})

      assert_gantt_event(%Event{type: :task_created, task: %{duration: 3, text: "New task"}})
    end
  end

  test "resizing grid columns", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn)

    hook(view, "gx:resize", %{"column" => "start_date", "width" => 150})
    assert render(view) =~ "--gx-col-1: 150px"

    hook(view, "gx:resize", %{"column" => "__grid", "width" => 500})
    assert render(view) =~ "--gx-grid-width: 500px"
  end

  test "the tree column is resized too, from its width on the screen", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn)

    # it has its own width (220px by default), and takes the free width
    assert render(view) =~ "--gx-col-0: 220px"
    assert has_element?(view, "#gantt-head-text[style*='flex: 1 0 var(--gx-col-0)']")
    assert has_element?(view, "#gantt-head-text .gx-col-resizer[data-gx-min-width='120']")

    hook(view, "gx:resize", %{"column" => "__grid", "width" => 900})

    # shown 400px wide in a grid of 900px, widened by 50px: the grid grows with it
    hook(view, "gx:resize", %{"column" => "text", "width" => 450, "delta" => 50})
    assert render(view) =~ "--gx-col-0: 450px"
    assert render(view) =~ "--gx-grid-width: 950px"

    # never narrower than 120px
    hook(view, "gx:resize", %{"column" => "text", "width" => 40, "delta" => -410})
    assert render(view) =~ "--gx-col-0: 120px"
  end
end
