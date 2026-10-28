defmodule GanttEx.Live.ColumnsTest do
  use ExUnit.Case, async: true

  alias GanttEx.I18n
  alias GanttEx.Live.Columns

  @labels I18n.labels("en")
  @slots [
    %{field: :wbs, hidden: true},
    %{field: :text},
    %{field: :start_date},
    %{field: :cost, hidden: true, label: "Cost"},
    %{field: :add}
  ]

  defp visible(opts), do: @slots |> Columns.build(@labels, opts) |> Enum.map(& &1.key)

  test "hidden slots are available but not built" do
    assert visible([]) == ["text", "start_date", "add"]

    assert @slots |> Columns.available(@labels) |> Enum.map(&{&1.key, &1.visible, &1.title}) == [
             {"wbs", false, "WBS"},
             {"text", true, "Task name"},
             {"start_date", true, "Start time"},
             {"cost", false, "Cost"},
             {"add", true, "Add task"}
           ]
  end

  test "the tree column is always shown" do
    assert visible(layout: %{hidden: ["text"]}) == ["text", "start_date", "add"]

    assert [%{tree: true, key: "text"} | _] =
             Columns.build([%{field: :text, hidden: true}], @labels)
  end

  test "layouts order, hide and resize the columns" do
    layout = %{order: ["cost", "add", "text"], hidden: ["add"], widths: %{"cost" => 140}}

    assert visible(layout: layout) == ["cost", "text", "start_date"]
    assert [%{key: "cost", width: 140} | _] = Columns.build(@slots, @labels, layout: layout)
    # explicit widths win over the layout
    assert [%{width: 90} | _] =
             Columns.build(@slots, @labels, layout: layout, widths: %{"cost" => 90})
  end

  test "readonly charts drop the add column" do
    assert visible(readonly: true) == ["text", "start_date"]
  end

  test "the reported layout lists every column" do
    state = Columns.normalize_layout(%{order: ["text"], hidden: ["start_date"], grid_width: 99})

    assert @slots |> Columns.available(@labels, layout: state) |> Columns.layout(state) == %{
             order: ["text", "wbs", "start_date", "cost", "add"],
             hidden: ["wbs", "start_date", "cost"],
             widths: %{},
             grid_width: 120
           }
  end

  test "layouts accept keyword lists and ignore garbage" do
    assert Columns.normalize_layout(
             order: [:text],
             hidden: "wbs",
             widths: [{"x", 10}],
             grid_width: "1"
           ) ==
             %{order: ["text"], hidden: nil, widths: %{"x" => 32}, grid_width: nil}
  end
end
