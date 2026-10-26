defmodule GanttEx.Export do
  @moduledoc """
  Exports a `GanttEx.Store` to common formats.

  | Format              | Function           | File            |
  | ------------------- | ------------------ | --------------- |
  | DHTMLX JSON         | `to_json/2`        | `.json`         |
  | CSV (Excel)         | `to_csv/2`         | `.csv`          |
  | iCalendar           | `to_ical/2`        | `.ics`          |
  | MS Project (MSPDI)  | `to_ms_project/2`  | `.xml`          |
  | SVG image           | `to_svg/2`         | `.svg`          |

  PNG images are the SVG rasterized by the browser (the toolbar offers both),
  and PDF output uses the print stylesheet: the toolbar "Print" button opens
  the print dialog, where "Save as PDF" is available.

  `GanttEx.Live.Gantt` uses `export/3` for its toolbar export menu.

      iex> store = GanttEx.Store.new!([%{id: 1, text: "Kickoff", start_date: ~D[2025-01-06], duration: 1}])
      iex> {filename, mime, content} = GanttEx.Export.export(store, :csv, filename: "plan")
      iex> {filename, mime}
      {"plan.csv", "text/csv"}
      iex> content |> String.split("\\r\\n") |> Enum.at(1)
      "1,Kickoff,task,2025-01-06 00:00,2025-01-07 00:00,1,0,,"
  """

  alias GanttEx.{Dates, I18n, Layout, Link, LinkPath, Store, Task, TaskForm, Timeline, Zoom}

  @formats [:json, :csv, :ical, :ms_project, :svg]

  @doc """
  Returns the supported export formats.

      iex> GanttEx.Export.formats()
      [:json, :csv, :ical, :ms_project, :svg]
  """
  @spec formats() :: [atom()]
  def formats, do: @formats

  @doc """
  Exports to `format`, returning `{filename, mime_type, content}`.

  ## Options

    * `:filename` - base file name, without extension. Defaults to `"gantt"`.
    * any option accepted by the format function.
  """
  @spec export(Store.t(), atom(), keyword()) :: {String.t(), String.t(), String.t()}
  def export(%Store{} = store, format, opts \\ []) when format in @formats do
    base = Keyword.get(opts, :filename, "gantt")

    case format do
      :json -> {base <> ".json", "application/json", to_json(store, opts)}
      :csv -> {base <> ".csv", "text/csv", to_csv(store, opts)}
      :ical -> {base <> ".ics", "text/calendar", to_ical(store, opts)}
      :ms_project -> {base <> ".xml", "application/xml", to_ms_project(store, opts)}
      :svg -> {base <> ".svg", "image/svg+xml", to_svg(store, opts)}
    end
  end

  # -- JSON --------------------------------------------------------------------

  @doc """
  Exports to the DHTMLX Gantt JSON format (`{"data": [...], "links": [...]}`),
  which `GanttEx.Import.from_json/1` and DHTMLX Gantt can read back.

      iex> store = GanttEx.Store.new!([%{id: 1, text: "A", start_date: ~D[2025-01-06], duration: 2}])
      iex> store |> GanttEx.Export.to_json() |> JSON.decode!() |> Map.fetch!("data")
      [%{"id" => 1, "text" => "A", "start_date" => "2025-01-06 00:00", "end_date" => "2025-01-08 00:00", "duration" => 2, "progress" => 0.0, "parent" => 0, "type" => "task", "open" => true}]
  """
  @spec to_json(Store.t(), keyword()) :: String.t()
  def to_json(%Store{} = store, _opts \\ []) do
    data =
      Enum.map(Store.tasks(store), fn task ->
        %{
          "id" => task.id,
          "text" => task.text,
          "start_date" => format_date(task.start_date),
          "end_date" => format_date(task.end_date),
          "duration" => task.duration,
          "progress" => task.progress,
          "parent" => task.parent || 0,
          "type" => Atom.to_string(task.type),
          "open" => task.open
        }
        |> Map.merge(json_meta(task.meta))
      end)

    links =
      Enum.map(Store.links(store), fn link ->
        %{
          "id" => link.id,
          "source" => link.source,
          "target" => link.target,
          "type" => Link.code(link.type),
          "lag" => link.lag
        }
      end)

    JSON.encode!(%{"data" => data, "links" => links})
  end

  defp json_meta(meta) do
    for {key, value} <- meta,
        is_binary(key) or is_atom(key),
        json_value?(value),
        into: %{},
        do: {to_string(key), value}
  end

  defp json_value?(value) when is_binary(value) or is_number(value) or is_boolean(value), do: true
  defp json_value?(nil), do: true
  defp json_value?(_value), do: false

  # -- CSV ---------------------------------------------------------------------

  @doc """
  Exports tasks to CSV (RFC 4180, `\\r\\n` line endings), ready for Excel.

  The last column lists the predecessors of each task (`source_id` or
  `source_id:TYPE` for non finish-to-start links).

  ## Options

    * `:headers` - list of the 9 column titles. Defaults to English titles.

  ## Examples

      iex> store = GanttEx.Store.new!(
      ...>   [%{id: 1, text: "Plan, review", start_date: ~D[2025-01-06]}, %{id: 2, text: ~s(Say "hi"), start_date: ~D[2025-01-07]}],
      ...>   [%{id: 1, source: 1, target: 2, type: :start_to_start}]
      ...> )
      iex> store |> GanttEx.Export.to_csv() |> String.split("\\r\\n")
      [
        "ID,Name,Type,Start,End,Duration,Progress (%),Parent,Predecessors",
        ~s(1,"Plan, review",task,2025-01-06 00:00,2025-01-07 00:00,1,0,,),
        ~s(2,"Say ""hi\""",task,2025-01-07 00:00,2025-01-08 00:00,1,0,,1:SS),
        ""
      ]
  """
  @spec to_csv(Store.t(), keyword()) :: String.t()
  def to_csv(%Store{} = store, opts \\ []) do
    headers =
      Keyword.get(opts, :headers, [
        "ID",
        "Name",
        "Type",
        "Start",
        "End",
        "Duration",
        "Progress (%)",
        "Parent",
        "Predecessors"
      ])

    predecessors = Enum.group_by(Store.links(store), & &1.target)

    rows =
      Enum.map(Store.tasks(store), fn task ->
        [
          Store.key(task.id),
          task.text,
          Atom.to_string(task.type),
          format_date(task.start_date),
          format_date(task.end_date),
          to_string(task.duration),
          task.progress |> Kernel.*(100) |> round() |> Integer.to_string(),
          if(task.parent, do: Store.key(task.parent), else: ""),
          predecessors |> Map.get(task.id, []) |> Enum.map_join(" ", &predecessor/1)
        ]
      end)

    Enum.map_join([headers | rows], "", fn row ->
      Enum.map_join(row, ",", &csv_field/1) <> "\r\n"
    end)
  end

  defp predecessor(%Link{source: source, type: :finish_to_start}), do: Store.key(source)

  defp predecessor(%Link{source: source, type: type}) do
    abbreviation =
      case type do
        :start_to_start -> "SS"
        :finish_to_finish -> "FF"
        :start_to_finish -> "SF"
      end

    Store.key(source) <> ":" <> abbreviation
  end

  defp csv_field(value) do
    if String.contains?(value, [",", "\"", "\n", "\r"]),
      do: "\"" <> String.replace(value, "\"", "\"\"") <> "\"",
      else: value
  end

  # -- iCalendar ---------------------------------------------------------------

  @doc """
  Exports tasks as iCalendar (RFC 5545) events. Tasks that start and end at
  midnight become all-day events; times are exported as floating local time.

  ## Options

    * `:name` - calendar name. Defaults to `"Gantt"`.
    * `:now` - the `DTSTAMP` value (`DateTime`). Defaults to the current time.

  ## Examples

      iex> store = GanttEx.Store.new!([%{id: 1, text: "Launch; v1", start_date: ~D[2025-01-06], duration: 2}])
      iex> ics = GanttEx.Export.to_ical(store, now: ~U[2025-01-01 12:00:00Z])
      iex> ics |> String.split("\\r\\n") |> Enum.filter(&String.starts_with?(&1, ["DTSTART", "DTEND", "SUMMARY", "UID"]))
      ["UID:1@gantt_ex", "DTSTART;VALUE=DATE:20250106", "DTEND;VALUE=DATE:20250108", "SUMMARY:Launch\\\\; v1"]
  """
  @spec to_ical(Store.t(), keyword()) :: String.t()
  def to_ical(%Store{} = store, opts \\ []) do
    stamp =
      opts |> Keyword.get_lazy(:now, &DateTime.utc_now/0) |> Calendar.strftime("%Y%m%dT%H%M%SZ")

    events =
      Enum.flat_map(Store.tasks(store), fn task ->
        [
          "BEGIN:VEVENT",
          "UID:#{ical_text(Store.key(task.id))}@gantt_ex",
          "DTSTAMP:#{stamp}",
          ical_date("DTSTART", task.start_date, all_day?(task)),
          ical_date("DTEND", task.end_date, all_day?(task)),
          "SUMMARY:#{ical_text(task.text)}",
          "END:VEVENT"
        ]
      end)

    ([
       "BEGIN:VCALENDAR",
       "VERSION:2.0",
       "PRODID:-//GanttEx//GanttEx//EN",
       "CALSCALE:GREGORIAN",
       "X-WR-CALNAME:#{ical_text(Keyword.get(opts, :name, "Gantt"))}"
     ] ++ events ++ ["END:VCALENDAR"])
    |> Enum.map_join("", &(fold(&1) <> "\r\n"))
  end

  defp all_day?(%Task{start_date: start, end_date: finish}) do
    Dates.floor(start, :day) == start and Dates.floor(finish, :day) == finish
  end

  defp ical_date(name, date, true), do: "#{name};VALUE=DATE:#{Calendar.strftime(date, "%Y%m%d")}"
  defp ical_date(name, date, false), do: "#{name}:#{Calendar.strftime(date, "%Y%m%dT%H%M%S")}"

  defp ical_text(text) do
    text
    |> String.replace("\\", "\\\\")
    |> String.replace(";", "\\;")
    |> String.replace(",", "\\,")
    |> String.replace(~r/\r?\n/, "\\n")
  end

  # Lines longer than 75 octets are folded with CRLF + space.
  defp fold(line) when byte_size(line) <= 75, do: line

  defp fold(line) do
    {head, rest} = split_utf8(line, 75)
    head <> "\r\n " <> fold(rest)
  end

  defp split_utf8(string, bytes) do
    if String.valid?(binary_part(string, 0, bytes)) do
      {binary_part(string, 0, bytes), binary_part(string, bytes, byte_size(string) - bytes)}
    else
      split_utf8(string, bytes - 1)
    end
  end

  # -- MS Project --------------------------------------------------------------

  @doc """
  Exports to Microsoft Project XML (MSPDI), which MS Project, ProjectLibre and
  GanttProject can import. Durations are elapsed time; lags assume 8-hour days.

  ## Options

    * `:name` - project name. Defaults to `"Gantt"`.

  ## Examples

      iex> store = GanttEx.Store.new!(
      ...>   [%{id: "a", text: "R&D", start_date: ~D[2025-01-06], duration: 2}, %{id: "b", text: "Ship", start_date: ~D[2025-01-08], type: :milestone}],
      ...>   [%{id: 1, source: "a", target: "b"}]
      ...> )
      iex> xml = GanttEx.Export.to_ms_project(store)
      iex> xml =~ "<Name>R&amp;D</Name>" and xml =~ "<PredecessorUID>1</PredecessorUID><Type>1</Type>"
      true
  """
  @spec to_ms_project(Store.t(), keyword()) :: String.t()
  def to_ms_project(%Store{} = store, opts \\ []) do
    tasks = Store.tasks(store)
    uids = tasks |> Enum.with_index(1) |> Map.new(fn {task, uid} -> {task.id, uid} end)
    predecessors = Enum.group_by(Store.links(store), & &1.target)
    outline = Store.wbs_codes(store)

    task_xml =
      Enum.map_join(tasks, "", fn task ->
        hours = max(NaiveDateTime.diff(task.end_date, task.start_date, :second), 0) / 3600

        links =
          predecessors
          |> Map.get(task.id, [])
          |> Enum.map_join("", fn link ->
            "<PredecessorLink><PredecessorUID>#{uids[link.source]}</PredecessorUID>" <>
              "<Type>#{ms_link_type(link.type)}</Type><LinkLag>#{link.lag * 4800}</LinkLag>" <>
              "<LagFormat>7</LagFormat></PredecessorLink>"
          end)

        "<Task><UID>#{uids[task.id]}</UID><ID>#{uids[task.id]}</ID>" <>
          "<Name>#{xml_escape(task.text)}</Name>" <>
          "<OutlineNumber>#{outline[task.id]}</OutlineNumber>" <>
          "<OutlineLevel>#{Store.level(store, task.id) + 1}</OutlineLevel>" <>
          "<Start>#{xml_date(task.start_date)}</Start><Finish>#{xml_date(task.end_date)}</Finish>" <>
          "<Duration>PT#{trunc(hours)}H#{round((hours - trunc(hours)) * 60)}M0S</Duration>" <>
          "<DurationFormat>39</DurationFormat>" <>
          "<Milestone>#{bit(task.type == :milestone)}</Milestone>" <>
          "<Summary>#{bit(Store.has_children?(store, task.id))}</Summary>" <>
          "<PercentComplete>#{round(task.progress * 100)}</PercentComplete>" <>
          links <> "</Task>"
      end)

    ~s(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n) <>
      ~s(<Project xmlns="http://schemas.microsoft.com/project">) <>
      "<Name>#{xml_escape(Keyword.get(opts, :name, "Gantt"))}</Name>" <>
      "<Tasks>#{task_xml}</Tasks></Project>\n"
  end

  # -- SVG ---------------------------------------------------------------------

  @svg_colors %{
    task: {"#6366f1", "#4338ca"},
    project: {"#0d9488", "#115e59"},
    milestone: {"#f59e0b", "#d97706"}
  }

  @doc """
  Renders the chart as a standalone SVG image (grid, time scale, bars and
  dependencies), using the same layout rules as the live chart.

  ## Options

    * `:locale` - language of the labels and dates. Defaults to `"en"`.
    * `:zoom` - zoom level name used when no `:timeline` is given. Defaults to `:day`.
    * `:rows` - the rows to draw (see `GanttEx.Store.rows/2`), so collapsed
      branches or filters are respected. Defaults to all tasks.
    * `:timeline` - a `GanttEx.Timeline`. Defaults to one that fits the tasks.
    * `:row_height`, `:bar_height` - sizes in pixels.
    * `:grid` - draw the task grid. Defaults to `true`.

  ## Examples

      iex> store = GanttEx.Store.new!(
      ...>   [%{id: 1, text: "Design <v2>", start_date: ~D[2025-01-06], duration: 3}, %{id: 2, text: "Ship", start_date: ~D[2025-01-10], type: :milestone}],
      ...>   [%{id: 1, source: 1, target: 2}]
      ...> )
      iex> svg = GanttEx.Export.to_svg(store, locale: "es")
      iex> String.starts_with?(svg, "<svg")
      true
      iex> svg =~ "Design &lt;v2&gt;" and svg =~ "enero 2025" and svg =~ ~s(class="link")
      true
  """
  @spec to_svg(Store.t(), keyword()) :: String.t()
  def to_svg(%Store{} = store, opts \\ []) do
    locale = Keyword.get(opts, :locale, "en")
    labels = I18n.labels(locale)
    format = I18n.formatter(locale)
    unit = Store.duration_unit(store)
    rows = Keyword.get_lazy(opts, :rows, fn -> Store.rows(store) end)
    timeline = Keyword.get_lazy(opts, :timeline, fn -> svg_timeline(store, opts) end)
    row_height = Keyword.get(opts, :row_height, 32)
    bar_height = Keyword.get(opts, :bar_height, row_height - 12)
    layout = Layout.build(store, rows, timeline, row_height: row_height, bar_height: bar_height)

    columns =
      if Keyword.get(opts, :grid, true),
        do: [
          {labels.task_name, 240, :text},
          {labels.start_time, 96, :start},
          {labels.duration, 72, :duration}
        ],
        else: []

    grid_width = columns |> Enum.map(&elem(&1, 1)) |> Enum.sum()
    scale_height = 28 * length(timeline.scales)
    width = grid_width + layout.width
    height = scale_height + max(layout.height, row_height)
    date_pattern = if TaskForm.date_input_type(unit) == "date", do: :date, else: :datetime

    body = [
      ~s(<rect width="#{width}" height="#{height}" fill="#ffffff"/>),
      ~s(<rect width="#{width}" height="#{scale_height}" fill="#f8fafc"/>),
      svg_weekends(timeline, grid_width, scale_height, height),
      svg_grid_lines(timeline, rows, grid_width, scale_height, row_height, width, height),
      svg_scale(timeline, format, grid_width),
      svg_grid(columns, rows, format, date_pattern, scale_height, row_height),
      ~s|<g transform="translate(#{grid_width} #{scale_height})">|,
      svg_links(layout.links),
      svg_bars(layout.bars),
      "</g>"
    ]

    [
      ~s(<svg xmlns="http://www.w3.org/2000/svg" width="#{width}" height="#{height}" ),
      ~s(viewBox="0 0 #{width} #{height}" font-family="system-ui, -apple-system, 'Segoe UI', Roboto, 'Hiragino Sans', 'Noto Sans JP', Helvetica, Arial, sans-serif" font-size="12">),
      "<style>.muted{fill:#64748b}.head{fill:#475569;font-weight:600;font-size:11px}.bar-text{fill:#ffffff;font-weight:500}.side-text{fill:#0f172a}.link{fill:none;stroke:#94a3b8;stroke-width:1.5}.arrow{fill:#94a3b8}</style>",
      body,
      "</svg>\n"
    ]
    |> IO.iodata_to_binary()
  end

  defp svg_timeline(store, opts) do
    level = Zoom.find(Zoom.default_levels(), Keyword.get(opts, :zoom, :day))
    {start, finish} = Timeline.fit(Store.date_range(store), level.scales)

    Timeline.new(
      scales: level.scales,
      start_date: start,
      end_date: finish,
      column_width: level.column_width
    )
  end

  defp svg_weekends(timeline, offset, top, height) do
    if List.last(timeline.scales).unit in [:hour, :day] do
      for column <- Timeline.columns(timeline), Date.day_of_week(column.start) in [6, 7] do
        ~s(<rect x="#{n(offset + column.x)}" y="#{top}" width="#{n(column.width)}" height="#{height - top}" fill="#f1f5f9"/>)
      end
    else
      []
    end
  end

  defp svg_grid_lines(timeline, rows, grid_width, top, row_height, width, height) do
    columns =
      for column <- Timeline.columns(timeline) do
        x = n(grid_width + column.x + column.width)
        ~s(<line x1="#{x}" y1="#{top}" x2="#{x}" y2="#{height}" stroke="#eef2f7"/>)
      end

    lines =
      for index <- 1..max(length(rows), 1)//1 do
        y = top + index * row_height
        ~s(<line x1="0" y1="#{y}" x2="#{width}" y2="#{y}" stroke="#eef2f7"/>)
      end

    [
      columns,
      lines,
      ~s(<line x1="0" y1="#{top}" x2="#{width}" y2="#{top}" stroke="#e2e8f0"/>),
      ~s(<line x1="#{grid_width}" y1="0" x2="#{grid_width}" y2="#{height}" stroke="#e2e8f0"/>)
    ]
  end

  defp svg_scale(timeline, format, offset) do
    for {scale, index} <- Enum.with_index(timeline.scales),
        cell <- Timeline.cells(timeline, scale, format) do
      y = index * 28
      x = offset + cell.x
      first_row? = index == 0 and length(timeline.scales) > 1
      text_x = if first_row?, do: x + 8, else: x + cell.width / 2
      anchor = if first_row?, do: "start", else: "middle"

      [
        ~s(<line x1="#{n(x + cell.width)}" y1="#{y}" x2="#{n(x + cell.width)}" y2="#{y + 28}" stroke="#e2e8f0"/>),
        ~s(<text x="#{n(text_x)}" y="#{y + 18}" text-anchor="#{anchor}" class="#{if first_row?, do: "head", else: "muted"}">),
        xml_escape(truncate(cell.label, cell.width - 8)),
        "</text>"
      ]
    end
  end

  defp svg_grid([], _rows, _format, _pattern, _top, _row_height), do: []

  defp svg_grid(columns, rows, format, pattern, top, row_height) do
    {headers, _x} =
      Enum.map_reduce(columns, 0, fn {label, width, _field}, x ->
        {[~s(<text x="#{x + 10}" y="#{top - 10}" class="head">), xml_escape(label), "</text>"],
         x + width}
      end)

    cells =
      for row <- rows do
        y = top + row.index * row_height + row_height / 2 + 4

        {cells, _x} =
          Enum.map_reduce(columns, 0, fn {_label, width, field}, x ->
            {text, indent} =
              case field do
                :text ->
                  {row.task.text, row.level * 16}

                :start ->
                  {format.(row.task.start_date, pattern), 0}

                :duration ->
                  {if(row.task.type == :milestone, do: "", else: to_string(row.task.duration)), 0}
              end

            weight =
              if row.task.type == :project and field == :text,
                do: ~s( font-weight="600"),
                else: ""

            {[
               ~s(<text x="#{x + 10 + indent}" y="#{n(y)}"#{weight}>),
               xml_escape(truncate(text, width - 20 - indent)),
               "</text>"
             ], x + width}
          end)

        cells
      end

    [headers, cells]
  end

  defp svg_links(links) do
    for link <- links do
      [~s(<path class="link" d="#{link.d}"/>), ~s(<path class="arrow" d="#{link.arrow_d}"/>)]
    end
  end

  defp svg_bars(bars) do
    bars
    |> Enum.with_index()
    |> Enum.map(fn {bar, index} ->
      task = bar.task
      {fill, progress_fill} = Map.fetch!(@svg_colors, bar.kind)
      fill = task.color || fill
      progress_fill = task.progress_color || progress_fill

      case bar.kind do
        :milestone ->
          cx = bar.x + bar.width / 2
          cy = bar.y + bar.height / 2
          r = bar.height / 2

          [
            ~s(<polygon points="#{n(cx)},#{n(cy - r)} #{n(cx + r)},#{n(cy)} #{n(cx)},#{n(cy + r)} #{n(cx - r)},#{n(cy)}" fill="#{fill}"/>),
            ~s(<text x="#{n(bar.x + bar.width + 6)}" y="#{n(cy + 4)}" class="side-text">),
            xml_escape(task.text),
            "</text>"
          ]

        _ ->
          inside? = String.length(task.text) * 6.5 + 16 < bar.width

          [
            ~s(<clipPath id="bar-#{index}"><rect x="#{n(bar.x)}" y="#{n(bar.y)}" width="#{n(bar.width)}" height="#{bar.height}" rx="4"/></clipPath>),
            ~s|<g clip-path="url(#bar-#{index})">|,
            ~s(<rect x="#{n(bar.x)}" y="#{n(bar.y)}" width="#{n(bar.width)}" height="#{bar.height}" fill="#{fill}"/>),
            ~s(<rect x="#{n(bar.x)}" y="#{n(bar.y)}" width="#{n(bar.width * bar.progress)}" height="#{bar.height}" fill="#{progress_fill}"/>),
            "</g>",
            if(inside?,
              do:
                ~s(<text x="#{n(bar.x + 8)}" y="#{n(bar.y + bar.height / 2 + 4)}" class="bar-text">),
              else:
                ~s(<text x="#{n(bar.x + bar.width + 6)}" y="#{n(bar.y + bar.height / 2 + 4)}" class="side-text">)
            ),
            xml_escape(task.text),
            "</text>"
          ]
      end
    end)
  end

  # Text is not clipped in SVG, so long labels are shortened (~6.5px per character).
  defp truncate(text, width) do
    max = max(trunc(width / 6.5), 1)
    if String.length(text) > max, do: String.slice(text, 0, max - 1) <> "…", else: text
  end

  defp n(value), do: LinkPath.format_number(value)

  # MSPDI link types: 0 = FF, 1 = FS, 2 = SF, 3 = SS
  defp ms_link_type(:finish_to_finish), do: 0
  defp ms_link_type(:finish_to_start), do: 1
  defp ms_link_type(:start_to_finish), do: 2
  defp ms_link_type(:start_to_start), do: 3

  defp bit(true), do: 1
  defp bit(false), do: 0

  defp xml_date(date), do: Calendar.strftime(date, "%Y-%m-%dT%H:%M:%S")

  defp xml_escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  defp format_date(nil), do: ""
  defp format_date(date), do: Calendar.strftime(date, "%Y-%m-%d %H:%M")
end
