defmodule GanttEx.LiveCase do
  @moduledoc false
  # Helpers to test GanttEx.Live.Gantt hosted by GanttEx.Test.GanttLive.
  use ExUnit.CaseTemplate

  import Phoenix.LiveViewTest

  @endpoint GanttEx.Test.Endpoint

  using do
    quote do
      import Phoenix.LiveViewTest
      import GanttEx.LiveCase

      @endpoint GanttEx.Test.Endpoint
    end
  end

  setup do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc "Sample project: a project with two tasks, a milestone and a dependency."
  def sample_tasks do
    [
      %{id: 1, text: "Website", type: :project, open: true},
      %{
        id: 2,
        text: "Design",
        parent: 1,
        start_date: ~D[2025-01-06],
        duration: 3,
        progress: 0.5,
        owner: "Ana"
      },
      %{id: 3, text: "Build", parent: 1, start_date: ~D[2025-01-09], duration: 5, owner: "Luis"},
      %{id: 4, text: "Launch", type: :milestone, start_date: ~D[2025-01-16]}
    ]
  end

  def sample_links do
    [%{id: 1, source: 2, target: 3}, %{id: 2, source: 3, target: 4}]
  end

  @doc """
  Mounts the chart. Options are given to the component as attributes, but
  `:row_actions`, which adds an `:actions` column with these actions, and
  `extra_columns: true`, which adds hidden `:wbs` and `:cost` columns.
  """
  def mount_gantt(conn, opts \\ []) do
    {tasks, opts} = Keyword.pop(opts, :tasks, sample_tasks())
    {links, opts} = Keyword.pop(opts, :links, sample_links())
    {row_actions, opts} = Keyword.pop(opts, :row_actions)
    {actions_reveal, opts} = Keyword.pop(opts, :actions_reveal, :hover)
    {extra_columns, opts} = Keyword.pop(opts, :extra_columns, false)

    live_isolated(conn, GanttEx.Test.GanttLive,
      session: %{
        "tasks" => tasks,
        "links" => links,
        "opts" => Map.new(opts),
        "row_actions" => row_actions,
        "actions_reveal" => actions_reveal,
        "extra_columns" => extra_columns,
        "test_pid" => self()
      }
    )
  end

  @doc "Runs `fun` inside the LiveView process (as the parent would) and waits for it."
  def run_in_parent(view, fun) do
    send(view.pid, {:run, fun})
    # once for the message, once for the send_update it triggers
    _ = :sys.get_state(view.pid)
    _ = :sys.get_state(view.pid)
    :ok
  end

  @doc "Waits for an event sent by the chart to its parent."
  defmacro assert_gantt_event(pattern, timeout \\ 500) do
    quote do
      assert_receive {:gantt_event, unquote(pattern)}, unquote(timeout)
    end
  end
end
