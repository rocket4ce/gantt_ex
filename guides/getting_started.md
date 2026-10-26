# Getting started

This guide adds a Gantt chart to a Phoenix 1.8 application.

## 1. Install

```elixir
# mix.exs
{:gantt_ex, "~> 0.1.0"}
```

```javascript
// assets/js/app.js
import {hooks as ganttHooks} from "phoenix-colocated/gantt_ex"

const liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, ...ganttHooks},
})
```

```css
/* assets/css/app.css */
@import "phoenix-colocated/gantt_ex/colocated.css";
```

The hook and the stylesheet are extracted when GanttEx compiles, so run
`mix compile` before building assets in custom pipelines (for example
`release: ["compile", "assets.deploy", "release"]`).

## 2. Render a chart

```elixir
defmodule MyAppWeb.RoadmapLive do
  use MyAppWeb, :live_view

  def mount(_params, _session, socket) do
    tasks = [
      %{id: 1, text: "Roadmap", type: :project},
      %{id: 2, text: "Research", parent: 1, start_date: ~D[2025-03-03], duration: 4, progress: 0.5},
      %{id: 3, text: "Prototype", parent: 1, start_date: ~D[2025-03-07], duration: 6},
      %{id: 4, text: "Demo day", type: :milestone, start_date: ~D[2025-03-14]}
    ]

    links = [
      %{id: 1, source: 2, target: 3},
      %{id: 2, source: 3, target: 4}
    ]

    {:ok, assign(socket, tasks: tasks, links: links)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.live_component module={GanttEx.Live.Gantt} id="roadmap" tasks={@tasks} links={@links} />
    </Layouts.app>
    """
  end

  def handle_info({GanttEx, %GanttEx.Event{}}, socket), do: {:noreply, socket}
end
```

That is a fully interactive chart: drag bars, resize them, draw links from
the round handles, double click a row to edit it, use the arrow keys, zoom,
export...

## 3. Data format

| Field | Description |
| --- | --- |
| `id` | Required. Integer, string (UUID) or atom. |
| `text` | Task name. |
| `start_date` | `Date`, `NaiveDateTime`, `DateTime` or a string (`"2025-03-03"`, `"2025-03-03 09:00"`, `"03-03-2025"`). |
| `end_date` | Exclusive end date. Computed from `duration` when missing. |
| `duration` | Integer amount of `duration_unit` (`:day` by default). |
| `progress` | `0.0` to `1.0`. |
| `parent` / `parent_id` | Id of the parent task. |
| `type` | `:task`, `:project` or `:milestone` (atoms or strings). |
| `open` | `false` to start collapsed. |
| `readonly` | `true` to lock the task. |
| `color`, `text_color`, `progress_color` | CSS colors. |

Links have `id`, `source` (or `source_id`), `target` (or `target_id`),
`type` (`:finish_to_start`, `:start_to_start`, `:finish_to_finish`,
`:start_to_finish` or the DHTMLX codes `"0"`..`"3"`) and `lag`.

Any other field is kept in `task.meta`.

## 4. Next steps

- Save changes to your database: [Persistence](persistence.md)
- Columns, templates, zoom levels and themes: [Customization](customization.md)
- Languages and date formats: [Internationalization](i18n.md)
