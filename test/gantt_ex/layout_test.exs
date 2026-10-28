defmodule GanttEx.LayoutTest do
  use ExUnit.Case, async: true

  alias GanttEx.{Layout, Store, Timeline}

  setup do
    store =
      Store.new!(
        [
          %{id: 1, start_date: ~D[2025-01-01], duration: 2},
          %{id: 2, start_date: ~D[2025-01-04], duration: 2},
          %{id: 3, start_date: ~D[2025-01-08], duration: 1}
        ],
        [%{id: 1, source: 1, target: 2}, %{id: 2, source: 2, target: 3}]
      )

    timeline =
      Timeline.new(
        scales: [[unit: :day]],
        start_date: ~N[2025-01-01 00:00:00],
        end_date: ~N[2025-01-12 00:00:00],
        column_width: 40
      )

    %{store: store, timeline: timeline}
  end

  defp build(store, timeline, opts \\ []),
    do: Layout.build(store, Store.rows(store), timeline, opts)

  test "links whose bars did not move keep their cached path", %{store: store, timeline: timeline} do
    layout = build(store, timeline)
    {:ok, moved, _changes} = Store.update_task(store, 3, %{start_date: ~D[2025-01-09]})

    # a cached path is only reused while both bars stay where they were
    cache =
      Map.new(layout.link_cache, fn {key, {from, to, type, height, _path}} ->
        {key, {from, to, type, height, %{d: "cached-#{key}", arrow_d: "arrow-#{key}"}}}
      end)

    [first, second] = build(moved, timeline, link_cache: cache).links

    assert {first.d, first.arrow_d} == {"cached-1", "arrow-1"}
    assert second.d == hd(tl(build(moved, timeline).links)).d
    refute second.d == "cached-2"
  end
end
