defmodule LiveGantt.Repo.Migrations.AddPlanningFields do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add :planned_start, :naive_datetime
      add :planned_end, :naive_datetime
      add :deadline, :naive_datetime
      add :constraint_type, :string
      add :constraint_date, :naive_datetime
    end
  end
end
