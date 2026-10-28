defmodule GanttEx.FilterTest do
  use ExUnit.Case, async: true

  alias GanttEx.{CriticalPath, Filter, I18n, Store, Task}

  @labels I18n.labels("en")

  defp definitions(filters, opts \\ []), do: Filter.definitions(filters, @labels, opts)

  defp task(attrs),
    do: Task.new!(Map.merge(%{id: 1, start_date: ~D[2025-01-06], duration: 2}, attrs))

  defp matches?(filters, values, attrs, ctx \\ %{}) do
    defs = definitions(filters)
    {:ok, task} = attrs |> task() |> Store.schedule(:day)
    Filter.match?(task, defs, Filter.normalize(values, defs), ctx)
  end

  describe "definitions/3" do
    test "default to search, status, type and dates" do
      assert Enum.map(definitions(true), & &1.id) == [:search, :status, :type, :dates]
      assert Filter.defaults() == [:search, :status, :type, :dates]
    end

    test "translate the built-in filters" do
      [status, type] = Filter.definitions([:status, :type], I18n.labels("en"), critical: true)

      assert Enum.map(status.options, & &1.label) == [
               "Not started",
               "In progress",
               "Completed",
               "Overdue",
               "Critical",
               "Blocked",
               "With restrictions"
             ]

      assert Enum.map(type.options, & &1.value) == [:task, :project, :milestone]
    end

    test "built-in filters can be relabelled" do
      assert [%{kind: :status, label: "Estado"}] = definitions([%{id: :status, label: "Estado"}])
    end

    test "normalize custom options" do
      [filter] =
        definitions([
          %{
            id: "company",
            label: "Company",
            options: [
              {"None", nil},
              %{label: "Acme", value: 7, image: "/logo.png", color: "#f00", hint: ""},
              %{label: "Evil", value: 8, color: "red; background: url(x)"},
              :other
            ]
          }
        ])

      assert [none, acme, evil, other] = filter.options

      assert none == %{
               value: nil,
               key: "__none__",
               label: "None",
               image: nil,
               color: nil,
               hint: nil
             }

      assert %{key: "7", image: "/logo.png", color: "#f00", hint: nil} = acme
      # colors go into inline styles
      assert evil.color == nil
      assert %{value: :other, label: "other"} = other
    end

    test "reject unknown filters" do
      assert_raise ArgumentError, ~r/invalid filter :stauts/, fn -> definitions([:stauts]) end
      assert_raise ArgumentError, fn -> definitions([%{label: "No id"}]) end
    end
  end

  describe "normalize/2" do
    setup do
      {:ok,
       defs:
         definitions([
           :search,
           :status,
           :type,
           :dates,
           %{id: :owner, options: [{"Ana", 1}, {"Luis", 2}]}
         ])}
    end

    test "accepts the values of the host", %{defs: defs} do
      values = %{
        search: " slab ",
        status: :blocked,
        type: [:milestone, :task],
        dates: [from: ~N[2025-01-06 10:00:00], to: ~D[2025-01-10]],
        owner: 2,
        unknown: [1]
      }

      assert Filter.normalize(values, defs) == %{
               search: "slab",
               status: [:blocked],
               # in the order of the options
               type: [:task, :milestone],
               dates: %{from: ~D[2025-01-06], to: ~D[2025-01-10]},
               owner: [2]
             }

      assert Filter.normalize([search: "x"], defs) == %{search: "x"}
    end

    test "drops empty and invalid values", %{defs: defs} do
      values = %{
        "search" => "",
        "status" => ["nope"],
        "dates" => %{"from" => "06/01/2025", "to" => nil},
        "owner" => ["3"]
      }

      assert Filter.normalize(values, defs) == %{}
      assert Filter.active_count(Filter.normalize(%{"status" => ["blocked"]}, defs)) == 1
    end

    test "never creates atoms from the client", %{defs: defs} do
      assert Filter.normalize(
               %{"status" => ["no_such_status_atom_#{System.unique_integer()}"]},
               defs
             ) ==
               %{}
    end
  end

  describe "statuses" do
    test "progress" do
      assert matches?([:status], %{status: [:not_started]}, %{progress: 0})
      refute matches?([:status], %{status: [:not_started]}, %{progress: 0.1})
      assert matches?([:status], %{status: [:in_progress]}, %{progress: 0.1})
      refute matches?([:status], %{status: [:in_progress]}, %{progress: 1})
      assert matches?([:status], %{status: [:completed]}, %{progress: 1})
    end

    test "overdue: unfinished after its end or its deadline" do
      today = %{today: ~N[2025-01-08 09:00:00]}
      # ends on the 8th at 00:00 (it runs on the 6th and 7th)
      assert matches?([:status], %{status: [:overdue]}, %{progress: 0.5}, today)
      refute matches?([:status], %{status: [:overdue]}, %{progress: 1}, today)
      refute matches?([:status], %{status: [:overdue]}, %{duration: 5}, today)

      # deadlines are inclusive days
      assert matches?(
               [:status],
               %{status: [:overdue]},
               %{duration: 5, deadline: ~D[2025-01-07]},
               today
             )

      refute matches?(
               [:status],
               %{status: [:overdue]},
               %{duration: 5, deadline: ~D[2025-01-08]},
               today
             )
    end

    test "blocked and with restrictions" do
      assert matches?([:status], %{status: [:blocked]}, %{blocked: true})
      refute matches?([:status], %{status: [:blocked]}, %{restrictions: 2})
      assert matches?([:status], %{status: [:restricted]}, %{restrictions: 2})
      # several statuses: any of them
      assert matches?([:status], %{status: [:blocked, :restricted]}, %{restrictions: 1})
    end

    test "critical, from the critical path analysis" do
      store =
        Store.new!(
          [
            %{id: 1, start_date: ~D[2025-01-06], duration: 2},
            %{id: 2, start_date: ~D[2025-01-08], duration: 2},
            %{id: 3, start_date: ~D[2025-01-06], duration: 1}
          ],
          [%{id: 1, source: 1, target: 2}]
        )

      defs = definitions([:status], critical: true)
      ctx = %{analysis: CriticalPath.analyze(store)}

      assert {ids, 2} = Filter.visible(store, defs, %{status: [:critical]}, ctx)
      assert Enum.sort(ids) == [1, 2]
      # without an analysis nothing is critical
      assert {_ids, 0} = Filter.visible(store, defs, %{status: [:critical]})
    end
  end

  describe "dates" do
    test "match tasks overlapping the range, both days included" do
      range = fn from, to -> %{dates: %{from: from, to: to}} end
      # the task runs on the 6th and the 7th
      assert matches?([:dates], range.(~D[2025-01-07], nil), %{})
      refute matches?([:dates], range.(~D[2025-01-08], nil), %{})
      assert matches?([:dates], range.(nil, ~D[2025-01-06]), %{})
      refute matches?([:dates], range.(nil, ~D[2025-01-05]), %{})
      assert matches?([:dates], range.(~D[2025-01-01], ~D[2025-01-31]), %{})
      # reversed ranges match nothing
      refute matches?([:dates], range.(~D[2025-01-31], ~D[2025-01-01]), %{})
    end

    test "milestones match on their day" do
      milestone = %{type: :milestone, start_date: ~D[2025-01-10]}
      assert matches?([:dates], %{dates: %{from: ~D[2025-01-10], to: ~D[2025-01-10]}}, milestone)
      refute matches?([:dates], %{dates: %{from: ~D[2025-01-11], to: nil}}, milestone)
    end
  end

  describe "custom filters" do
    test "read task fields, meta keys and functions" do
      options = [{"A", "a"}, {"B", "b"}, {"None", nil}]

      assert matches?([%{id: :owner, options: options}], %{owner: ["a"]}, %{owner: "a"})
      assert matches?([%{id: :owner, options: options}], %{owner: ["a"]}, %{"owner" => "a"})
      refute matches?([%{id: :owner, options: options}], %{owner: ["a"]}, %{owner: "b"})
      assert matches?([%{id: :owner, options: options}], %{owner: [nil]}, %{})

      by_text = %{id: :initial, field: &String.first(&1.text), options: options}
      assert matches?([by_text], %{initial: ["b"]}, %{text: "brick"})

      assert matches?(
               [%{id: :kind, field: :type, options: [{"M", :milestone}]}],
               %{kind: [:milestone]},
               %{
                 type: :milestone
               }
             )
    end

    test "any value of a list matches, an empty list has no value" do
      options = [{"Crane", "crane"}, {"Team", "team"}, {"Nobody", nil}]
      filter = [%{id: :resources, options: options}]

      assert matches?(filter, %{resources: ["team"]}, %{resources: ["crane", "team"]})
      refute matches?(filter, %{resources: ["team"]}, %{resources: ["crane"]})
      assert matches?(filter, %{resources: [nil]}, %{resources: []})

      tags = [%{id: :tags, options: options}]
      assert matches?(tags, %{tags: [nil]}, %{tags: []})
      assert matches?(tags, %{tags: ["crane"]}, %{tags: ["crane"]})
    end

    test "values from the client are matched by key" do
      [filter] = definitions([%{id: :n, options: [{"One", 1}, {"Two", 2}]}])
      assert Filter.normalize(%{"n" => ["2", "1"]}, [filter]) == %{n: [1, 2]}
    end
  end

  describe "search" do
    test "is case and accent insensitive" do
      assert matches?([:search], %{search: "CAÑERÍA"}, %{text: "Instalación de cañerías"})
      assert matches?([:search], %{search: "instalacion"}, %{text: "INSTALACIÓN"})
      refute matches?([:search], %{search: "muro"}, %{text: "Losa"})
    end

    test "uses the index when given, and ignores stale entries" do
      defs = definitions([:search])
      task = Task.new!(id: 1, text: "Renamed")

      assert Filter.match?(task, defs, %{search: "old"}, %{index: %{1 => {"Renamed", "old text"}}})

      refute Filter.match?(task, defs, %{search: "old"}, %{
               index: %{1 => {"Old text", "old text"}}
             })
    end

    test "the index reuses the texts that did not change" do
      store =
        Store.new!([
          %{id: 1, text: "A", start_date: ~D[2025-01-01]},
          %{id: 2, text: "B", start_date: ~D[2025-01-01]}
        ])

      index = Filter.search_index(store)
      {:ok, store, _} = Store.update_task(store, 2, %{text: "Bé"})

      assert %{1 => {"A", "a"}, 2 => {"Bé", "be"}} = Filter.search_index(store, index)
    end
  end

  describe "visible/4" do
    test "includes the ancestors of the matching tasks, once" do
      tasks =
        [%{id: :root, type: :project}] ++
          for(i <- 1..50, do: %{id: i, parent: :root, text: "T#{i}", start_date: ~D[2025-01-01]}) ++
          [%{id: :deep, parent: 7, text: "Deep", start_date: ~D[2025-01-01]}]

      store = Store.new!(Enum.map(tasks, &Map.put_new(&1, :start_date, ~D[2025-01-01])))
      defs = definitions([:search])

      assert {ids, 1} = Filter.visible(store, defs, %{search: "deep"})
      assert MapSet.equal?(ids, MapSet.new([:root, 7, :deep]))
      # T1 and T10 to T19, under the same root
      assert {ids, 11} = Filter.visible(store, defs, %{search: "t1"})
      assert MapSet.size(ids) == 12
    end

    test "combines with the filter function of the chart" do
      store =
        Store.new!([
          %{id: 1, text: "A", start_date: ~D[2025-01-01]},
          %{id: 2, text: "AB", start_date: ~D[2025-01-01]}
        ])

      defs = definitions([:search])

      assert {ids, 1} = Filter.visible(store, defs, %{search: "a"}, %{filter: &(&1.id == 2)})
      assert MapSet.to_list(ids) == [2]
      assert {ids, 1} = Filter.visible(store, defs, %{}, %{filter: &(&1.id == 2)})
      assert MapSet.to_list(ids) == [2]
      assert {nil, 2} = Filter.visible(store, defs, %{})
    end

    test "runs in linear time on large plans" do
      # a real plan: 7,000 tasks under one summary task
      tasks =
        [%{id: 1, text: "Plan", type: :project, start_date: ~D[2025-01-01]}] ++
          for i <- 1..7000 do
            %{
              id: i + 1,
              parent: 1,
              text: "Hormigón #{i}",
              start_date: Date.add(~D[2025-01-01], rem(i, 90)),
              blocked: rem(i, 3) == 0
            }
          end

      store = Store.new!(tasks)
      defs = definitions([:search, :status])
      ctx = %{index: Filter.search_index(store), wbs: Store.wbs_codes(store)}
      values = %{search: "hormigon 1", status: [:blocked]}

      {micros, {ids, matched}} = :timer.tc(fn -> Filter.visible(store, defs, values, ctx) end)

      expected = Enum.count(1..7000, &(String.starts_with?("#{&1}", "1") and rem(&1, 3) == 0))
      assert matched == expected
      assert MapSet.size(ids) == expected + 1
      assert micros < 500_000
    end
  end
end
