defmodule GanttEx.ImportExportTest do
  use ExUnit.Case, async: true

  alias GanttEx.{Export, Import, Store}

  setup do
    store =
      Store.new!(
        [
          %{id: 1, text: "Phase \"A\"", type: :project},
          %{
            id: 2,
            text: "Work, part 1",
            parent: 1,
            start_date: ~D[2025-01-06],
            duration: 3,
            progress: 0.25
          },
          %{id: 3, text: "Review", parent: 1, start_date: ~D[2025-01-09], duration: 2},
          %{id: 4, text: "Release", start_date: ~D[2025-01-13], type: :milestone}
        ],
        [
          %{id: 1, source: 2, target: 3},
          %{id: 2, source: 3, target: 4, type: :finish_to_finish, lag: 2}
        ]
      )

    {:ok, store: store}
  end

  defp summary(store) do
    tasks =
      Enum.map(Store.tasks(store), &{&1.text, &1.type, &1.start_date, &1.end_date, &1.parent})

    links = Enum.map(Store.links(store), &{&1.source, &1.target, &1.type, &1.lag})
    {tasks, links}
  end

  test "JSON round trip", %{store: store} do
    {:ok, data} = store |> Export.to_json() |> Import.from_json()
    assert summary(Store.new!(data.tasks, data.links)) == summary(store)
  end

  test "MS Project round trip", %{store: store} do
    {:ok, data} = store |> Export.to_ms_project() |> Import.from_ms_project()
    assert summary(Store.new!(data.tasks, data.links)) == summary(store)
  end

  test "rejects XML with entity declarations" do
    bomb = """
    <?xml version="1.0"?>
    <!DOCTYPE data [<!ENTITY a "aaaaaaaaaa"><!ENTITY b "&a;&a;&a;&a;&a;&a;&a;&a;&a;&a;">]>
    <data><task id="1" start_date="06-01-2025">&b;</task></data>
    """

    assert Import.from_xml(bomb) == {:error, :invalid_xml}
    assert Import.from_ms_project(bomb) == {:error, :invalid_xml}
  end

  test "rejects documents that are not MS Project files" do
    assert Import.from_ms_project("<data/>") == {:error, :invalid_format}
  end

  test "SVG export is well formed and draws every task", %{store: store} do
    svg = Export.to_svg(store, zoom: :week, locale: "de")
    assert {:ok, %{name: "svg"}} = GanttEx.XML.parse(svg)
    assert svg =~ "Phase &quot;A&quot;"
    assert svg =~ "<polygon"
    assert length(Regex.scan(~r/class="link"/, svg)) == 2
  end

  test "SVG export respects the given rows", %{store: store} do
    rows = Store.rows(store, collapsed: MapSet.new([1]))
    svg = Export.to_svg(store, rows: rows)
    refute svg =~ "Work, part 1"
    assert svg =~ "Release"
  end
end
