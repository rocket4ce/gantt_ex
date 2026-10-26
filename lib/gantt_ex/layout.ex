defmodule GanttEx.Layout do
  @moduledoc """
  Computes the geometry of the chart: one bar per visible row and one path per
  visible link.

  The layout is pure data, so it can be tested without rendering anything:

      iex> store = GanttEx.Store.new!(
      ...>   [
      ...>     %{id: 1, text: "A", start_date: ~D[2025-01-01], duration: 2},
      ...>     %{id: 2, text: "B", start_date: ~D[2025-01-04], type: :milestone}
      ...>   ],
      ...>   [%{id: 1, source: 1, target: 2}]
      ...> )
      iex> timeline = GanttEx.Timeline.new(scales: [[unit: :day]], start_date: ~N[2025-01-01 00:00:00], end_date: ~N[2025-01-10 00:00:00], column_width: 40)
      iex> layout = GanttEx.Layout.build(store, GanttEx.Store.rows(store), timeline, row_height: 36, bar_height: 24)
      iex> [a, b] = layout.bars
      iex> {a.x, a.width, a.y, a.kind}
      {0.0, 80.0, 6.0, :task}
      iex> {b.x, b.width, b.kind}
      {108.0, 24, :milestone}
      iex> [link] = layout.links
      iex> link.d
      "M80 18L92 18L92 54L102 54"
      iex> layout.height
      72
  """

  alias GanttEx.{LinkPath, Store, Task, Timeline}

  @typedoc "A positioned task bar."
  @type bar :: %{
          key: Store.key(),
          task: Task.t(),
          row: non_neg_integer(),
          kind: Task.type(),
          x: float(),
          y: float(),
          width: float(),
          height: number(),
          progress: float()
        }

  @typedoc "A positioned link."
  @type link_path :: %{
          key: Store.key(),
          link: GanttEx.Link.t(),
          source_key: Store.key(),
          target_key: Store.key(),
          source_row: non_neg_integer(),
          target_row: non_neg_integer(),
          d: String.t(),
          arrow_d: String.t()
        }

  @type t :: %{
          bars: [bar()],
          bar_index: %{Store.key() => bar()},
          links: [link_path()],
          width: non_neg_integer(),
          height: non_neg_integer()
        }

  @doc """
  Builds the layout for the given rows (see `GanttEx.Store.rows/2`).

  ## Options

    * `:row_height` - defaults to `36`.
    * `:bar_height` - defaults to `row_height - 12`.
    * `:min_bar_width` - defaults to `6`, so very short tasks stay visible.
  """
  @spec build(Store.t(), [Store.row()], Timeline.t(), keyword()) :: t()
  def build(%Store{} = store, rows, %Timeline{} = timeline, opts \\ []) do
    row_height = Keyword.get(opts, :row_height, 36)
    bar_height = Keyword.get(opts, :bar_height, row_height - 12)
    min_width = Keyword.get(opts, :min_bar_width, 6)

    bars =
      Enum.map(rows, fn row ->
        bar(row, timeline, row_height, bar_height, min_width)
      end)

    bar_index = Map.new(bars, &{&1.key, &1})

    links =
      for link <- Store.links(store),
          source = Map.get(bar_index, Store.key(link.source)),
          target = Map.get(bar_index, Store.key(link.target)) do
        path =
          LinkPath.route(row_box(source, row_height), row_box(target, row_height), link.type,
            row_height: row_height
          )

        %{
          key: Store.key(link.id),
          link: link,
          source_key: source.key,
          target_key: target.key,
          source_row: source.row,
          target_row: target.row,
          d: path.d,
          arrow_d: path.arrow_d
        }
      end

    %{
      bars: bars,
      bar_index: bar_index,
      links: links,
      width: Timeline.width(timeline),
      height: length(rows) * row_height
    }
  end

  defp bar(%{task: task} = row, timeline, row_height, bar_height, min_width) do
    y = row.index * row_height + (row_height - bar_height) / 2
    x = Timeline.x(timeline, task.start_date)

    {x, width} =
      if task.type == :milestone do
        {x - bar_height / 2, bar_height}
      else
        {x, max(Timeline.x(timeline, task.end_date) - x, min_width)}
      end

    %{
      key: row.key,
      task: task,
      row: row.index,
      kind: task.type,
      x: x,
      y: y,
      width: width,
      height: bar_height,
      progress: task.progress
    }
  end

  defp row_box(bar, row_height), do: %{x: bar.x, width: bar.width, y: bar.row * row_height}
end
