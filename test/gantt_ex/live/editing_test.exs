defmodule GanttEx.Live.EditingTest do
  use GanttEx.LiveCase, async: true

  alias GanttEx.Event

  describe "lightbox" do
    test "adds a task", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)

      view |> element("#gantt-add-task") |> render_click()
      assert has_element?(view, "#gantt-lightbox", "New task")

      view
      |> element("#gantt-lightbox-form")
      |> render_submit(%{
        "task" => %{
          "text" => "QA",
          "type" => "task",
          "parent" => "1",
          "start_date" => "2025-01-14",
          "duration" => "2",
          "progress" => "10"
        }
      })

      refute has_element?(view, "#gantt-lightbox")
      assert_gantt_event(%Event{type: :task_created, task: task})
      assert %{text: "QA", parent: 1, duration: 2, progress: 0.1} = task
      assert task.start_date == ~N[2025-01-14 00:00:00]
      assert "gx-" <> _ = task.id
      # the parent project grows
      assert_gantt_event(%Event{type: :task_updated, task: %{id: 1}, changes: %{end_date: _}})
      assert has_element?(view, ".gx-row", "QA")
    end

    test "validates the form", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)

      view |> element("#gantt-add-task") |> render_click()

      view
      |> element("#gantt-lightbox-form")
      |> render_change(%{
        "task" => %{"text" => "", "start_date" => "2025-01-14", "duration" => "-2"}
      })

      assert has_element?(view, "#gantt-lightbox .gx-error", "can't be blank")
      assert has_element?(view, "#gantt-lightbox .gx-error", "must be a whole number")

      view |> element("#gantt-lightbox-form") |> render_submit(%{"task" => %{"text" => ""}})
      assert has_element?(view, "#gantt-lightbox")
      refute_received {:gantt_event, %Event{type: :task_created}}
    end

    test "edits a task opened with a double click", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)

      view |> element("#gantt") |> render_hook("gx:dblclick", %{"key" => "3"})
      assert has_element?(view, "#gantt-lightbox", "Edit task")
      assert has_element?(view, "#gantt-lightbox input[name='task[text]'][value=Build]")

      view
      |> element("#gantt-lightbox-form")
      |> render_submit(%{"task" => %{"text" => "Build & test", "duration" => "6"}})

      assert_gantt_event(%Event{type: :task_updated, task: %{id: 3}, changes: changes})
      assert changes.text == "Build & test"
      assert changes.end_date == ~N[2025-01-15 00:00:00]
      assert has_element?(view, "#gantt-row-3", "Build & test")
    end

    test "cancel closes without changes", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)

      view |> element("#gantt") |> render_hook("gx:dblclick", %{"key" => "2"})
      view |> element("#gantt-lightbox button", "Cancel") |> render_click()

      refute has_element?(view, "#gantt-lightbox")
      refute_received {:gantt_event, %Event{type: :task_updated}}
    end

    test "readonly tasks cannot be opened", %{conn: conn} do
      tasks = List.update_at(sample_tasks(), 1, &Map.put(&1, :readonly, true))
      {:ok, view, _html} = mount_gantt(conn, tasks: tasks)

      view |> element("#gantt") |> render_hook("gx:dblclick", %{"key" => "2"})
      refute has_element?(view, "#gantt-lightbox")
    end
  end

  describe "deletion" do
    test "deletes a task and its links after confirmation", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)

      view |> element("#gantt-bar-3") |> render_click()
      view |> element("#gantt-quick-info-delete") |> render_click()
      assert has_element?(view, "#gantt-confirm")

      view |> element("#gantt-confirm-yes") |> render_click()

      refute has_element?(view, "#gantt-row-3")
      refute has_element?(view, "#gantt-confirm")
      assert_gantt_event(%Event{type: :link_deleted, link: %{id: 1}})
      assert_gantt_event(%Event{type: :link_deleted, link: %{id: 2}})
      assert_gantt_event(%Event{type: :task_deleted, task: %{id: 3}})
    end

    test "can be cancelled", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)

      view |> element("#gantt-bar-3") |> render_click()
      view |> element("#gantt-quick-info-delete") |> render_click()
      view |> element("#gantt-confirm-no") |> render_click()

      assert has_element?(view, "#gantt-row-3")
      refute_received {:gantt_event, %Event{type: :task_deleted}}
    end

    test "warns about subtasks", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)

      view |> element("#gantt") |> render_hook("gx:dblclick", %{"key" => "1"})
      view |> element("#gantt-lightbox-delete") |> render_click()

      assert has_element?(view, "#gantt-confirm", "Its subtasks will be deleted too.")
    end
  end

  describe "inline editing" do
    test "edits a cell of the selected row", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)

      view |> element("#gantt-row-2") |> render_click()
      view |> element("#gantt-row-2 [role=gridcell][phx-value-field=text]") |> render_click()
      assert has_element?(view, "#gantt-cell-editor input[name=value][value=Design]")

      view |> element("#gantt-cell-editor") |> render_submit(%{"value" => "UX design"})

      refute has_element?(view, "#gantt-cell-editor")
      assert_gantt_event(%Event{type: :task_updated, task: %{id: 2, text: "UX design"}})
    end

    test "editing the end date resizes the task", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)

      view |> element("#gantt-row-2") |> render_click()
      view |> element("#gantt-row-2 [role=gridcell][phx-value-field=end_date]") |> render_click()
      # shown inclusive
      assert has_element?(view, "#gantt-cell-editor input[value='2025-01-08']")

      view |> element("#gantt-cell-editor") |> render_submit(%{"value" => "2025-01-10"})

      assert_gantt_event(%Event{type: :task_updated, task: task})
      assert {task.end_date, task.duration} == {~N[2025-01-11 00:00:00], 5}
    end

    test "edits custom fields into meta", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)

      view |> element("#gantt-row-3") |> render_click()
      view |> element("#gantt-row-3 [role=gridcell][phx-value-field=owner]") |> render_click()
      view |> element("#gantt-cell-editor") |> render_submit(%{"value" => "Marta"})

      assert_gantt_event(%Event{type: :task_updated, task: task})
      assert task.meta.owner == "Marta"
      assert has_element?(view, "#gantt-row-3 .owner", "Marta")
    end

    test "escape cancels the edition", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)

      view |> element("#gantt-row-2") |> render_click()
      view |> element("#gantt-row-2 [role=gridcell][phx-value-field=text]") |> render_click()
      view |> element("#gantt-cell-input") |> render_keydown(%{"key" => "Escape"})

      refute has_element?(view, "#gantt-cell-editor")
    end

    test "project dates are not editable", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)

      refute has_element?(
               view,
               "#gantt-row-1 [role=gridcell][phx-value-field=start_date][phx-click]"
             )

      assert has_element?(
               view,
               "#gantt-row-2 [role=gridcell][phx-value-field=start_date][phx-click]"
             )
    end
  end

  describe "links" do
    test "edits the type and lag of a link", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)

      view |> element("g[data-gx-link='1']") |> render_click()
      assert has_element?(view, "#gantt-link-editor", "Design")

      view
      |> element("#gantt-link-form")
      |> render_submit(%{"link" => %{"type" => "start_to_start", "lag" => "1"}})

      refute has_element?(view, "#gantt-link-editor")
      assert_gantt_event(%Event{type: :link_updated, link: link, changes: changes})
      assert {link.type, link.lag} == {:start_to_start, 1}
      assert changes == %{type: :start_to_start, lag: 1}
    end

    test "deletes a link", %{conn: conn} do
      {:ok, view, _html} = mount_gantt(conn)

      view |> element("g[data-gx-link='2']") |> render_click()
      view |> element("#gantt-link-delete") |> render_click()
      view |> element("#gantt-confirm-yes") |> render_click()

      refute has_element?(view, "g[data-gx-link='2']")
      assert_gantt_event(%Event{type: :link_deleted, link: %{id: 2}})
    end
  end
end
