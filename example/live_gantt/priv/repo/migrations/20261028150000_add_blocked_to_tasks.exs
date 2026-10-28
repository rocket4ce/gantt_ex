defmodule LiveGantt.Repo.Migrations.AddBlockedToTasks do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add :blocked, :boolean, null: false, default: false
    end
  end
end
