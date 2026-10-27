defmodule GanttEx.StoreTest do
  use ExUnit.Case, async: true

  alias GanttEx.Store

  test "new/3 keeps the links add_link/2 would accept one by one" do
    tasks = for id <- 1..4, do: %{id: id, start_date: ~D[2025-01-06]}

    links = [
      %{id: "a", source: 1, target: 2},
      %{id: "b", source: 2, target: 3},
      %{id: "duplicate", source: 1, target: 2},
      %{id: "ss", source: 1, target: 2, type: :start_to_start},
      %{id: "cycle", source: 3, target: 1},
      %{id: "self", source: 4, target: 4},
      %{id: "missing", source: 4, target: 99},
      %{id: "c", source: 3, target: 4}
    ]

    one_by_one =
      Enum.reduce(links, Store.new!(tasks), fn link, store ->
        case Store.add_link(store, link) do
          {:ok, store, _changes} -> store
          {:error, _reason} -> store
        end
      end)

    store = Store.new!(tasks, links)
    assert Enum.map(Store.links(store), & &1.id) == ["a", "b", "ss", "c"]
    assert store == one_by_one
  end
end
