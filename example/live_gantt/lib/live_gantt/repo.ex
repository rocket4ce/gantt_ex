defmodule LiveGantt.Repo do
  use Ecto.Repo,
    otp_app: :live_gantt,
    adapter: Ecto.Adapters.Postgres
end
