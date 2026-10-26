# LiveGantt

A Phoenix application showing [GanttEx](../../README.md) backed by Postgres.

```shell
mix setup        # deps, database, seeds and assets
mix phx.server   # http://localhost:4000
```

`mix run priv/repo/seeds.exs` resets the sample "Website relaunch" project.

## Where to look

- `lib/live_gantt_web/live/gantt_live.ex` - the page: renders
  `GanttEx.Live.Gantt` with custom columns and lightbox fields, and persists
  every `{GanttEx, %GanttEx.Event{}}` it receives.
- `lib/live_gantt/planning.ex` - `apply_event/1` maps each event to Ecto.
- `lib/live_gantt/planning/task.ex` - a schema using the GanttEx field
  names, so records are given to the chart as they are.
- `assets/js/app.js` and `assets/css/app.css` - the two lines that install
  the GanttEx hook and stylesheet.

## Advanced features

The switches above the chart turn on working days (with a holiday),
auto-scheduling, baselines, grouping by owner, the workload panel (owners
double as resources) and read-only mode. The toolbar toggles the critical
path, and the chart shows a today marker, a "Release freeze" marker, WBS
codes and deadlines.

## Troubleshooting

**`GET /assets/css/app.css` returns 404 on macOS.** The standalone Tailwind
binary may ship with an invalid code signature, and recent macOS versions
kill it at startup (exit code 137), so the CSS is never built. Re-sign it
and rebuild:

```shell
codesign --force --sign - _build/tailwind-macos-arm64-*
mix tailwind live_gantt
```
