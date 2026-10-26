# Customization

## Columns

Columns are slots. Built-in fields get a translated label, a width and an
inline editor; other fields are read from `task.meta`.

```heex
<.live_component module={GanttEx.Live.Gantt} id="gantt" tasks={@tasks} links={@links}>
  <:column field={:text} tree width={260} />
  <:column field={:owner} label="Owner" width={120} editor={:text} :let={task}>
    <span class="font-medium">{task.meta[:owner]}</span>
  </:column>
  <:column field={:start_date} />
  <:column field={:end_date} />
  <:column field={:progress} align="right" />
  <:column field={:add} />
</.live_component>
```

Slot attributes: `field`, `label`, `width`, `align` (`"left"`, `"center"`,
`"right"`), `tree`, `editor` (`:text`, `:date`, `:number`, `:progress`,
`:type` or `nil`) and `sortable`. See `GanttEx.Live.Columns`.

## Bars and tooltips

```heex
<:task_text :let={task}>{task.text} · {round(task.progress * 100)}%</:task_text>
<:tooltip :let={task}><strong>{task.text}</strong><p>{task.meta[:notes]}</p></:tooltip>
```

`task_class={&if(&1.meta[:late], do: "is-late")}` adds classes to bars, and
the `color`, `text_color` and `progress_color` task fields color them.

## Lightbox

Choose the sections with `lightbox_sections={[:text, :time, :progress]}` and
add fields with the `:lightbox_fields` slot. Their values are saved in
`task.meta`:

```heex
<:lightbox_fields :let={form}>
  <div class="gx-field">
    <label for={form[:owner].id}>Owner</label>
    <input id={form[:owner].id} name={form[:owner].name} value={form[:owner].value} class="gx-input" />
  </div>
</:lightbox_fields>
```

## Time scale

The built-in zoom levels are `:hour`, `:day`, `:week`, `:month`, `:quarter`
and `:year`. Pass your own with `zoom_levels`:

```elixir
zoom_levels = [
  %{name: :sprint, column_width: 64,
    scales: [[unit: :month, format: :month_year], [unit: :week, step: 2, format: "S%V"]]},
  %{name: :month, column_width: 90, scales: [[unit: :year], [unit: :month, format: :month]]}
]
```

Formats can be named patterns (see `GanttEx.I18n.pattern/2`), strftime
strings (`%V` is the ISO week) or functions. A fixed range can be set with
`start_date` and `end_date`; otherwise it fits the tasks.

## Themes

Every color and size is a CSS custom property on `.gx-root`:

```css
.gx-root {
  --gx-accent: #0ea5e9;
  --gx-task: #0ea5e9;
  --gx-task-progress: #0369a1;
  --gx-project: #8b5cf6;
  --gx-milestone: #f97316;
  --gx-radius: 4px;
  --gx-font-size: 14px;
}
```

`theme="auto"` (the default) follows `prefers-color-scheme` and a
`data-theme="dark"` / `data-theme="light"` attribute on an ancestor, which
is what the Phoenix theme toggle sets. Use `theme="dark"` or `"light"` to
force one. Sizes: `row_height`, `bar_height`, `scale_height`, `height`
(CSS) and `grid_width`.

## Behaviour flags

`readonly`, `lightbox`, `inline_edit`, `quick_info`, `tooltips`, `reorder`,
`links_editable`, `drag_create`, `toolbar`, `show_grid`, `smart_rendering`
and `filter`. See `GanttEx.Live.Gantt` for the full list.

## Large charts

With `smart_rendering={:auto}` (the default), charts with more than 120
visible rows only render the rows around the viewport, plus the bars and
dependencies crossing them. The hook reports the scroll position when the
user gets close to the edge of the rendered rows.

## Import and export

The toolbar offers JSON, CSV, iCalendar, MS Project, SVG and PNG
(`export_formats`). Images show the chart as it is on screen. The same
functions are available on the server:

```elixir
GanttEx.Export.to_svg(store, locale: "fr", zoom: :week)
{:ok, %{tasks: tasks, links: links}} = GanttEx.Import.from_ms_project(File.read!("plan.xml"))
```

## Controlling the chart

From the parent LiveView:

```elixir
GanttEx.Live.Gantt.zoom("gantt", :month)
GanttEx.Live.Gantt.select("gantt", task_id)
GanttEx.Live.Gantt.expand_all("gantt")
```
