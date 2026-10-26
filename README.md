# GanttEx

Interactive Gantt charts for **Phoenix LiveView**, inspired by
[DHTMLX Gantt](https://github.com/DHTMLX/gantt).

State, validation, layout and dialogs live on the server. The only
JavaScript is one small colocated hook for what needs the mouse:
dragging, resizing and drawing dependencies.

```heex
<.live_component module={GanttEx.Live.Gantt} id="gantt" tasks={@tasks} links={@links} locale="es" />
```

## Features

These are the features of the DHTMLX Gantt community edition:

- **Task grid**: tree, configurable columns (slots), sorting, resizable
  columns and grid, inline editing
- **Task types**: tasks, projects (dates rolled up from their children) and milestones
- **Drag & drop**: move, resize and change progress, with snapping; reorder
  and re-parent rows
- **Dependencies**: finish-to-start, start-to-start, finish-to-finish and
  start-to-finish with lag, drawn by dragging between bar edges, with
  cycle detection
- **Zoomable time scale**: hours, days, weeks, months, quarters and years,
  or your own levels
- **Lightbox editor** with configurable sections and custom fields, quick
  info popup, tooltips and confirmation dialogs
- **Drag to create** tasks on the timeline and drag to pan, with edge
  auto-scrolling
- **Smart rendering**: large charts only render the rows around the viewport
- **Keyboard navigation**, fullscreen and print (PDF)
- **Export** to JSON (DHTMLX format), CSV/Excel, iCalendar, MS Project XML,
  SVG and PNG; **import** from DHTMLX JSON/XML and MS Project XML
- **8 languages**: English, Spanish, French, Italian, German, Portuguese,
  Brazilian Portuguese and Japanese (Gettext `.po` files)
- **Light and dark themes** based on CSS custom properties, WAI-ARIA roles,
  touch support and reduced motion
- **Events for persistence**: every change is sent to your LiveView as
  `{GanttEx, %GanttEx.Event{}}`

## Installation

Add `gantt_ex` to your dependencies (Phoenix 1.8+, LiveView 1.2+):

```elixir
def deps do
  [
    {:gantt_ex, "~> 0.1.0"}
  ]
end
```

Register the hook in `assets/js/app.js`:

```javascript
import {hooks as ganttHooks} from "phoenix-colocated/gantt_ex"

const liveSocket = new LiveSocket("/live", Socket, {
  hooks: {...colocatedHooks, ...ganttHooks},
  // ...
})
```

Import the styles in `assets/css/app.css` (Tailwind 4.2.3+):

```css
@import "phoenix-colocated/gantt_ex/colocated.css";
```

New Phoenix 1.8 applications already have the `NODE_PATH` and compiler
configuration needed to resolve `phoenix-colocated`. See
`Phoenix.LiveView.ColocatedJS` if yours does not.

## Usage

```elixir
defmodule MyAppWeb.ProjectLive do
  use MyAppWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, tasks: Planning.list_tasks(), links: Planning.list_links())}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.live_component module={GanttEx.Live.Gantt} id="gantt" tasks={@tasks} links={@links} />
    </Layouts.app>
    """
  end

  # Persist every change, then re-render the chart with fresh data.
  def handle_info({GanttEx, %GanttEx.Event{} = event}, socket) do
    :ok = Planning.apply_event(event)
    {:noreply, assign(socket, tasks: Planning.list_tasks(), links: Planning.list_links())}
  end
end
```

Tasks can be maps, keyword lists or structs (Ecto schemas included) with
DHTMLX field names: `id`, `text`, `start_date`, `end_date`, `duration`,
`progress` (0..1), `parent` (or `parent_id`), `type` and `open`. Any other
field ends up in `task.meta` and can be shown in custom columns.

```heex
<.live_component module={GanttEx.Live.Gantt} id="gantt" tasks={@tasks} links={@links} zoom={:week}>
  <:column field={:text} tree />
  <:column field={:owner} label="Owner" editor={:text} :let={task}>{task.meta[:owner]}</:column>
  <:column field={:start_date} />
  <:column field={:duration} />
  <:column field={:add} />
</.live_component>
```

## Guides

- [Getting started](guides/getting_started.md)
- [Persistence](guides/persistence.md)
- [Customization](guides/customization.md)
- [Internationalization](guides/i18n.md)

## Example application

`example/live_gantt` is a Phoenix application that
stores a project in Postgres:

```shell
cd example/live_gantt
mix setup
mix phx.server
```

## Development

```shell
mix test       # unit tests, LiveView tests and doctests
mix docs       # documentation
mix precommit  # compile with warnings as errors, format and test
```

## License

MIT, see the `LICENSE` file.

## Roadmap

The next version targets the DHTMLX PRO features: working-time calendars,
auto-scheduling, critical path, resources, baselines and deadlines,
constraints, split tasks, rollups, grouping, undo/redo, multi-selection,
timeline markers and WBS codes.
