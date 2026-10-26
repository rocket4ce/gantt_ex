defmodule GanttEx.Live.SplitRollupTest do
  use GanttEx.LiveCase, async: true

  alias GanttEx.Event

  defp split_tasks do
    [
      %{id: 1, text: "Phases", type: :project, render: :split, open: false},
      %{id: 2, text: "Phase A", parent: 1, start_date: ~D[2025-01-06], duration: 2},
      %{id: 3, text: "Phase B", parent: 1, start_date: ~D[2025-01-10], duration: 2},
      %{id: 4, text: "Review", start_date: ~D[2025-01-14], duration: 1}
    ]
  end

  test "split tasks draw their children on their own row", %{conn: conn} do
    {:ok, view, _html} =
      mount_gantt(conn, tasks: split_tasks(), links: [%{id: 1, source: 3, target: 4}])

    refute has_element?(view, "#gantt-row-2")
    refute has_element?(view, "#gantt-bar-1")

    assert has_element?(
             view,
             "#gantt-bar-split-2[data-gx-bar='2'][style*='--gx-y: 6px']",
             "Phase A"
           )

    assert has_element?(view, "#gantt-bar-split-3[data-gx-bar='3']", "Phase B")
    # the link starts at the segment of Phase B while the branch is collapsed
    assert has_element?(view, "g[data-gx-link='1']")
  end

  test "segments can be dragged like their task", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn, tasks: split_tasks(), links: [])

    view
    |> element("#gantt")
    |> render_hook("gx:drag", %{"key" => "3", "mode" => "move", "x" => 528, "width" => 96})

    assert_gantt_event(%Event{
      type: :task_updated,
      task: %{id: 3, start_date: ~N[2025-01-12 00:00:00]}
    })
  end

  test "rollup tasks appear on their ancestor project rows", %{conn: conn} do
    tasks = List.update_at(sample_tasks(), 3, &Map.merge(&1, %{parent: 1, rollup: true}))
    {:ok, view, _html} = mount_gantt(conn, tasks: tasks)

    assert has_element?(view, "#gantt-rollup-1-4.gx-rollup--milestone[style*='top: 18px']")
  end
end
