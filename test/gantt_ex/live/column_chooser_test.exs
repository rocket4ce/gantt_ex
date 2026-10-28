defmodule GanttEx.Live.ColumnChooserTest do
  use GanttEx.LiveCase, async: true

  alias GanttEx.Event

  @default_order ["wbs", "text", "start_date", "end_date", "owner", "cost", "add"]

  defp tasks, do: Enum.map(sample_tasks(), &Map.put(&1, :cost, "$#{&1.id}00"))

  defp mount_columns(conn, opts \\ []) do
    mount_gantt(conn, Keyword.merge([extra_columns: true, tasks: tasks()], opts))
  end

  defp headers(view) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("[role=columnheader]")
    |> Enum.map(&(&1 |> LazyHTML.attribute("data-gx-column") |> hd()))
  end

  defp open_chooser(view), do: view |> element("#gantt-columns-toggle") |> render_click()

  defp show(view, keys) do
    view |> element("#gantt-columns-form") |> render_change(%{"visible" => ["" | keys]})
  end

  test "hidden columns are available but not shown", %{conn: conn} do
    {:ok, view, _html} = mount_columns(conn)

    assert headers(view) == ["text", "start_date", "end_date", "owner", "add"]
    refute has_element?(view, ".cost")

    open_chooser(view)
    assert has_element?(view, "#gantt-columns[role=dialog]")
    assert has_element?(view, "#gantt-columns-toggle[aria-expanded=true]")
    assert has_element?(view, "#gantt-column-cost.gx-column-item--hidden", "Cost")
    refute has_element?(view, "#gantt-column-cost input[checked]")
    assert has_element?(view, "#gantt-column-owner input[type=checkbox][checked]")
    # the tree cannot be hidden
    assert has_element?(view, "#gantt-column-text input[checked][disabled]")
    assert has_element?(view, "#gantt-column-add", "Add task")
  end

  test "columns are shown and hidden from the chooser", %{conn: conn} do
    {:ok, view, _html} = mount_columns(conn)
    open_chooser(view)

    show(view, ["text", "start_date", "end_date", "owner", "cost", "add"])

    assert headers(view) == ["text", "start_date", "end_date", "owner", "cost", "add"]
    # the content of host columns comes from their slot
    assert has_element?(view, "#gantt-row-3 .cost", "$300")

    assert_gantt_event(%Event{
      type: :columns_changed,
      gantt_id: "gantt",
      columns: %{order: @default_order, hidden: ["wbs"], widths: %{}, grid_width: nil}
    })

    show(view, ["start_date", "cost", "add"])
    assert headers(view) == ["text", "start_date", "cost", "add"]
    assert_gantt_event(%Event{columns: %{hidden: ["wbs", "end_date", "owner"]}})
  end

  test "columns are moved with the chooser buttons", %{conn: conn} do
    {:ok, view, _html} = mount_columns(conn)
    open_chooser(view)

    assert has_element?(view, "#gantt-column-wbs button[data-gx-move=up][disabled]")
    assert has_element?(view, "#gantt-column-add button[data-gx-move=down][disabled]")

    view |> element("#gantt-column-owner button[data-gx-move=up]") |> render_click()
    assert headers(view) == ["text", "start_date", "owner", "end_date", "add"]
    assert_gantt_event(%Event{columns: %{order: ["wbs", "text", "start_date", "owner" | _]}})
    # the focus stays on the moved column
    assert_push_event(view, "gantt_ex:focus", %{
      selector: "[data-gx-column-item='owner'] [data-gx-move='up']"
    })

    view |> element("#gantt-column-wbs button[data-gx-move=down]") |> render_click()
    assert_gantt_event(%Event{columns: %{order: ["text", "wbs" | _]}})
  end

  test "columns are moved by dragging their header", %{conn: conn} do
    {:ok, view, _html} = mount_columns(conn)

    assert has_element?(view, "#gantt-head-owner[data-gx-column=owner]")

    view
    |> element("#gantt")
    |> render_hook("gx:column_move", %{
      "field" => "owner",
      "target" => "text",
      "position" => "before"
    })

    assert headers(view) == ["owner", "text", "start_date", "end_date", "add"]
    assert has_element?(view, "#gantt-row-2 [role=gridcell]:first-child .owner", "Ana")

    assert_gantt_event(%Event{
      type: :columns_changed,
      columns: %{order: ["wbs", "owner", "text", "start_date", "end_date", "cost", "add"]}
    })

    view
    |> element("#gantt")
    |> render_hook("gx:column_move", %{
      "field" => "text",
      "target" => "add",
      "position" => "after"
    })

    assert headers(view) == ["owner", "start_date", "end_date", "add", "text"]

    # unknown columns are ignored
    view
    |> element("#gantt")
    |> render_hook("gx:column_move", %{
      "field" => "nope",
      "target" => "add",
      "position" => "after"
    })

    assert headers(view) == ["owner", "start_date", "end_date", "add", "text"]
  end

  test "resizing a column is reported", %{conn: conn} do
    {:ok, view, _html} = mount_columns(conn)

    view |> element("#gantt") |> render_hook("gx:resize", %{"column" => "owner", "width" => 180})

    assert render(view) =~ "--gx-col-3: 180px"
    assert_gantt_event(%Event{columns: %{widths: %{"owner" => 180}, grid_width: nil}})

    view
    |> element("#gantt")
    |> render_hook("gx:resize", %{"column" => "__grid", "width" => 640.4})

    assert_gantt_event(%Event{columns: %{widths: %{"owner" => 180}, grid_width: 640}})
    assert render(view) =~ "--gx-grid-width: 640px"
  end

  test "reset restores the columns of the slots", %{conn: conn} do
    {:ok, view, _html} = mount_columns(conn)
    open_chooser(view)
    show(view, ["text", "wbs", "add"])
    view |> element("#gantt") |> render_hook("gx:resize", %{"column" => "wbs", "width" => 99})

    view |> element("#gantt-columns-reset") |> render_click()

    assert headers(view) == ["text", "start_date", "end_date", "owner", "add"]

    assert_gantt_event(%Event{
      columns: %{order: @default_order, hidden: ["wbs", "cost"], widths: %{}, grid_width: nil}
    })

    # nothing to reset, nothing to report
    view |> element("#gantt-columns-reset") |> render_click()

    refute_receive {:gantt_event,
                    %Event{type: :columns_changed, columns: %{hidden: ["wbs", "cost"]}}},
                   50
  end

  test "showing a column widens a grid whose width was set", %{conn: conn} do
    {:ok, view, _html} = mount_columns(conn, grid_width: 500)
    open_chooser(view)

    show(view, ["text", "start_date", "end_date", "owner", "cost", "add"])
    assert render(view) =~ "--gx-grid-width: 604px"
    assert_gantt_event(%Event{columns: %{grid_width: 604}})
  end

  test "hiding the sorted column clears the sorting", %{conn: conn} do
    {:ok, view, _html} = mount_columns(conn)

    view |> element("#gantt-head-end_date button.gx-sort") |> render_click()
    assert has_element?(view, "#gantt[data-gx-reorder=false]")

    open_chooser(view)
    show(view, ["text", "start_date", "owner", "add"])
    assert has_element?(view, "#gantt[data-gx-reorder=true]")
  end

  describe "column_layout" do
    test "restores the layout without reporting it", %{conn: conn} do
      layout = %{
        order: ["cost", "gone", "text", "owner"],
        hidden: ["owner"],
        widths: %{"cost" => 130}
      }

      {:ok, view, _html} = mount_columns(conn, column_layout: layout)

      # columns missing from the layout come after, as in the slots
      assert headers(view) == ["cost", "text", "start_date", "end_date", "add"]
      assert render(view) =~ "--gx-col-0: 130px"
      refute_received {:gantt_event, %Event{type: :columns_changed}}
    end

    test "the same layout keeps the user's changes, a new one replaces them", %{conn: conn} do
      layout = %{"hidden" => ["owner"]}
      {:ok, view, _html} = mount_columns(conn, column_layout: layout)
      assert headers(view) == ["text", "start_date", "end_date", "add"]

      view
      |> element("#gantt")
      |> render_hook("gx:column_move", %{
        "field" => "add",
        "target" => "text",
        "position" => "before"
      })

      send(
        view.pid,
        {:assign,
         opts: %{column_layout: layout},
         tasks: tasks() ++ [%{id: 9, text: "New", start_date: ~D[2025-01-20]}]}
      )

      assert headers(view) == ["add", "text", "start_date", "end_date"]

      send(view.pid, {:assign, opts: %{column_layout: %{order: ["owner", "text"], hidden: []}}})
      # wbs and cost are not in the new layout: hidden, as in their slots
      assert headers(view) == ["owner", "text", "start_date", "end_date", "add"]
    end
  end

  test "the chooser closes with Escape and can be disabled", %{conn: conn} do
    {:ok, view, _html} = mount_columns(conn)
    open_chooser(view)

    view |> element("#gantt-columns") |> render_keydown(%{"key" => "Escape"})
    refute has_element?(view, "#gantt-columns")

    {:ok, view, _html} = mount_columns(conn, column_chooser: false)
    refute has_element?(view, "#gantt-columns-toggle")
  end

  test "readonly charts keep the chooser", %{conn: conn} do
    {:ok, view, _html} = mount_columns(conn, readonly: true)
    open_chooser(view)

    refute has_element?(view, "#gantt-column-add")
    show(view, ["text", "wbs"])
    assert headers(view) == ["wbs", "text"]
  end
end
