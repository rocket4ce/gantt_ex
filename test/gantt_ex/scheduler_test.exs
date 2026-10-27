defmodule GanttEx.SchedulerTest do
  use ExUnit.Case, async: true

  alias GanttEx.{Scheduler, Store}

  defp store(tasks, links, opts \\ []), do: Store.new!(tasks, links, opts)
  defp start(store, id), do: Store.get_task(store, id).start_date
  defp schedule(store, opts \\ []), do: store |> Scheduler.schedule(opts) |> elem(1)

  @a %{id: 1, start_date: ~D[2025-01-06], duration: 3}
  @b %{id: 2, start_date: ~D[2025-01-06], duration: 2}

  describe "link types" do
    test "start to start with lag" do
      s =
        store([@a, @b], [%{id: 1, source: 1, target: 2, type: :start_to_start, lag: 1}])
        |> schedule()

      assert start(s, 2) == ~N[2025-01-07 00:00:00]
    end

    test "finish to finish" do
      s = store([@a, @b], [%{id: 1, source: 1, target: 2, type: :finish_to_finish}]) |> schedule()
      # A ends on the 9th, so B (2 days) starts on the 7th
      assert start(s, 2) == ~N[2025-01-07 00:00:00]
    end

    test "start to finish" do
      b = %{@b | start_date: ~D[2025-01-01]}
      s = store([@a, b], [%{id: 1, source: 1, target: 2, type: :start_to_finish}]) |> schedule()
      assert Store.get_task(s, 2).end_date == ~N[2025-01-06 00:00:00]
    end

    test "negative lags (leads)" do
      s = store([@a, @b], [%{id: 1, source: 1, target: 2, lag: -1}]) |> schedule()
      assert start(s, 2) == ~N[2025-01-08 00:00:00]
    end
  end

  test "non-strict mode only moves tasks that violate a dependency" do
    late = %{@b | start_date: ~D[2025-01-20]}
    s = store([@a, late], [%{id: 1, source: 1, target: 2}]) |> schedule()
    assert start(s, 2) == ~N[2025-01-20 00:00:00]

    s = store([@a, late], [%{id: 1, source: 1, target: 2}]) |> schedule(strict: true)
    assert start(s, 2) == ~N[2025-01-09 00:00:00]
  end

  test "chains propagate in dependency order, whatever the tree order" do
    tasks = [%{id: 3, start_date: ~D[2025-01-01], duration: 1}, @b, @a]
    links = [%{id: 1, source: 1, target: 2}, %{id: 2, source: 2, target: 3}]
    s = store(tasks, links) |> schedule()
    assert start(s, 3) == ~N[2025-01-11 00:00:00]
  end

  describe "constraints" do
    test "start and finish no earlier than" do
      s =
        store([Map.merge(@a, %{constraint_type: :snet, constraint_date: ~D[2025-01-10]})], [])
        |> schedule()

      assert start(s, 1) == ~N[2025-01-10 00:00:00]

      s =
        store([Map.merge(@a, %{constraint_type: "fnet", constraint_date: "2025-01-20"})], [])
        |> schedule()

      assert Store.get_task(s, 1).end_date == ~N[2025-01-20 00:00:00]
    end

    test "must start / must finish on win over dependencies" do
      b = Map.merge(@b, %{constraint_type: :mso, constraint_date: ~D[2025-01-07]})
      s = store([@a, b], [%{id: 1, source: 1, target: 2}]) |> schedule()
      assert start(s, 2) == ~N[2025-01-07 00:00:00]

      b = Map.merge(@b, %{constraint_type: :mfo, constraint_date: ~D[2025-01-15]})
      s = store([@a, b], [%{id: 1, source: 1, target: 2}]) |> schedule()
      assert Store.get_task(s, 2).end_date == ~N[2025-01-15 00:00:00]
    end

    test "start no later than caps the start" do
      b = Map.merge(@b, %{constraint_type: :snlt, constraint_date: ~D[2025-01-08]})
      s = store([@a, b], [%{id: 1, source: 1, target: 2}]) |> schedule()
      assert start(s, 2) == ~N[2025-01-08 00:00:00]
    end

    test "as late as possible" do
      tasks = [
        Map.merge(@a, %{constraint_type: :alap}),
        %{id: 2, start_date: ~D[2025-01-06], duration: 8},
        %{id: 3, start_date: ~D[2025-01-20], type: :milestone}
      ]

      s = store(tasks, [%{id: 1, source: 1, target: 3}]) |> schedule()
      # right before the milestone that depends on it
      assert Store.get_task(s, 1).end_date == ~N[2025-01-20 00:00:00]
    end
  end

  test "links to a project constrain its children, links from a project use its end" do
    tasks = [
      @a,
      %{id: 10, type: :project},
      %{id: 11, parent: 10, start_date: ~D[2025-01-06], duration: 2},
      %{id: 12, parent: 10, start_date: ~D[2025-01-07], duration: 2},
      %{id: 20, start_date: ~D[2025-01-06], duration: 1}
    ]

    links = [%{id: 1, source: 1, target: 10}, %{id: 2, source: 10, target: 20}]
    s = store(tasks, links) |> schedule()

    assert start(s, 11) == ~N[2025-01-09 00:00:00]
    assert start(s, 12) == ~N[2025-01-09 00:00:00]
    assert start(s, 20) == ~N[2025-01-11 00:00:00]
  end

  test "links from an outer project see the moves of nested children" do
    tasks = [
      @a,
      %{id: 100, type: :project},
      %{id: 10, parent: 100, type: :project},
      %{id: 11, parent: 10, start_date: ~D[2025-01-06], duration: 2},
      %{id: 20, start_date: ~D[2025-01-06], duration: 1}
    ]

    links = [%{id: 1, source: 1, target: 11}, %{id: 2, source: 100, target: 20}]
    {:ok, s, changes} = store(tasks, links) |> Scheduler.schedule()

    # 11 follows 1 (ends Jan 11), so both projects end on Jan 11 and 20 follows them
    assert start(s, 11) == ~N[2025-01-09 00:00:00]
    assert Store.get_task(s, 100).end_date == ~N[2025-01-11 00:00:00]
    assert start(s, 20) == ~N[2025-01-11 00:00:00]

    changed = for {:task_updated, task, _} <- changes, into: %{}, do: {task.id, task}
    assert Map.keys(changed) |> Enum.sort() == [10, 11, 20, 100]
    assert changed[100] == Store.get_task(s, 100)
  end

  test "honors working time" do
    tasks = [
      %{id: 1, start_date: ~D[2025-01-08], duration: 2},
      %{id: 2, start_date: ~D[2025-01-06], duration: 1}
    ]

    s = store(tasks, [%{id: 1, source: 1, target: 2}], work_time: true) |> schedule()
    # Wed 8 + 2 working days -> ends Fri 10 -> B starts on Fri 10
    assert start(s, 2) == ~N[2025-01-10 00:00:00]

    s =
      store(
        [%{(tasks |> hd()) | start_date: ~D[2025-01-09]}, Enum.at(tasks, 1)],
        [%{id: 1, source: 1, target: 2}],
        work_time: true
      )
      |> schedule()

    # Thu 9 + 2 -> ends Sat 11 00:00 (after Friday) -> B starts Monday
    assert start(s, 2) == ~N[2025-01-13 00:00:00]
  end

  test "reports each moved task once" do
    tasks = [%{id: 10, type: :project}, Map.put(@a, :parent, 10), Map.put(@b, :parent, 10)]

    {:ok, _store, changes} =
      store(tasks, [%{id: 1, source: 1, target: 2}]) |> Scheduler.schedule()

    assert {:task_updated, %{id: 10}, _} = Enum.find(changes, &match?({_, %{id: 10}, _}, &1))
    ids = Enum.map(changes, fn {_type, task, _} -> task.id end)
    assert ids == Enum.uniq(ids)
  end
end
