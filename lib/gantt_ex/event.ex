defmodule GanttEx.Event do
  @moduledoc """
  Notifications sent by `GanttEx.Live.Gantt` to the LiveView that renders it.

  Every change made by the user (dragging a bar, editing a task in the
  lightbox, drawing a dependency, ...) is applied to the chart immediately and
  reported to the parent LiveView process as a message:

      {GanttEx, %GanttEx.Event{}}

  so the parent can persist it:

      def handle_info({GanttEx, %GanttEx.Event{type: :task_updated, task: task}}, socket) do
        Planning.update_task!(task.id, GanttEx.Task.to_map(task))
        {:noreply, socket}
      end

      def handle_info({GanttEx, %GanttEx.Event{}}, socket), do: {:noreply, socket}

  ## Types

    * `:task_created` - `:task` holds the new task. Its id is temporary (a
      string starting with `"gx-"`) unless it came from your own data;
      re-render the component with the persisted tasks to replace it.
    * `:task_updated` - `:task` holds the updated task and `:changes` the
      changed fields with their new values. Also sent for parent projects whose
      dates were recomputed.
    * `:task_deleted` - one event per deleted task (descendants first).
    * `:task_moved` - the task changed position in the tree: `:parent`, `:index`
      and `:siblings` (ordered ids of the new siblings) describe where.
    * `:link_created`, `:link_updated`, `:link_deleted` - `:link` holds the link,
      `:changes` the changed fields for updates.
    * `:branch_requested` - the user expanded a task with `has_children: true`
      whose children are not loaded yet: load them and render the component
      with them (dynamic loading).
    * `:task_selected` - the user selected a task (`:task`). `:selection` holds
      the ids of every selected task (Ctrl/Cmd+click and Shift+click select
      several).
    * `:filters_changed` - the user changed the search or the filters.
      `:filters` holds the normalized values (see `GanttEx.Filter`), which
      can be given back as `:filter_values` to restore them:

          %{search: "slab", status: [:blocked], responsible: ["uuid-1", nil],
            dates: %{from: ~D[2025-01-01], to: ~D[2025-01-31]}}

  `:gantt_id` is the `id` of the component that sent the event, which allows
  several charts in the same LiveView.
  """

  alias GanttEx.{Link, Store, Task}

  defstruct [
    :gantt_id,
    :type,
    :task,
    :link,
    :changes,
    :parent,
    :index,
    :siblings,
    :selection,
    :filters
  ]

  @type type ::
          :task_created
          | :task_updated
          | :task_deleted
          | :task_moved
          | :link_created
          | :link_updated
          | :link_deleted
          | :task_selected
          | :branch_requested
          | :filters_changed

  @type t :: %__MODULE__{
          gantt_id: String.t(),
          type: type(),
          task: Task.t() | nil,
          link: Link.t() | nil,
          changes: map() | nil,
          parent: Task.id() | nil,
          index: non_neg_integer() | nil,
          siblings: [Task.id()] | nil,
          selection: [Task.id()] | nil,
          filters: GanttEx.Filter.values() | nil
        }

  @doc """
  Builds an event from a `t:GanttEx.Store.change/0`.

      iex> task = GanttEx.Task.new!(id: 1, start_date: ~D[2025-01-01])
      iex> event = GanttEx.Event.from_change("gantt", {:task_updated, task, %{changes: %{text: "A"}}})
      iex> {event.gantt_id, event.type, event.task.id, event.changes}
      {"gantt", :task_updated, 1, %{text: "A"}}

      iex> link = GanttEx.Link.new!(id: 9, source: 1, target: 2)
      iex> GanttEx.Event.from_change("gantt", {:link_deleted, link, %{}}).link.id
      9
  """
  @spec from_change(String.t(), Store.change()) :: t()
  def from_change(gantt_id, {type, %Link{} = link, details}) do
    %__MODULE__{gantt_id: gantt_id, type: type, link: link, changes: details[:changes]}
  end

  def from_change(gantt_id, {type, %Task{} = task, details}) do
    %__MODULE__{
      gantt_id: gantt_id,
      type: type,
      task: task,
      changes: details[:changes],
      parent: details[:parent],
      index: details[:index],
      siblings: details[:siblings]
    }
  end

  @doc """
  Sends the event to `pid` as `{GanttEx, event}`.
  """
  @spec notify(pid(), t()) :: t()
  def notify(pid, %__MODULE__{} = event) do
    send(pid, {GanttEx, event})
    event
  end
end
