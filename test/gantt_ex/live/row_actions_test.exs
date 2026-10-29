defmodule GanttEx.Live.RowActionsTest do
  use GanttEx.LiveCase, async: true

  alias GanttEx.Event

  @all [:drag, :rename, :edit, :block, :restriction, :detail, :delete]
  @approve %{id: :approve, icon: :check, label: "Approve"}

  defp mount_actions(conn, opts \\ []) do
    mount_gantt(conn, Keyword.put_new(opts, :row_actions, @all ++ [@approve]))
  end

  defp click(view, selector), do: view |> element(selector) |> render_click()

  test "renders compact buttons with tooltips on every task row", %{conn: conn} do
    {:ok, view, _html} = mount_actions(conn)

    assert has_element?(view, "[role=columnheader] .gx-sr-only", "Actions")

    for {action, label} <- [
          drag: "Drag to reorder",
          rename: "Rename",
          edit: "Edit",
          block: "Block task",
          restriction: "Add restriction",
          detail: "Open detail",
          delete: "Delete",
          approve: "Approve"
        ] do
      assert has_element?(
               view,
               "#gantt-row-2-#{action}.gx-action[title='#{label}'][aria-label='#{label}']"
             )
    end

    # the column is as wide as its actions
    assert render(view) =~ "--gx-col-4: #{GanttEx.Live.Columns.actions_width(8)}px"
  end

  test "the actions do not select the row", %{conn: conn} do
    {:ok, view, _html} = mount_actions(conn)

    click(view, "#gantt-row-3-detail")
    refute has_element?(view, "#gantt-row-3.gx-row--selected")
    refute_received {:gantt_event, %Event{type: :task_selected}}
  end

  test "block toggles the task through the normal change path", %{conn: conn} do
    {:ok, view, _html} = mount_actions(conn)

    click(view, "#gantt-row-2-block")

    assert_gantt_event(%Event{
      type: :task_updated,
      task: %{id: 2, blocked: true},
      changes: %{blocked: true}
    })

    assert has_element?(view, "#gantt-row-2 .gx-flag--blocked")
    assert has_element?(view, "#gantt-row-2-block.gx-action--on[title='Unblock task']")

    click(view, "#gantt-row-2-block")
    assert_gantt_event(%Event{type: :task_updated, changes: %{blocked: false}})
    refute has_element?(view, "#gantt-row-2 .gx-flag--blocked")
  end

  test "blocking can be undone", %{conn: conn} do
    {:ok, view, _html} = mount_actions(conn)

    click(view, "#gantt-row-3-block")
    assert_gantt_event(%Event{type: :task_updated, changes: %{blocked: true}})

    click(view, "#gantt-undo")
    assert_gantt_event(%Event{type: :task_updated, task: %{id: 3}, changes: %{blocked: false}})
    refute has_element?(view, "#gantt-row-3 .gx-flag--blocked")

    click(view, "#gantt-redo")
    assert_gantt_event(%Event{type: :task_updated, task: %{id: 3}, changes: %{blocked: true}})
  end

  test "restriction, detail and custom actions are reported to the parent", %{conn: conn} do
    {:ok, view, _html} = mount_actions(conn)

    click(view, "#gantt-row-2-restriction")
    assert_gantt_event(%Event{type: :task_action, action: :restriction, task: %{id: 2}})

    click(view, "#gantt-row-4-detail")
    assert_gantt_event(%Event{type: :task_action, action: :detail, task: %{id: 4}})

    click(view, "#gantt-row-3-approve")

    assert_gantt_event(%Event{
      type: :task_action,
      gantt_id: "gantt",
      action: :approve,
      task: %{id: 3}
    })
  end

  test "rename edits the name in place", %{conn: conn} do
    {:ok, view, _html} = mount_actions(conn)

    click(view, "#gantt-row-3-rename")
    assert has_element?(view, "#gantt-row-3 #gantt-cell-editor input[name=value][value=Build]")

    view |> element("#gantt-cell-editor") |> render_submit(%{"value" => "Build it"})
    assert_gantt_event(%Event{type: :task_updated, task: %{id: 3}, changes: %{text: "Build it"}})
  end

  test "edit opens the lightbox and delete asks first", %{conn: conn} do
    {:ok, view, _html} = mount_actions(conn)

    click(view, "#gantt-row-3-edit")
    assert has_element?(view, "#gantt-lightbox input[name='task[text]'][value=Build]")
    click(view, "#gantt-lightbox button[aria-label=Close]")

    click(view, "#gantt-row-3-delete")
    assert has_element?(view, "#gantt-confirm")
    click(view, "#gantt-confirm-yes")
    assert_gantt_event(%Event{type: :task_deleted, task: %{id: 3}})
  end

  test "the drag handle reorders with the arrow keys", %{conn: conn} do
    {:ok, view, _html} = mount_actions(conn)

    assert has_element?(view, "#gantt-row-2-drag[data-gx-drag-handle][aria-disabled=false]")

    view |> element("#gantt-row-2-drag") |> render_keydown(%{"key" => "ArrowDown"})

    assert_gantt_event(%Event{type: :task_moved, task: %{id: 2}, parent: 1, siblings: [3, 2]})

    assert_push_event(view, "gantt_ex:focus", %{
      selector: "[data-gx-row='2'] [data-gx-drag-handle]"
    })

    # the first sibling cannot go up, other keys do nothing
    view |> element("#gantt-row-3-drag") |> render_keydown(%{"key" => "ArrowUp"})
    view |> element("#gantt-row-3-drag") |> render_keydown(%{"key" => "Tab"})
    refute_received {:gantt_event, %Event{type: :task_moved}}
  end

  test "the drag handle explains why rows cannot be reordered", %{conn: conn} do
    {:ok, view, _html} = mount_actions(conn)

    view |> element("[role=columnheader] button.gx-sort", "Task name") |> render_click()

    assert has_element?(
             view,
             "#gantt-row-2-drag[aria-disabled=true][title='Clear the sorting to reorder']"
           )

    refute has_element?(view, "#gantt-row-2-drag[phx-keydown]")

    {:ok, view, _html} = mount_actions(conn)
    view |> element("#gantt-search") |> render_change(%{"search" => "d"})

    assert has_element?(
             view,
             "#gantt-row-2-drag[aria-disabled=true][title='Clear the filters to reorder']"
           )

    {:ok, view, _html} = mount_actions(conn, reorder: false)

    assert has_element?(
             view,
             "#gantt-row-2-drag[aria-disabled=true][title='Reordering is not available']"
           )
  end

  test "readonly charts only keep the actions that do not edit", %{conn: conn} do
    {:ok, view, _html} = mount_actions(conn, readonly: true)

    assert has_element?(view, "#gantt-row-2-detail")
    assert has_element?(view, "#gantt-row-2-approve")

    for action <- [:drag, :rename, :edit, :block, :restriction, :delete] do
      refute has_element?(view, "#gantt-row-2-#{action}")
    end

    assert render(view) =~ "--gx-col-4: #{GanttEx.Live.Columns.actions_width(2)}px"

    # forged events are ignored
    view |> element("#gantt") |> render_hook("row_action", %{"action" => "block", "key" => "2"})
    refute_received {:gantt_event, %Event{type: :task_updated}}
  end

  test "readonly tasks hide the actions that edit", %{conn: conn} do
    tasks = List.update_at(sample_tasks(), 1, &Map.put(&1, :readonly, true))
    {:ok, view, _html} = mount_actions(conn, tasks: tasks)

    refute has_element?(view, "#gantt-row-2-block")
    assert has_element?(view, "#gantt-row-2-detail")
    assert has_element?(view, "#gantt-row-3-block")

    view |> element("#gantt") |> render_hook("row_action", %{"action" => "block", "key" => "2"})

    view
    |> element("#gantt")
    |> render_hook("row_action", %{"action" => "restriction", "key" => "2"})

    refute_received {:gantt_event, _event}
  end

  test "actions may be offered to some tasks only", %{conn: conn} do
    # Design (2) has some progress. Functions can't go in the session of
    # the test LiveView: they are assigned once it's mounted.
    unfinished = &(&1.progress == 0)
    {:ok, view, _html} = mount_actions(conn)

    send(
      view.pid,
      {:assign,
       row_actions: [
         %{id: :restriction, when: unfinished},
         Map.put(@approve, :when, unfinished),
         :detail
       ]}
    )

    _ = :sys.get_state(view.pid)

    refute has_element?(view, "#gantt-row-2-restriction")
    refute has_element?(view, "#gantt-row-2-approve")
    assert has_element?(view, "#gantt-row-2-detail")
    assert has_element?(view, "#gantt-row-3-restriction[title='Add restriction']")
    assert has_element?(view, "#gantt-row-3-approve")

    # nor taken from the client for the other tasks
    view
    |> element("#gantt")
    |> render_hook("row_action", %{"action" => "restriction", "key" => "2"})

    refute_received {:gantt_event, %Event{type: :task_action}}

    click(view, "#gantt-row-3-restriction")
    assert_gantt_event(%Event{type: :task_action, action: :restriction})
  end

  test "edit is hidden without lightbox", %{conn: conn} do
    {:ok, view, _html} = mount_actions(conn, lightbox: false)

    refute has_element?(view, "#gantt-row-2-edit")
    assert has_element?(view, "#gantt-row-2-rename")
  end

  test "custom actions need a known icon" do
    labels = GanttEx.I18n.labels("en")
    slot = %{field: :actions, actions: [%{id: :x, icon: :nope, label: "X"}]}

    assert_raise ArgumentError, ~r/unknown icon :nope/, fn ->
      GanttEx.Live.Columns.build([slot], labels)
    end

    assert_raise ArgumentError, ~r/invalid row action :fly/, fn ->
      GanttEx.Live.Columns.build([%{field: :actions, actions: [:fly]}], labels)
    end
  end
end
