defmodule LiveGantt.Planning.Task do
  @moduledoc """
  A persisted Gantt task. Field names follow `GanttEx.Task`, so records can be
  given straight to `GanttEx.Live.Gantt` (`owner` and `position` end up in
  the task `:meta`).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "tasks" do
    field :text, :string
    field :type, Ecto.Enum, values: [:task, :project, :milestone], default: :task
    field :start_date, :naive_datetime
    field :duration, :integer, default: 1
    field :progress, :float, default: 0.0
    field :open, :boolean, default: true
    field :position, :integer, default: 0
    field :owner, :string

    belongs_to :parent, __MODULE__

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(task, attrs) do
    task
    |> cast(attrs, [
      :text,
      :type,
      :start_date,
      :duration,
      :progress,
      :open,
      :position,
      :owner,
      :parent_id
    ])
    |> validate_required([:text, :type, :start_date, :duration])
    |> validate_length(:text, max: 255)
    |> validate_number(:duration, greater_than_or_equal_to: 0)
    |> validate_number(:progress, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
    |> foreign_key_constraint(:parent_id)
  end
end
