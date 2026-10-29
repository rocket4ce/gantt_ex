defmodule GanttEx.Live.PlansTest do
  use GanttEx.LiveCase, async: true

  @plan %{id: 7, week: ~D[2025-01-08], committed: [2], label: "Week 2"}

  describe "plans" do
    test "highlight their period and color the committed tasks", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn, plans: [@plan])

      assert has_element?(view, "#gantt.gx-root--plans")
      # the timeline starts on Jan 1 (48px per day): the week starts on Monday the 6th
      assert has_element?(view, "#gantt-plan-7[style*='left: 240px; width: 336px']", "Week 2")
      assert has_element?(view, ".gx-scale-band[style*='left: 240px']")

      assert has_element?(view, "#gantt-bar-2.gx-bar--committed")
      assert has_element?(view, "#gantt-bar-3.gx-bar--not-committed")
      # summary tasks and milestones out of the plan keep their colors
      refute has_element?(view, "#gantt-bar-1.gx-bar--not-committed")
      refute has_element?(view, "#gantt-bar-4.gx-bar--not-committed")
    end

    test "may last several weeks, with the tasks committed in any of them", %{conn: conn} do
      plans = [
        %{week: "2025-01-06", committed: ["3"]},
        %{id: "next", week: ~D[2025-01-13], weeks: 2, committed: [4], label: "Weeks 3-4"}
      ]

      {:ok, view, _html} = mount_gantt(conn, plans: plans)

      assert has_element?(view, "#gantt-plan-2025-01-06", "Planned period")
      # two weeks, cut at the end of the timeline (Jan 20)
      assert has_element?(view, "#gantt-plan-next[style*='left: 576px']", "Weeks 3-4")
      assert has_element?(view, "#gantt-bar-3.gx-bar--committed")
      assert has_element?(view, "#gantt-bar-2.gx-bar--not-committed")
      assert has_element?(view, "#gantt-bar-4.gx-bar--committed")
    end

    test "are off by default", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn, plans: false)

      refute has_element?(view, ".gx-plan-band")
      refute has_element?(view, ".gx-bar--committed")
      refute has_element?(view, ".gx-bar--not-committed")
    end
  end

  describe "legend" do
    test "explains the bars and marks of the chart", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn, legend: true, today_marker: true)

      for key <- ~w(task progress project milestone deadline overdue blocked restricted today) do
        assert has_element?(view, "#gantt-legend-#{key}")
      end

      assert has_element?(view, "#gantt-legend-milestone", "Milestone")
      assert has_element?(view, "#gantt-legend-project .gx-swatch--project")
      refute has_element?(view, "#gantt-legend-critical")
      refute has_element?(view, "#gantt-legend-baseline")
      refute has_element?(view, "#gantt-legend-committed")

      view |> element("#gantt-critical-path") |> render_click()
      assert has_element?(view, "#gantt-legend-critical", "Critical path")
    end

    test "has the weekly plan, the summary style and the entries of the host", %{conn: conn} do
      {:ok, view, _html} =
        mount_gantt(conn,
          legend: true,
          plans: [@plan],
          summary_bars: :bracket,
          baselines: true,
          legend_items: [
            %{label: "Concrete Ltd.", color: "#0ea5e9", group: "Partner"},
            %{label: "Rain", icon: :exclamation_triangle},
            %{label: "Bad color", color: "red; position: fixed", shape: :dot}
          ]
        )

      assert has_element?(view, "#gantt-legend-committed", "Committed")
      assert has_element?(view, "#gantt-legend-not-committed", "Not committed")
      assert has_element?(view, "#gantt-legend-plan", "Planned period")
      assert has_element?(view, "#gantt-legend-project .gx-swatch--bracket")
      assert has_element?(view, "#gantt-legend-baseline")

      assert has_element?(
               view,
               "#gantt-legend-item-0 .gx-swatch--custom[style*='--gx-swatch: #0ea5e9']",
               ""
             )

      assert has_element?(view, "#gantt-legend-item-0", "Concrete Ltd.")
      assert has_element?(view, "#gantt-legend-group-0.gx-legend-group", "Partner")
      refute has_element?(view, "#gantt-legend-group-0 .gx-swatch")
      assert has_element?(view, "#gantt-legend-item-1 .gx-legend-icon svg")
      # invalid colors are dropped
      assert has_element?(view, "#gantt-legend-item-2 .gx-swatch--dot")
      refute has_element?(view, "#gantt-legend-item-2 [style*=position]")
    end

    test "is off by default", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)
      refute has_element?(view, "#gantt-legend")
    end
  end

  describe "progress column" do
    test "colors the progress by the status of the task", %{conn: conn} do
      # today is Jan 8
      tasks = [
        %{id: 1, text: "Done", start_date: ~D[2025-01-02], duration: 2, progress: 1.0},
        %{id: 2, text: "Late", start_date: ~D[2025-01-02], duration: 2, progress: 0.4},
        %{id: 3, text: "Going", start_date: ~D[2025-01-07], duration: 3, progress: 0.5},
        %{id: 4, text: "Next", start_date: ~D[2025-01-13], duration: 2}
      ]

      {:ok, view, _html} =
        mount_gantt(conn, tasks: tasks, links: [], progress_column: true, legend: true)

      for {id, status, percent} <- [
            {1, "completed", "100%"},
            {2, "overdue", "40%"},
            {3, "in-progress", "50%"},
            {4, "not-started", "0%"}
          ] do
        assert has_element?(view, "#gantt-row-#{id} .gx-progress--#{status}", percent)
      end

      assert has_element?(view, "#gantt-legend-group-progress", "Progress")
      assert has_element?(view, "#gantt-legend-status-overdue", "Overdue")
      assert has_element?(view, "#gantt-legend-status-overdue .gx-swatch.gx-progress--overdue")
    end
  end

  describe "summary bars" do
    test "can be drawn as brackets", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn, summary_bars: :bracket)

      assert has_element?(view, "#gantt.gx-root--bracket")
      assert has_element?(view, "#gantt-bar-1.gx-bar--summary .gx-summary-cap--start")
      assert has_element?(view, "#gantt-bar-1.gx-bar--summary .gx-summary-cap--end")
      refute has_element?(view, "#gantt-bar-2.gx-bar--summary")
    end

    test "are bars by default", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)
      refute has_element?(view, "#gantt.gx-root--bracket")
    end
  end
end
