defmodule LiveGantt.Repo.Migrations.CreatePlanning do
  use Ecto.Migration

  def change do
    create table(:tasks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :text, :string, null: false
      add :type, :string, null: false, default: "task"
      add :start_date, :naive_datetime, null: false
      add :duration, :integer, null: false, default: 1
      add :progress, :float, null: false, default: 0.0
      add :open, :boolean, null: false, default: true
      add :position, :integer, null: false, default: 0
      add :owner, :string
      add :parent_id, references(:tasks, type: :binary_id, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:tasks, [:parent_id, :position])

    create table(:links, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :type, :string, null: false, default: "finish_to_start"
      add :lag, :integer, null: false, default: 0
      add :source_id, references(:tasks, type: :binary_id, on_delete: :delete_all), null: false
      add :target_id, references(:tasks, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:links, [:source_id])
    create index(:links, [:target_id])
    create unique_index(:links, [:source_id, :target_id, :type])
  end
end
