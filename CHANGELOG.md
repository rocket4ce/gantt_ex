# Changelog

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
