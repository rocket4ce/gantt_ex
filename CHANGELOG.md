# Changelog

## 0.3.0 (2026-10-28)

Charts of thousands of tasks edited by many people at once. Measured on a
real plan of 7,000 tasks and 10,700 links, all under one summary task.

Additions:

- `:batch_events` attribute: the changes of each user action are reported
  as one `:batch` event (`GanttEx.Event` has an `:events` field) instead of
  one event per task, so a move that pushes thousands of tasks with
  auto-scheduling can be saved at once
- `GanttEx.Store.put_tasks/2` replaces existing tasks without building the
  store again
- `GanttEx.CriticalPath.inputs/1`: what an analysis depends on
- `GanttEx.Layout.build/4` accepts the `:link_cache` of a previous layout
  and returns its own

Performance:

- New data that only changes some tasks (other people's changes) is
  applied to the store with `put_tasks/2` instead of building it again
- Rows, layout and link routes are reused between renders: selecting a
  task, opening a popover or the lightbox no longer lays out the chart
  again, and links whose bars did not move keep their route. Selection,
  critical path and slack flags are only set on the rendered window
- The critical path is computed again only when dates, durations, types,
  links or calendars change, not for a new progress or name
- Working-time arithmetic works on day numbers and skips whole weeks
  without exceptions (critical path 152 ms to 92 ms)
- WBS codes are computed in linear time (quadratic in the number of
  children of a summary task before)
- Link coordinates are formatted with integer arithmetic

## 0.2.0 (2026-10-28)

Filters, row actions and dynamic columns, for plans with thousands of tasks
and more data than fits in the grid.

Additions:

- Status indicators: tasks have `:blocked` and `:restrictions` (the number
  of open restrictions, as in the Last Planner System) fields, shown with a
  lock and a warning next to the task name, hatched or marked bars and in
  tooltips and the quick info (`gx-row--blocked`, `gx-row--restricted`,
  `gx-bar--blocked`, `gx-bar--restricted`, `--gx-danger*` and
  `--gx-warning*` custom properties)
- Search and filters: a search input in the toolbar (names and WBS codes,
  ignoring case and accents) and a filter panel with status (not started,
  in progress, completed, overdue, critical, blocked, with restrictions),
  type, dates and custom filters rendered as searchable comboboxes with
  removable chips (`:filters` attribute). Matching tasks are shown with
  their ancestors, with how many matched and the active filters above the
  chart
- `:filter_values` restores the filters and `:filters_changed` events
  report them; `GanttEx.Filter` holds the logic and runs in linear time
- Row actions: an `:actions` column (`actions` slot attribute) with a drag
  handle (also moved with the arrow keys), rename, edit, block/unblock,
  add a restriction, open the detail, delete and custom actions, reported
  as `:task_action` events when the host handles them
- Column chooser: columns can be declared `hidden`, shown, hidden,
  reordered and reset from the toolbar (`:column_chooser` attribute), and
  headers can be dragged to reorder them. `:column_layout` restores the
  layout and `:columns_changed` events report it
- `GanttEx.Event` has `:action`, `:filters` and `:columns` fields
- `GanttEx.Store.rows/2` accepts a `:visible` set of ids
- `GanttEx.Live.Columns.available/3`, `normalize_layout/1`, `layout/2`
  and `actions_width/1`, and `GanttEx.Live.Icons.names/0`
- Translations of every new label in the 8 languages

Changes:

- The default toolbar shows the search, the filters and the column chooser;
  `filters={false}` and `column_chooser={false}` hide them
- A host `:filter` function is combined with the filters of the toolbar, and
  `GanttEx.Store.rows/2` with `:filter` adds each ancestor once (linear time)
- Tasks given with `blocked` or `restrictions` fields get them as task fields
  instead of `:meta`

Fixes:

- With smart rendering, a chart scrolled down that gets fewer rows no
  longer renders an empty window past its last row

## 0.1.3 (2026-10-28)

Fixes:

- The quick info of a bar opens where the bar was clicked, instead of at
  the start of the bar, which could be scrolled under the grid and cover
  it. It stays in the visible part of the timeline: it opens to the left of
  the click when there is no room on the right, and follows changes of the
  page layout

## 0.1.2 (2026-10-28)

Fixes:

- Narrowing the grid (with its splitter or the `:grid_width` attribute)
  below the width of its columns no longer lets them overflow onto the
  timeline: they are clipped from the right, and the tree column keeps at
  least 120px

## 0.1.1 (2026-10-26)

Performance with large plans. Measured on a real plan of 7,000 tasks and
10,700 links, all under one summary task:

- `GanttEx.Store.new/3` validates the links in bulk (21 s to 0.2 s)
- `GanttEx.CriticalPath.analyze/1` indexes the links by task and counts
  working time by whole weeks (25 s to 0.2 s)
- `GanttEx.Dependency.order/2` is no longer quadratic (11 s to 0.05 s)
- `GanttEx.Scheduler.schedule/2` rolls up projects once instead of after
  every moved task (47 s to 0.1 s)

Results are the same as in 0.1.0.

Additions:

- `GanttEx.Dependency.index/1`, accepted by `GanttEx.Dependency.order/2`,
  `GanttEx.Dependency.earliest_start/3` and
  `GanttEx.Scheduler.target_start/4`
- `GanttEx.Store.rollup/2` and the `:rollup` option of
  `GanttEx.Store.update_task/4`

## 0.1.0 (2026-10-26)

First version, covering the features of the DHTMLX Gantt community edition:

- `GanttEx.Live.Gantt` LiveComponent with grid, timeline, drag & drop,
  dependencies, lightbox, inline editing, quick info, tooltips, keyboard
  navigation, zoom, fullscreen, print and export
- Data model (`GanttEx.Task`, `GanttEx.Link`, `GanttEx.Store`) with
  scheduling rules, project roll-up and cycle detection
- `GanttEx.Event` notifications to persist changes
- Smart rendering of large charts (only the rows around the viewport)
- Export to JSON, CSV, iCalendar, MS Project XML, SVG and PNG; import from
  DHTMLX JSON/XML and MS Project XML (safe XML parsing, no atoms created)
- Translations for en, es, fr, it, de, pt, pt_BR and ja

Features of the DHTMLX Gantt PRO edition:

- Working-time calendars (`GanttEx.Calendar`), per-task calendars and
  highlighted non-working days
- Task constraints and auto-scheduling (`GanttEx.Scheduler`,
  `GanttEx.Dependency`)
- Critical path and slack (`GanttEx.CriticalPath`)
- Baselines and deadlines
- Resources and resource load (`GanttEx.Resource`, `GanttEx.ResourceLoad`)
- Grouping, split tasks and rollups
- Undo/redo (`GanttEx.History`, `GanttEx.Store.diff/2`)
- Multi-selection, bulk deletion and multi-drag
- Timeline markers (`GanttEx.Marker`) and WBS codes
- Dynamic loading (`:branch_requested` events) and auto types
