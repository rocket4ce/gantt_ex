defmodule GanttEx.Test.GanttLive do
  @moduledoc false
  # Hosts a GanttEx.Live.Gantt in tests and forwards its events to the test process.
  use Phoenix.LiveView

  @impl true
  def mount(_params, session, socket) do
    {:ok,
     assign(socket,
       tasks: Map.get(session, "tasks", []),
       links: Map.get(session, "links", []),
       opts: Map.get(session, "opts", %{}),
       test_pid: Map.fetch!(session, "test_pid")
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component
      module={GanttEx.Live.Gantt}
      id="gantt"
      tasks={@tasks}
      links={@links}
      today={~N[2025-01-08 10:00:00]}
      {@opts}
    >
      <:column field={:text} tree />
      <:column field={:start_date} />
      <:column field={:end_date} />
      <:column :let={task} field={:owner} label="Owner" editor={:text}>
        <span class="owner">{task.meta[:owner]}</span>
      </:column>
      <:column field={:add} />
    </.live_component>
    """
  end

  @impl true
  def handle_info({GanttEx, event}, socket) do
    send(socket.assigns.test_pid, {:gantt_event, event})
    {:noreply, socket}
  end

  def handle_info({:run, fun}, socket) do
    fun.()
    {:noreply, socket}
  end

  def handle_info({:assign, assigns}, socket) do
    {:noreply, assign(socket, assigns)}
  end
end
