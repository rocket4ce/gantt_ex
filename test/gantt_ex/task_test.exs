defmodule GanttEx.TaskTest do
  use ExUnit.Case, async: true

  alias GanttEx.{Store, Task}

  describe "blocked and restrictions" do
    test "default to an unblocked task without restrictions" do
      task = Task.new!(id: 1)
      assert {task.blocked, task.restrictions} == {false, 0}
    end

    test "are cast from client and database values" do
      assert %{blocked: true, restrictions: 2} =
               Task.new!(%{"id" => 1, "blocked" => "1", "restrictions" => " 2 "})

      assert %{blocked: false, restrictions: 0} =
               Task.new!(id: 1, blocked: nil, restrictions: nil)

      # a list (such as the open restrictions themselves) counts its elements
      assert %{restrictions: 3} = Task.new!(id: 1, restrictions: [:permit, :crane, :steel])
      assert %{restrictions: 2} = Task.new!(id: 1, restrictions: 2.0)
    end

    test "reject invalid values" do
      assert Task.new(id: 1, blocked: "maybe") == {:error, {:invalid, :blocked}}
      assert Task.new(id: 1, restrictions: -2) == {:error, {:invalid, :restrictions}}
      assert Task.new(id: 1, restrictions: "many") == {:error, {:invalid, :restrictions}}
    end

    test "are first-class fields, not meta" do
      task = Task.new!(id: 1, blocked: true, restrictions: 1)

      assert task.meta == %{}
      assert %{blocked: true, restrictions: 1} = Task.to_map(task)

      assert {:ok, %{blocked: false, restrictions: 4}} =
               Task.change(task, %{"blocked" => false, "restrictions" => "4"})
    end

    test "changes are reported and diffed by the store" do
      store = Store.new!([%{id: 1, start_date: ~D[2025-01-01]}])

      assert {:ok, updated, [{:task_updated, _task, %{changes: %{blocked: true}}}]} =
               Store.update_task(store, 1, %{blocked: true})

      assert [{:task_updated, _task, %{changes: %{blocked: false}}}] = Store.diff(updated, store)
    end
  end
end
