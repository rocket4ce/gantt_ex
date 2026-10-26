# Persistence

`GanttEx.Live.Gantt` applies user changes immediately and notifies the
LiveView that renders it with `{GanttEx, %GanttEx.Event{}}` messages. The
LiveView persists them and renders the component with fresh data; the
chart reloads while keeping its UI state (selection, expanded rows, zoom).

```elixir
def handle_info({GanttEx, %GanttEx.Event{type: :task_selected}}, socket), do: {:noreply, socket}

def handle_info({GanttEx, %GanttEx.Event{} = event}, socket) do
  case Planning.apply_event(event) do
    :ok ->
      {:noreply, assign(socket, tasks: Planning.list_tasks(), links: Planning.list_links())}

    {:error, _reason} ->
      # Nothing changed in the database, so the chart must drop its local change.
      GanttEx.Live.Gantt.reload("gantt")
      {:noreply, put_flash(socket, :error, "Could not save the change")}
  end
end
```

## Events

| Type | Fields | Notes |
| --- | --- | --- |
| `:task_created` | `task` | The id is temporary (`"gx-..."`); insert a new record. |
| `:task_updated` | `task`, `changes` | `changes` only has the changed fields. Also sent for projects whose dates were recomputed. |
| `:task_deleted` | `task` | Sent for every deleted task, deepest first. |
| `:task_moved` | `task`, `parent`, `index`, `siblings` | `siblings` is the new order of the branch. |
| `:link_created` | `link` | Temporary id. |
| `:link_updated` | `link`, `changes` | Type or lag changed. |
| `:link_deleted` | `link` | Also sent for the links of deleted tasks. |
| `:task_selected` | `task` | Not a change, useful for side panels. |

## A schema that maps 1:1

Using the DHTMLX field names in your schema lets you pass records straight
to the component:

```elixir
schema "tasks" do
  field :text, :string
  field :type, Ecto.Enum, values: [:task, :project, :milestone], default: :task
  field :start_date, :naive_datetime
  field :duration, :integer, default: 1
  field :progress, :float, default: 0.0
  field :open, :boolean, default: true
  field :position, :integer, default: 0
  belongs_to :parent, __MODULE__, type: :binary_id
  timestamps()
end
```

Order the query by `position` (siblings are displayed in the given order) and
persist `:task_moved` events by updating the `position` of every sibling.

A complete implementation lives in the example application:
`example/live_gantt/lib/live_gantt/planning.ex`.

## Without a database

The parent can also ignore the events: the chart keeps its local state until
the parent renders it with different `tasks` or `links`. `GanttEx.Store` can
also be used directly to apply the same rules on the server:

```elixir
{:ok, store, changes} = GanttEx.Store.update_task(store, 3, %{duration: 5})
```
