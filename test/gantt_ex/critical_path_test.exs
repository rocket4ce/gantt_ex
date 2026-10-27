defmodule GanttEx.CriticalPathTest do
  use ExUnit.Case, async: true

  alias GanttEx.{CriticalPath, Store}

  test "a broken dependency gives negative slack and is critical" do
    store =
      Store.new!(
        [
          %{id: 1, start_date: ~D[2025-01-06], duration: 4},
          %{id: 2, start_date: ~D[2025-01-08], duration: 2}
        ],
        [%{id: 1, source: 1, target: 2}]
      )

    analysis = CriticalPath.analyze(store)
    assert analysis.tasks[1].total_slack == -2
    assert analysis.tasks[1].critical
  end

  test "projects are critical when a descendant is" do
    store =
      Store.new!(
        [
          %{id: 10, type: :project},
          %{id: 1, parent: 10, start_date: ~D[2025-01-06], duration: 2},
          %{id: 2, parent: 10, start_date: ~D[2025-01-06], duration: 1},
          %{id: 3, start_date: ~D[2025-01-08], duration: 1}
        ],
        [%{id: 1, source: 10, target: 3}]
      )

    analysis = CriticalPath.analyze(store)
    assert analysis.tasks[1].critical
    refute analysis.tasks[2].critical
    assert analysis.tasks[2].total_slack == 1
    assert analysis.tasks[10].critical
    assert MapSet.member?(analysis.links, 1)
  end

  test "nested projects take their most critical descendant" do
    store =
      Store.new!(
        [
          %{id: 100, type: :project},
          %{id: 10, parent: 100, type: :project},
          %{id: 11, parent: 10, start_date: ~D[2025-01-06], duration: 4},
          %{id: 12, parent: 100, start_date: ~D[2025-01-06], duration: 1},
          %{id: 20, type: :project, start_date: ~D[2025-01-06]}
        ],
        []
      )

    analysis = CriticalPath.analyze(store)
    assert analysis.tasks[10] == analysis.tasks[11]
    assert analysis.tasks[100] == analysis.tasks[11]
    assert analysis.tasks[12].total_slack == 3
    # a project without children is scheduled like a task
    assert Map.has_key?(analysis.tasks, 20)
  end

  test "slack counts working days" do
    store =
      Store.new!(
        [
          %{id: 1, start_date: ~D[2025-01-09], duration: 1},
          %{id: 2, start_date: ~D[2025-01-06], duration: 5}
        ],
        [],
        work_time: true
      )

    # task 1 (Thu) can slip to Fri, the last working day of the project
    assert CriticalPath.analyze(store).tasks[1].total_slack == 1
  end

  test "empty stores" do
    assert %{tasks: tasks, links: links} = CriticalPath.analyze(Store.new!())
    assert tasks == %{}
    assert MapSet.size(links) == 0
  end
end
