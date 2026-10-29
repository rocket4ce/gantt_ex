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
`:type` or `nil`), `sortable`, `hidden` and `actions`. See
`GanttEx.Live.Columns`.

## Column chooser and layout

Plans carry more data than fits on screen. Declare every column the user
may want and mark the optional ones `hidden`: they are listed in the column
chooser (the "Columns" button of the toolbar) and shown when the user adds
them. Their content still comes from your slot:

```heex
<:column field={:wbs} hidden />
<:column field={:text} tree />
<:column field={:start_date} />
<:column field={:cost} label="Cost" align="right" hidden :let={task}>
  {Money.to_string(task.meta[:cost])}
</:column>
<:column field={:company} label="Company" hidden :let={task}>
  <img src={task.meta[:company_logo]} alt="" class="size-5 rounded" /> {task.meta[:company]}
</:column>
```

The chooser shows and hides columns, reorders them by dragging (or with
the arrow buttons, from the keyboard) and resets them to the slots. Headers
can also be dragged onto each other; a click still sorts and the edges
still resize. The tree column is always shown. `column_chooser={false}`
removes the button.

Every change is reported as a `:columns_changed` event with the layout,
which can be given back as `column_layout` (see the
[Persistence](persistence.html) guide):

```elixir
%{order: ["wbs", "text", "start_date", "cost", "company"], hidden: ["company"],
  widths: %{"text" => 300}, grid_width: nil}
```

Fields that are no longer columns are ignored, and new slots are added at
the end, hidden if their slot says so.

## Filters and search

The toolbar has a search input (task names and WBS codes, ignoring case and
accents) and a "Filters" button whose badge counts the active filters. The
panel offers the filters given in `filters`, by default
`[:search, :status, :type, :dates]`:

- `:status`: not started, in progress, completed, overdue (unfinished
  after its end or its deadline), critical (while the critical path is
  shown), blocked and with restrictions
- `:type`: tasks, projects and milestones
- `:dates`: tasks overlapping a range of days

Your own filters are maps. They are rendered as comboboxes: the options
can be searched as you type (by default with more than 8 options), the
selected ones are chips that can be removed, and each filter can be cleared.

```elixir
people = for p <- @people, do: %{label: p.name, value: p.id, image: p.avatar_url, hint: p.role}
companies = for c <- @companies, do: %{label: c.name, value: c.id, image: c.logo_url}

filters = [
  :search,
  :status,
  %{id: :responsible, label: "Responsible", field: :responsible_id,
    options: [%{label: "Unassigned", value: nil} | people], placeholder: "Search people"},
  %{id: :company, label: "Company", field: &task_company/1, options: companies},
  %{id: :resources, label: "Crews", options: Enum.map(@crews, &{&1.name, &1.id})},
  :dates
]
```

`field` is a task field, a `:meta` key or a function of the task; when the
value is a list (such as `:resources`) any of them can match, and the `nil`
option matches tasks without value. Values of a filter combine with OR,
filters combine with AND (and with the `filter` function attribute).

Matching tasks are shown with their ancestors, with "N of M tasks" and the
active filters above the chart; rows cannot be reordered meanwhile. The
selection is reported as `:filters_changed` events and can be restored with
`filter_values`. `filters={false}` removes the search and the panel. The
logic is in `GanttEx.Filter`, usable on its own.

## Row actions

An `:actions` column shows compact buttons on every row, revealed on hover,
focus and selection (always on touch screens):

```heex
<:column field={:actions} actions={[:drag, :rename, :block, :restriction, :detail, :delete]} />
<:column field={:actions} actions={[:drag, :edit, %{id: :approve, icon: :check, label: "Approve"}]} />
```

- `:drag` - a grip to drag the row (reorder or re-parent it). With the
  keyboard, the arrow keys move it among its siblings. It is dimmed, with
  the reason in its tooltip, while rows are sorted, filtered or grouped.
- `:rename` - edits the name in place. `:edit` opens the lightbox.
- `:block` - blocks or unblocks the task, as a normal change: undoable and
  reported as `:task_updated` with `changes: %{blocked: true}`.
- `:restriction` and `:detail` - reported as `:task_action` events, for
  you to open your own dialog or side panel.
- `:delete` - deletes the task after confirmation.
- Custom actions (`%{id, icon, label}`, `icon` from
  `GanttEx.Live.Icons.names/0`) are reported as `:task_action` events too.

Read-only charts and tasks hide the actions that edit; `:detail` and custom
actions stay. The column is as wide as its actions unless `width` is given.

## Status indicators

Tasks with `blocked: true` show a lock next to their name and a hatched bar;
tasks with open `restrictions` (a count) show a warning with the count and a
dot on their bar. Tooltips and the quick info mention both. Rows and bars get
the `gx-row--blocked`, `gx-row--restricted`, `gx-bar--blocked` and
`gx-bar--restricted` classes, and the tones are custom properties:

```css
.gx-root {
  --gx-danger: #dc2626;        /* blocked */
  --gx-danger-strong: #b91c1c;
  --gx-danger-soft: rgba(220, 38, 38, 0.1);
  --gx-warning: #f59e0b;       /* restrictions */
  --gx-warning-strong: #b45309;
  --gx-warning-soft: rgba(245, 158, 11, 0.14);
}
```

## Last Planner: lookahead and weekly plan

Add `:lookahead` to the `filters` to get a toolbar menu that shows the next
weeks only: from the start of the current week (`week_start`) and as many
weeks as chosen (1, 2, 3, 4 or 6, or `%{id: :lookahead, weeks: [2, 4, 6]}`).
The timeline shows those weeks day by day and only the tasks overlapping
them, with their summary tasks. The value is part of the filter values
(`%{lookahead: 3}`), so it is reported with `:filters_changed` and can be
restored with `filter_values`.

`plans` shows the commitments of plans of one week or more (such as the
plans within the lookahead):

```heex
plans={[
  %{id: 1, week: ~D[2025-03-03], committed: @this_week, label: "Week 10"},
  %{id: 2, week: ~D[2025-03-10], weeks: 2, committed: @next_weeks, label: "Weeks 11-12"}
]}
```

The period of each plan is highlighted on the scale and the chart, the bars
of the tasks committed in any of them are green and the other tasks are
muted (summary tasks and milestones keep their colors; critical tasks keep a
red underline). The colors are custom properties:

```css
.gx-root {
  --gx-plan: #14b8a6;
  --gx-plan-soft: rgba(20, 184, 166, 0.07);
  --gx-committed: #bbf7d0;
  --gx-committed-progress: #4ade80;
  --gx-committed-border: #22c55e;
  --gx-not-committed: #c3d2dd;
  --gx-not-committed-progress: #8ca6b9;
}
```

## Legend and summary bars

`legend` adds a legend below the chart with the bars and marks it can show
(tasks, progress, summary tasks, milestones, critical path, baselines,
deadlines, overdue, blocked, restrictions, today and the weekly plan).
`legend_items` adds your own entries, such as the colors of your bars:

```heex
legend_items={[%{label: "Concrete Ltd.", color: "#0ea5e9"}, %{label: "Rain", icon: :exclamation_triangle}]}
```

`summary_bars={:bracket}` draws summary tasks as in MS Project: a thin bar
with downward ends and the name after it. Summary bars get the
`gx-bar--summary` class.

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
`links_editable`, `drag_create`, `toolbar`, `show_grid`, `smart_rendering`,
`filter`, `filters` and `column_chooser`. See `GanttEx.Live.Gantt` for the
full list.

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
