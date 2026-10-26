# Changelog

## Unreleased

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

Fixes:

- Pixel values were rendered in exponent notation (`1.2e3px`) for some
  round numbers

## 0.1.0 (unreleased)

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
