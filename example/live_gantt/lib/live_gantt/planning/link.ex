defmodule LiveGantt.Planning.Link do
  @moduledoc "A persisted dependency between two tasks (see `GanttEx.Link`)."
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "links" do
    field :type, Ecto.Enum,
      values: [:finish_to_start, :start_to_start, :finish_to_finish, :start_to_finish],
      default: :finish_to_start

    field :lag, :integer, default: 0

    belongs_to :source, LiveGantt.Planning.Task
    belongs_to :target, LiveGantt.Planning.Task

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(link, attrs) do
    link
    |> cast(attrs, [:type, :lag, :source_id, :target_id])
    |> validate_required([:type, :source_id, :target_id])
    |> foreign_key_constraint(:source_id)
    |> foreign_key_constraint(:target_id)
    |> unique_constraint([:source_id, :target_id, :type])
  end
end
