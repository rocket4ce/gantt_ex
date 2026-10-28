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
| `:task_action` | `task`, `action` | A row action for you to handle: `:restriction`, `:detail` or a custom one. |
| `:filters_changed` | `filters` | The search and filters selected by the user. |
| `:columns_changed` | `columns` | The order, hidden columns and widths set by the user. |

The last three are not changes of the plan: handle them before your
generic clause.

## Large plans

A move with auto-scheduling can push thousands of tasks. With
`batch_events`, the changes of each user action arrive as one `:batch`
event holding the events above, in order, so they can be saved in one
transaction:

```elixir
def handle_info({GanttEx, %GanttEx.Event{type: :batch, events: events}}, socket) do
  :ok = Planning.apply_events(events)
  {:noreply, assign(socket, tasks: Planning.list_tasks())}
end
```

Render the chart again with the same list where only the changed tasks
are replaced (same tasks, same order, same links): the component updates
those tasks in its store instead of building it again, which keeps charts
of thousands of tasks fast when other people change them. Adding,
deleting or moving tasks builds the store again.

## Blocked tasks and restrictions

`blocked` (boolean) and `restrictions` (the number of open restrictions)
are task fields: add them to your schema (or compute `restrictions` in your
query) and they are shown in the grid and on the bars.

```elixir
field :blocked, :boolean, default: false
field :restrictions, :integer, virtual: true, default: 0
```

The `:block` row action updates the task like any other change, so you get
`%GanttEx.Event{type: :task_updated, changes: %{blocked: true}}` and persist
it with the rest of the fields.

Restrictions usually live in their own table. The `:restriction` action
only tells you that the user wants to add one: open your form, and render
the chart with the new count once it is saved.

```elixir
def handle_info({GanttEx, %GanttEx.Event{type: :task_action, action: :restriction, task: task}}, socket),
  do: {:noreply, assign(socket, restriction_form: Planning.new_restriction(task.id))}

def handle_info({GanttEx, %GanttEx.Event{type: :task_action, action: :detail, task: task}}, socket),
  do: {:noreply, push_patch(socket, to: ~p"/plans/#{socket.assigns.plan}/tasks/#{task.id}")}
```

## Filters and columns

`:filters_changed` and `:columns_changed` events carry plain data (atoms,
strings, `Date`s), so they can be stored as user preferences and given back
as `filter_values` and `column_layout`:

```elixir
def mount(_params, _session, socket) do
  prefs = Preferences.get(socket.assigns.current_scope, :gantt)
  {:ok, assign(socket, filter_values: prefs.filters, column_layout: prefs.columns)}
end

def handle_info({GanttEx, %GanttEx.Event{type: :filters_changed, filters: filters}}, socket) do
  Preferences.put(socket.assigns.current_scope, :gantt, filters: filters)
  {:noreply, assign(socket, filter_values: filters)}
end

def handle_info({GanttEx, %GanttEx.Event{type: :columns_changed, columns: layout}}, socket) do
  Preferences.put(socket.assigns.current_scope, :gantt, columns: layout)
  {:noreply, assign(socket, column_layout: layout)}
end
```

Rendering the chart with the same values again does not interrupt the user;
a different value replaces the selection. Stored as JSON, atoms come back
as strings and dates as ISO strings: both are accepted (unknown values are
dropped), so `%{"status" => ["blocked"], "dates" => %{"from" => "2025-01-06"}}`
restores the same filters.

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
