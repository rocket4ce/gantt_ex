defmodule GanttEx.Live.ContextMenuTest do
  use GanttEx.LiveCase, async: true

  alias GanttEx.Event

  @actions [:drag, :rename, :block, :detail, %{id: :approve, icon: :check, label: "Approve"}]

  defp open_menu(view, key, params \\ %{}) do
    view
    |> element("#gantt")
    |> render_hook("gx:context_menu", Map.merge(%{"key" => key, "x" => 120, "y" => 80}, params))
  end

  test "a right click opens the actions of the row, named", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn, row_actions: @actions, context_menu: true)
    assert has_element?(view, "#gantt[data-gx-context-menu=true]")

    open_menu(view, "3")

    # the task is selected and the menu has every action but the drag handle
    assert has_element?(view, "#gantt-row-3.gx-row--selected")
    assert has_element?(view, "#gantt-context-menu[role=menu]", "Build")
    assert has_element?(view, "#gantt-context-menu-rename[role=menuitem]", "Rename")
    assert has_element?(view, "#gantt-context-menu-block", "Block task")
    assert has_element?(view, "#gantt-context-menu-detail", "Open detail")
    assert has_element?(view, "#gantt-context-menu-approve", "Approve")
    refute has_element?(view, "#gantt-context-menu-drag")
    assert has_element?(view, "#gantt-context-menu[style='left: 120px; top: 80px']")

    # an action of the host is reported, and the menu closes
    view |> element("#gantt-context-menu-detail") |> render_click()
    assert_gantt_event(%Event{type: :task_action, action: :detail, task: %{id: 3}})
    refute has_element?(view, "#gantt-context-menu")

    # a built-in one runs in the chart
    open_menu(view, "3")
    view |> element("#gantt-context-menu-block") |> render_click()
    assert has_element?(view, "#gantt-bar-3.gx-bar--blocked")

    open_menu(view, "3")
    assert has_element?(view, "#gantt-context-menu-block", "Unblock task")

    # Escape closes it
    view |> element("#gantt-context-menu") |> render_keydown(%{"key" => "Escape"})
    refute has_element?(view, "#gantt-context-menu")
  end

  test "it turns to stay inside the chart", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn, context_menu: true)

    open_menu(view, "2", %{"x" => 900, "y" => 600, "width" => 1000, "height" => 640})
    assert has_element?(view, "#gantt-context-menu.gx-context-menu--left.gx-context-menu--up")

    open_menu(view, "2", %{"x" => 100, "y" => 100, "width" => 1000, "height" => 640})
    refute has_element?(view, "#gantt-context-menu.gx-context-menu--left")
  end

  test "a list gives its own actions, and read-only charts leave out the editing ones", %{
    conn: conn
  } do
    {:ok, view, _html} =
      mount_gantt(conn, row_actions: [:detail], context_menu: [:detail, :edit, :delete])

    open_menu(view, "2")
    assert has_element?(view, "#gantt-context-menu-edit", "Edit")
    assert has_element?(view, "#gantt-context-menu-delete.gx-menu-item--danger", "Delete")

    {:ok, view, _html} =
      mount_gantt(conn, readonly: true, context_menu: [:detail, :edit, :delete])

    open_menu(view, "2")
    assert has_element?(view, "#gantt-context-menu-detail")
    refute has_element?(view, "#gantt-context-menu-delete")
  end

  test "without the option there is no menu", %{conn: conn} do
    {:ok, view, _html} = mount_gantt(conn, row_actions: @actions)
    assert has_element?(view, "#gantt[data-gx-context-menu=false]")

    open_menu(view, "2")
    refute has_element?(view, "#gantt-context-menu")
  end
end
