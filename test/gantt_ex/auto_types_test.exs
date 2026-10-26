defmodule GanttEx.AutoTypesTest do
  use ExUnit.Case, async: true

  alias GanttEx.Store

  @tasks [
    %{id: 1, text: "Parent", start_date: ~D[2025-01-01], duration: 1},
    %{id: 2, text: "Child", parent: 1, start_date: ~D[2025-01-02], duration: 3},
    %{id: 3, text: "Empty project", type: :project, start_date: ~D[2025-01-01], duration: 1}
  ]

  test "types follow the tree when loading" do
    store = Store.new!(@tasks, [], auto_types: true)
    assert Store.get_task(store, 1).type == :project
    assert Store.get_task(store, 3).type == :task
    # the new project is rolled up from its child
    assert Store.get_task(store, 1).start_date == ~N[2025-01-02 00:00:00]
  end

  test "mutations retype the parents" do
    store = Store.new!(@tasks, [], auto_types: true)

    {:ok, store, changes} = Store.add_task(store, %{id: 4, parent: 3, start_date: ~D[2025-01-05]})

    assert {:task_updated, %{id: 3, type: :project}, %{changes: %{type: :project}}} =
             Enum.find(changes, &match?({:task_updated, %{id: 3}, _}, &1))

    {:ok, store, changes} = Store.delete_task(store, 2)
    assert Enum.any?(changes, &match?({:task_updated, %{id: 1, type: :task}, _}, &1))

    {:ok, store, _changes} = Store.move_task(store, 4, 1, nil)
    assert Store.get_task(store, 1).type == :project
    assert Store.get_task(store, 3).type == :task
  end

  test "without auto types nothing changes" do
    store = Store.new!(@tasks)
    assert Store.get_task(store, 1).type == :task
    assert Store.get_task(store, 3).type == :project
  end

  test "lazy branches report children before they are loaded" do
    store = Store.new!([%{id: 1, text: "Lazy", start_date: ~D[2025-01-01], has_children: true}])
    assert [%{has_children: true, open: false}] = Store.rows(store)
  end
end
