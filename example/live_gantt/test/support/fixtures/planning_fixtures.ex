defmodule LiveGantt.PlanningFixtures do
  @moduledoc "Test helpers to create tasks and links."
  alias LiveGantt.Planning

  def task_fixture(attrs \\ %{}) do
    {:ok, task} =
      attrs
      |> Enum.into(%{text: "Task", start_date: ~N[2025-01-06 00:00:00], duration: 2})
      |> Planning.create_task()

    task
  end

  def link_fixture(source, target, attrs \\ %{}) do
    {:ok, link} =
      attrs
      |> Enum.into(%{source_id: source.id, target_id: target.id})
      |> Planning.create_link()

    link
  end

  @doc "A project with two tasks and a dependency."
  def project_fixture do
    project = task_fixture(%{text: "Website", type: :project, position: 0})
    design = task_fixture(%{text: "Design", parent_id: project.id, position: 0, owner: "Ana"})

    build =
      task_fixture(%{
        text: "Build",
        parent_id: project.id,
        position: 1,
        start_date: ~N[2025-01-08 00:00:00],
        duration: 4
      })

    link = link_fixture(design, build)
    %{project: project, design: design, build: build, link: link}
  end
end
