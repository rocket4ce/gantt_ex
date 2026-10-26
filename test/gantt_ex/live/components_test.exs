defmodule GanttEx.Live.ComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias GanttEx.Live.{Columns, Components}
  alias GanttEx.{I18n, Store}

  defp ctx(overrides \\ %{}) do
    Map.merge(
      %{
        id: "gantt",
        myself: nil,
        labels: I18n.labels("en"),
        format: I18n.formatter("en"),
        locale: "en",
        unit: :day,
        date_pattern: :date,
        readonly: false,
        inline_edit: true,
        tooltips: true,
        lightbox: true
      },
      overrides
    )
  end

  test "grid rows show WBS codes" do
    store =
      Store.new!([
        %{id: 1, text: "A", start_date: ~D[2025-01-01]},
        %{id: 2, parent: 1, text: "B", start_date: ~D[2025-01-01]}
      ])

    [_parent, child] = Store.rows(store)
    columns = Columns.build([%{field: :wbs}, %{field: :text}], I18n.labels("es"))

    html =
      render_component(&Components.grid_row/1,
        ctx: ctx(),
        row: Map.put(child, :selected, false),
        columns: columns
      )

    assert html =~ ~s(<span class="gx-truncate gx-wbs">1.1</span>)
    assert hd(columns).label == "EDT"
  end
end
