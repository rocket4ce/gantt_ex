{:ok, _} =
  Supervisor.start_link(
    [{Phoenix.PubSub, name: GanttEx.Test.PubSub}, GanttEx.Test.Endpoint],
    strategy: :one_for_one
  )

ExUnit.start()
