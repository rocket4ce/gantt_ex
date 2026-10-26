# Advanced features

These features match the DHTMLX Gantt PRO edition. They are all opt-in.

## Working time

```heex
<.live_component
  module={GanttEx.Live.Gantt}
  id="gantt"
  tasks={@tasks}
  links={@links}
  work_time
  calendar={[work_days: 1..5, hours: ["09:00-13:00", "14:00-18:00"], holidays: [~D[2025-12-25]]]}
  calendars={[[id: "weekend-crew", work_days: [6, 7]]]}
/>
```

Durations then count working days (or working hours with
`duration_unit={:hour}`), starts snap to working time, and non-working days
and holidays are highlighted. Tasks use another calendar with
`calendar_id: "weekend-crew"`. See `GanttEx.Calendar`.

## Auto-scheduling and constraints

`auto_scheduling` moves tasks after every change so that dependencies and
constraints hold; `auto_scheduling_strict` also moves them earlier. Tasks
accept `constraint_type` (`:asap`, `:alap`, `:snet`, `:snlt`, `:fnet`,
`:fnlt`, `:mso`, `:mfo`) and `constraint_date`, editable in the lightbox.
Moves caused by scheduling are reported as `:task_updated` events within the
same undo step. See `GanttEx.Scheduler`.

## Critical path and slack

`critical_path` highlights the critical tasks and links (the toolbar has a
toggle), `show_slack` draws the free slack after each bar, and the
`:total_slack` / `:free_slack` columns show the numbers. See
`GanttEx.CriticalPath`.

## Baselines and deadlines

Tasks accept `planned_start` / `planned_end` (drawn below the bar with
`baselines`) and `deadline` (a flag; tasks ending after it are marked as
overdue). The lightbox sections are `:baseline` and `:deadline`, and the
grid columns `:planned_start`, `:planned_end` and `:deadline`.

## Resources

```heex
<.live_component
  module={GanttEx.Live.Gantt}
  id="gantt"
  tasks={@tasks}
  links={@links}
  resources={[%{id: "ana", text: "Ana", capacity: 8}, %{id: "luis", text: "Luis"}]}
  resource_panel
  lightbox_sections={[:text, :time, :resources]}
/>
```

Tasks list their assignments in `resources` (`["ana"]` or
`[%{resource_id: "ana", value: 4}]`, the value being units per working day).
The resource panel shows the load of each resource per column and highlights
overloads. See `GanttEx.Resource` and `GanttEx.ResourceLoad`.

## Grouping

`group_by` regroups tasks under virtual rows: a task field (`:type`), a
`:meta` key (`:owner`), `:resources` (a task appears under each of its
resources) or a function. `group_label` customizes the labels.

## Split tasks and rollups

A task with `render: :split` draws its children on its own row (they can be
dragged there, and links reach them while the branch is collapsed). Tasks
with `rollup: true` also appear on the rows of their ancestor projects.

## Undo and redo

Enabled by default (`undo={false}` disables it): toolbar buttons,
Ctrl/Cmd+Z and Ctrl/Cmd+Shift+Z or Ctrl+Y. Undone changes are reported as
events, so they are persisted like any other change. Undoing a deletion
sends `:task_created` / `:link_created` events with the original ids: insert
them with those ids so that links stay valid. See `GanttEx.History`.

## Multi-selection

Ctrl/Cmd+click toggles tasks and Shift+click selects ranges. Dragging a
selected bar moves the whole selection, and Delete removes all the selected
tasks after a single confirmation. `:task_selected` events carry the
`selection`.

## Timeline markers

`markers={[%{date: ~D[2025-03-01], text: "Release", color: "#e11d48"}]}` and
`today_marker` draw vertical lines with labels. See `GanttEx.Marker`.

## WBS codes

The `:wbs` column shows outline numbers (`1.2.3`), see
`GanttEx.Store.wbs_codes/1`.

## Dynamic loading

Mark tasks whose children are not loaded with `has_children: true`.
Expanding one sends a `:branch_requested` event; load the children and render
the component with them:

```elixir
def handle_info({GanttEx, %GanttEx.Event{type: :branch_requested, task: task}}, socket) do
  {:noreply, update(socket, :tasks, &(&1 ++ Planning.children_of(task.id)))}
end
```

## Auto types

`auto_types` turns tasks with children into projects and projects without
children into tasks, on load and after every change.
