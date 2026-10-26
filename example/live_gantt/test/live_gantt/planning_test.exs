defmodule LiveGantt.PlanningTest do
  use LiveGantt.DataCase, async: true

  import LiveGantt.PlanningFixtures

  alias GanttEx.Event
  alias LiveGantt.Planning
  alias LiveGantt.Planning.{Link, Task}

  setup do
    project_fixture()
  end

  defp gantt_task(%Task{} = record), do: GanttEx.Task.new!(record)
  defp gantt_link(%Link{} = record), do: GanttEx.Link.new!(record)

  test "lists tasks in position order", %{design: design, build: build} do
    ids = Planning.list_tasks() |> Enum.map(& &1.id)
    assert Enum.find_index(ids, &(&1 == design.id)) < Enum.find_index(ids, &(&1 == build.id))
  end

  test "persists created tasks at the end of their branch", %{project: project} do
    task =
      GanttEx.Task.new!(
        id: "gx-temp",
        text: "QA",
        parent: project.id,
        start_date: ~D[2025-01-12],
        duration: 3,
        meta: %{"owner" => "Luis"}
      )

    assert :ok = Planning.apply_event(%Event{type: :task_created, task: task})

    assert %Task{parent_id: parent_id, position: 2, duration: 3, owner: "Luis"} =
             Repo.get_by!(Task, text: "QA")

    assert parent_id == project.id
  end

  test "persists only the changed fields", %{design: design} do
    task = gantt_task(design)

    changes = %{
      start_date: ~N[2025-01-10 00:00:00],
      end_date: ~N[2025-01-12 00:00:00],
      meta: %{owner: "Marta"}
    }

    assert :ok = Planning.apply_event(%Event{type: :task_updated, task: task, changes: changes})

    assert %Task{start_date: ~N[2025-01-10 00:00:00], duration: 2, owner: "Marta"} =
             Repo.reload!(design)
  end

  test "persists moves and sibling positions", %{project: project, design: design, build: build} do
    event = %Event{
      type: :task_moved,
      task: gantt_task(build),
      parent: project.id,
      index: 0,
      siblings: [build.id, design.id]
    }

    assert :ok = Planning.apply_event(event)
    assert Repo.reload!(build).position == 0
    assert Repo.reload!(design).position == 1

    assert :ok = Planning.apply_event(%{event | parent: nil, siblings: [project.id, build.id]})
    assert Repo.reload!(build).parent_id == nil
  end

  test "deleting a task cascades to its children and links", %{project: project} do
    assert :ok = Planning.apply_event(%Event{type: :task_deleted, task: gantt_task(project)})
    assert Repo.aggregate(Task, :count) == 0
    assert Repo.aggregate(Link, :count) == 0
  end

  test "persists links", %{design: design, build: build, link: link} do
    assert :ok =
             Planning.apply_event(%Event{
               type: :link_updated,
               link: gantt_link(link),
               changes: %{type: :start_to_start, lag: 2}
             })

    assert %Link{type: :start_to_start, lag: 2} = Repo.reload!(link)

    assert :ok = Planning.apply_event(%Event{type: :link_deleted, link: gantt_link(link)})
    refute Repo.get(Link, link.id)

    new =
      GanttEx.Link.new!(id: "gx-l", source: build.id, target: design.id, type: :finish_to_finish)

    assert :ok = Planning.apply_event(%Event{type: :link_created, link: new})
    assert %Link{type: :finish_to_finish} = Repo.get_by!(Link, source_id: build.id)
  end

  test "temporary ids are not persisted yet" do
    task = GanttEx.Task.new!(id: "gx-temp", start_date: ~D[2025-01-01])

    assert {:error, :not_found} =
             Planning.apply_event(%Event{type: :task_updated, task: task, changes: %{text: "A"}})

    assert :ok = Planning.apply_event(%Event{type: :task_deleted, task: task})
  end

  test "ignores events that are not changes", %{design: design} do
    assert :ok = Planning.apply_event(%Event{type: :task_selected, task: gantt_task(design)})
  end
end
