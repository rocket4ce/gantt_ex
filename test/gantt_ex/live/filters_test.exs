defmodule GanttEx.Live.FiltersTest do
  use GanttEx.LiveCase, async: true

  alias GanttEx.Event

  @owner %{
    id: :owner,
    label: "Owner",
    options: [
      {"Unassigned", nil},
      %{label: "Ana", value: "Ana", hint: "Design"},
      {"Luis", "Luis"}
    ]
  }

  defp shown_rows(view) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(".gx-row")
    |> Enum.map(&(&1 |> LazyHTML.attribute("data-gx-row") |> hd()))
  end

  defp search(view, text),
    do: view |> element("#gantt-search") |> render_change(%{"search" => text})

  defp open_filters(view), do: view |> element("#gantt-filters-toggle") |> render_click()

  defp change_filters(view, params) do
    view |> element("#gantt-filters-form") |> render_change(params)
  end

  describe "search" do
    test "matches the text of the tasks and shows their ancestors", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)
      assert has_element?(view, "#gantt-search-input[type=search][aria-label='Search tasks']")

      search(view, "desi")

      assert shown_rows(view) == ["1", "2"]
      assert has_element?(view, "#gantt-filter-bar", "1 of 4 tasks")
      assert has_element?(view, "#gantt-search-input[value=desi]")
      assert_gantt_event(%Event{type: :filters_changed, filters: %{search: "desi"}})
    end

    test "ignores case and accents", %{conn: conn} do
      tasks = [
        %{id: 1, text: "Losa de hormigón", start_date: ~D[2025-01-06]},
        %{id: 2, text: "Pintura", start_date: ~D[2025-01-06]}
      ]

      {:ok, view, _html} = mount_gantt(conn, tasks: tasks, links: [])

      search(view, "HORMIGON")
      assert shown_rows(view) == ["1"]
    end

    test "matches WBS codes and the tasks below them", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)

      search(view, "1.2")
      assert shown_rows(view) == ["1", "3"]

      search(view, "1")
      assert shown_rows(view) == ["1", "2", "3"]
    end

    test "can be cleared", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)

      search(view, "build")
      view |> element("#gantt-search-clear") |> render_click()

      assert shown_rows(view) == ["1", "2", "3", "4"]
      refute has_element?(view, "#gantt-filter-bar")
      assert_gantt_event(%Event{type: :filters_changed, filters: %{search: "build"}})
      assert_gantt_event(%Event{type: :filters_changed, filters: filters})
      assert filters == %{}
    end

    test "shows an empty state when nothing matches", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)

      search(view, "zzz")
      assert has_element?(view, ".gx-empty", "No matching tasks")

      view |> element("#gantt-empty-clear-filters") |> render_click()
      assert shown_rows(view) == ["1", "2", "3", "4"]
    end
  end

  describe "panel" do
    test "opens, closes and reports its state", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)
      refute has_element?(view, "#gantt-filters")

      open_filters(view)
      assert has_element?(view, "#gantt-filters-toggle[aria-expanded=true]")
      assert has_element?(view, "#gantt-filters[role=dialog]")
      assert has_element?(view, "#gantt-filter-status input[type=checkbox][value=blocked]")
      assert has_element?(view, "#gantt-filter-type input[type=checkbox][value=milestone]")
      assert has_element?(view, "#gantt-filter-dates input[type=date]")

      view |> element("#gantt-filters") |> render_keydown(%{"key" => "Escape"})
      refute has_element?(view, "#gantt-filters")

      open_filters(view)
      open_filters(view)
      refute has_element?(view, "#gantt-filters")
    end

    test "filters by status", %{conn: conn} do
      tasks =
        sample_tasks()
        |> List.update_at(1, &Map.put(&1, :deadline, ~D[2025-01-07]))
        |> List.update_at(2, &Map.merge(&1, %{blocked: true, restrictions: 2}))

      {:ok, view, _html} = mount_gantt(conn, tasks: tasks)
      open_filters(view)

      change_filters(view, %{"filters" => %{"status" => ["", "in_progress"]}})
      assert shown_rows(view) == ["1", "2"]
      assert has_element?(view, "#gantt-filters-toggle .gx-badge", "1")
      assert_gantt_event(%Event{type: :filters_changed, filters: %{status: [:in_progress]}})

      # today is the 8th: Design is unfinished and its deadline was the 7th
      change_filters(view, %{"filters" => %{"status" => ["overdue"]}})
      assert shown_rows(view) == ["1", "2"]

      change_filters(view, %{"filters" => %{"status" => ["blocked"]}})
      assert shown_rows(view) == ["1", "3"]

      change_filters(view, %{"filters" => %{"status" => ["restricted", "completed"]}})
      assert shown_rows(view) == ["1", "3"]

      change_filters(view, %{"filters" => %{"status" => ["not_started"]}})
      assert shown_rows(view) == ["1", "3", "4"]
    end

    test "offers the critical status while the critical path is shown", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)
      open_filters(view)
      refute has_element?(view, "#gantt-filter-status input[value=critical]")

      view |> element("#gantt-critical-path") |> render_click()
      assert has_element?(view, "#gantt-filter-status input[value=critical]")

      change_filters(view, %{"filters" => %{"status" => ["critical"]}})
      assert "4" in shown_rows(view)
    end

    test "filters by type", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)
      open_filters(view)

      change_filters(view, %{"filters" => %{"type" => ["milestone"]}})
      assert shown_rows(view) == ["4"]
      assert_gantt_event(%Event{type: :filters_changed, filters: %{type: [:milestone]}})
    end

    test "filters by dates", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)
      open_filters(view)

      change_filters(view, %{"filters" => %{"dates" => %{"from" => "2025-01-15", "to" => ""}}})
      assert shown_rows(view) == ["4"]
      assert_gantt_event(%Event{filters: %{dates: %{from: ~D[2025-01-15], to: nil}}})

      # the last day is included
      change_filters(view, %{"filters" => %{"dates" => %{"from" => "", "to" => "2025-01-06"}}})
      assert shown_rows(view) == ["1", "2"]

      change_filters(view, %{
        "filters" => %{"dates" => %{"from" => "2025-01-10", "to" => "2025-01-01"}}
      })

      assert has_element?(view, "#gantt-filter-dates .gx-error")
      assert has_element?(view, "#gantt-filter-dates-to[aria-invalid=true]")
      assert shown_rows(view) == []
    end

    test "filters combine with AND, values of a filter with OR", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)
      open_filters(view)

      change_filters(view, %{"filters" => %{"type" => ["task", "milestone"]}})
      assert shown_rows(view) == ["1", "2", "3", "4"]

      search(view, "launch")
      assert shown_rows(view) == ["4"]
      assert has_element?(view, "#gantt-filter-bar", "1 of 4 tasks")
    end

    test "clears one filter or all of them", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)
      open_filters(view)
      search(view, "a")

      change_filters(view, %{
        "filters" => %{"type" => ["milestone"], "status" => ["not_started"]}
      })

      assert has_element?(view, "#gantt-filter-type-active", "Type: Milestone")

      view |> element("#gantt-filter-type-clear") |> render_click()
      refute has_element?(view, "#gantt-filter-type-active")
      assert has_element?(view, "#gantt-filter-status-active")

      view |> element("#gantt-filter-status-active button") |> render_click()
      refute has_element?(view, "#gantt-filter-status-active")

      view |> element("#gantt-clear-filters") |> render_click()
      refute has_element?(view, "#gantt-filter-bar")
      refute has_element?(view, "#gantt-search-input[value]")
    end

    test "rows cannot be reordered while filtering", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)
      assert has_element?(view, "#gantt[data-gx-reorder=true]")

      search(view, "a")
      assert has_element?(view, "#gantt[data-gx-reorder=false]")

      view
      |> element("#gantt")
      |> render_hook("gx:reorder", %{"key" => "4", "target" => "1", "position" => "inside"})

      refute_received {:gantt_event, %Event{type: :task_moved}}
    end

    test "keep working on readonly charts", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn, readonly: true)

      search(view, "build")
      assert shown_rows(view) == ["1", "3"]
    end

    test "can be disabled", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn, filters: false)

      refute has_element?(view, "#gantt-search")
      refute has_element?(view, "#gantt-filters-toggle")

      {:ok, view, _html} = mount_gantt(conn, filters: [:search])
      assert has_element?(view, "#gantt-search")
      refute has_element?(view, "#gantt-filters-toggle")
    end
  end

  describe "custom filters" do
    test "match a meta field, with an option for no value", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn, filters: [@owner])
      open_filters(view)

      assert has_element?(view, "#gantt-filter-owner-option-Ana", "Design")
      refute has_element?(view, "#gantt-filter-owner input[type=search]")

      change_filters(view, %{"filters" => %{"owner" => ["", "Ana"]}})
      assert shown_rows(view) == ["1", "2"]
      assert_gantt_event(%Event{type: :filters_changed, filters: %{owner: ["Ana"]}})

      change_filters(view, %{"filters" => %{"owner" => ["__none__", "Luis"]}})
      assert shown_rows(view) == ["1", "3", "4"]
      assert_gantt_event(%Event{type: :filters_changed, filters: %{owner: [nil, "Luis"]}})
    end

    test "show the selected options as removable chips", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn, filters: [@owner])
      open_filters(view)
      change_filters(view, %{"filters" => %{"owner" => ["Ana", "Luis"]}})

      assert has_element?(view, "#gantt-filter-owner-chip-Ana", "Ana")
      assert has_element?(view, "#gantt-filter-owner-chip-Luis", "Luis")
      assert has_element?(view, "#gantt-filter-owner-active", "Owner: Ana, Luis")

      view
      |> element("#gantt-filter-owner-chip-Ana button[aria-label='Remove Ana']")
      |> render_click()

      refute has_element?(view, "#gantt-filter-owner-chip-Ana")
      assert shown_rows(view) == ["1", "3"]
      assert_gantt_event(%Event{filters: %{owner: ["Ana", "Luis"]}})
      assert_gantt_event(%Event{filters: %{owner: ["Luis"]}})
    end

    test "searchable options are filtered as you type", %{conn: conn} do
      owner = Map.merge(@owner, %{searchable: true, placeholder: "Find people"})
      {:ok, view, _html} = mount_gantt(conn, filters: [owner])
      open_filters(view)
      change_filters(view, %{"filters" => %{"owner" => ["Ana"]}})

      assert has_element?(view, "#gantt-filter-owner-query[placeholder='Find people']")

      # the hint is searched too, ignoring accents
      change_filters(view, %{
        "queries" => %{"owner" => "DESÍ"},
        "filters" => %{"owner" => ["Ana"]}
      })

      assert has_element?(view, "#gantt-filter-owner-option-Ana")
      refute has_element?(view, "#gantt-filter-owner-option-Luis")

      change_filters(view, %{"queries" => %{"owner" => "lu"}, "filters" => %{"owner" => ["Ana"]}})
      refute has_element?(view, "#gantt-filter-owner-option-Ana")
      assert has_element?(view, "#gantt-filter-owner-option-Luis")
      # the selected option filtered out of the list keeps being submitted
      assert has_element?(view, "#gantt-filter-owner input[type=hidden][value=Ana]")
      assert has_element?(view, "#gantt-filter-owner-chip-Ana")
      assert has_element?(view, "#gantt-filter-owner-query[value=lu]")

      change_filters(view, %{"queries" => %{"owner" => "zz"}, "filters" => %{"owner" => ["Ana"]}})
      assert has_element?(view, "#gantt-filter-owner .gx-options-empty", "No options found")

      # typing is not a change of the filters
      refute_receive {:gantt_event, %Event{filters: %{owner: ["Ana", _]}}}, 50
    end

    test "with more than 8 options are searchable by default", %{conn: conn} do
      options = for i <- 1..9, do: {"Person #{i}", i}
      {:ok, view, _html} = mount_gantt(conn, filters: [%{id: :person, options: options}])
      open_filters(view)

      assert has_element?(view, "#gantt-filter-person-query")
    end

    test "single choice filters keep the last option", %{conn: conn} do
      owner = Map.put(@owner, :multiple, false)
      {:ok, view, _html} = mount_gantt(conn, filters: [owner])
      open_filters(view)

      assert has_element?(view, "#gantt-filter-owner input[type=radio][value=Ana]")
      change_filters(view, %{"filters" => %{"owner" => ["Ana", "Luis"]}})
      assert_gantt_event(%Event{filters: %{owner: ["Luis"]}})
    end
  end

  describe "filter_values" do
    test "restore the filters without reporting them", %{conn: conn} do
      {:ok, view, _html} =
        mount_gantt(conn, filters: [:search, :type, @owner], filter_values: %{owner: ["Luis"]})

      assert shown_rows(view) == ["1", "3"]
      assert has_element?(view, "#gantt-filters-toggle .gx-badge", "1")
      refute_received {:gantt_event, %Event{type: :filters_changed}}
    end

    test "the same values do not reset the user's filters, new ones replace them", %{conn: conn} do
      opts = %{filters: [:search, :type], filter_values: %{search: "design"}}
      {:ok, view, _html} = mount_gantt(conn, Map.to_list(opts))
      assert shown_rows(view) == ["1", "2"]

      search(view, "build")

      send(
        view.pid,
        {:assign,
         opts: opts,
         tasks: sample_tasks() ++ [%{id: 5, text: "Build QA", start_date: ~D[2025-01-20]}]}
      )

      assert shown_rows(view) == ["1", "3", "5"]

      send(view.pid, {:assign, opts: %{opts | filter_values: %{"type" => ["milestone"]}}})
      assert shown_rows(view) == ["4"]
      refute has_element?(view, "#gantt-search-input[value]")
    end
  end
end
