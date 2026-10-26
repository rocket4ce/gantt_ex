defmodule GanttEx.Layout do
  @moduledoc """
  Computes the geometry of the chart: one bar per visible row and one path per
  visible link.

  Tasks rendered with `render: :split` draw their children as *segments* on
  their own row (and links reach the segments while the branch is collapsed),
  and tasks with `rollup: true` also appear as *rollups* on the rows of
  their ancestor projects.

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
          progress: float(),
          baseline: %{x: float(), y: float(), width: float(), milestone: boolean()} | nil,
          uid: String.t(),
          segment: boolean()
        }

  @typedoc "A task shown on the row of an ancestor project."
  @type rollup :: %{
          uid: String.t(),
          task: Task.t(),
          row: non_neg_integer(),
          kind: Task.type(),
          x: float(),
          y: float(),
          width: float()
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
          segments: [bar()],
          rollups: [rollup()],
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
    * `:baselines` - make room below the bars for the baselines
      (`:planned_start` / `:planned_end`). Defaults to `false`.
  """
  @spec build(Store.t(), [Store.row()], Timeline.t(), keyword()) :: t()
  def build(%Store{} = store, rows, %Timeline{} = timeline, opts \\ []) do
    row_height = Keyword.get(opts, :row_height, 36)
    bar_height = Keyword.get(opts, :bar_height, row_height - 12)
    min_width = Keyword.get(opts, :min_bar_width, 6)
    baselines = Keyword.get(opts, :baselines, false)

    build_bar = fn row -> bar(row, timeline, row_height, bar_height, min_width, baselines) end

    bars =
      for row <- rows, row.task.render != :split, do: build_bar.(row)

    segments =
      for row <- rows,
          row.task.render == :split,
          child <- Store.children(store, row.task.id),
          do: %{
            build_bar.(%{row | task: child, key: Store.key(child.id)})
            | uid: "split-" <> Store.key(child.id),
              segment: true
          }

    # a task shown several times (grouping) is linked from its first bar
    bar_index =
      segments
      |> Map.new(&{&1.key, &1})
      |> Map.merge(bars |> Enum.reverse() |> Map.new(&{&1.key, &1}))

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
      segments: segments,
      rollups: rollups(store, rows, timeline, row_height),
      bar_index: bar_index,
      links: links,
      width: Timeline.width(timeline),
      height: length(rows) * row_height
    }
  end

  @baseline_height 5

  defp bar(%{task: task} = row, timeline, row_height, bar_height, min_width, baselines) do
    room = if baselines, do: @baseline_height + 2, else: 0
    y = row.index * row_height + (row_height - bar_height - room) / 2
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
      progress: task.progress,
      baseline: baselines && baseline(task, timeline, y + bar_height + 2),
      uid: row[:uid] || row.key,
      segment: false,
      group: row[:group] || false
    }
  end

  defp rollups(store, rows, timeline, row_height) do
    for row <- rows,
        row.task.type == :project and row.has_children,
        id <- Store.descendant_ids(store, row.task.id),
        task = Store.get_task(store, id),
        task.rollup do
      x = Timeline.x(timeline, task.start_date)
      width = if task.type == :milestone, do: 0, else: Timeline.x(timeline, task.end_date) - x

      %{
        uid: "rollup-#{row.key}-#{Store.key(id)}",
        task: task,
        row: row.index,
        kind: task.type,
        x: x,
        y: row.index * row_height + row_height / 2,
        width: width
      }
    end
  end

  defp baseline(
         %{planned_start: %NaiveDateTime{} = start, planned_end: %NaiveDateTime{} = finish},
         timeline,
         y
       ) do
    x = Timeline.x(timeline, start)
    width = Timeline.x(timeline, finish) - x

    # a zero-length baseline (a milestone) is drawn as a small diamond
    if width < 1,
      do: %{x: x, y: y, width: 0, milestone: true},
      else: %{x: x, y: y, width: width, milestone: false}
  end

  defp baseline(_task, _timeline, _y), do: nil

  defp row_box(bar, row_height), do: %{x: bar.x, width: bar.width, y: bar.row * row_height}
end
