defmodule LiveGantt.Planning do
  @moduledoc """
  Persistence for the Gantt chart.

  `apply_event/1` stores every change reported by `GanttEx.Live.Gantt`
  (see `GanttEx.Event`), which is all an application needs to keep a chart in
  sync with its database.
  """
  import Ecto.Query, warn: false

  alias GanttEx.Event
  alias LiveGantt.Planning.{Link, Task}
  alias LiveGantt.Repo

  @doc "Returns all tasks in display order."
  def list_tasks do
    Repo.all(from t in Task, order_by: [asc: t.position, asc: t.inserted_at])
  end

  @doc "Returns all links."
  def list_links do
    Repo.all(from l in Link, order_by: [asc: l.inserted_at])
  end

  @doc "Creates a task."
  def create_task(attrs, id \\ nil) do
    %Task{id: uuid(id)} |> Task.changeset(attrs) |> Repo.insert()
  end

  @doc "Creates a link."
  def create_link(attrs, id \\ nil) do
    %Link{id: uuid(id)} |> Link.changeset(attrs) |> Repo.insert()
  end

  # New tasks come with temporary ids ("gx-..."), but undoing a deletion
  # brings records back with their original UUID, which links reference.
  defp uuid(id) do
    case id && Ecto.UUID.cast(id) do
      {:ok, uuid} -> uuid
      _ -> nil
    end
  end

  @doc "Deletes every task and link."
  def reset! do
    Repo.delete_all(Link)
    Repo.delete_all(Task)
    :ok
  end

  @doc """
  Persists a change reported by the chart. Returns `:ok` or `{:error, reason}`.
  """
  def apply_event(%Event{type: :task_created, task: task}) do
    task
    |> Map.from_struct()
    |> task_attrs()
    |> Map.put(:position, next_position(task.parent))
    |> create_task(task.id)
    |> result()
  end

  def apply_event(%Event{type: :task_updated, task: task, changes: changes}) do
    with {:ok, record} <- fetch(Task, task.id) do
      record |> Task.changeset(task_attrs(changes)) |> Repo.update() |> result()
    end
  end

  def apply_event(%Event{type: :task_deleted, task: task}) do
    delete(Task, task.id)
  end

  def apply_event(%Event{type: :task_moved, task: task, parent: parent, siblings: siblings}) do
    Repo.transact(fn ->
      with {:ok, record} <- fetch(Task, task.id),
           {:ok, _record} <- record |> Task.changeset(%{parent_id: parent}) |> Repo.update() do
        siblings
        |> Enum.filter(&match?({:ok, _}, Ecto.UUID.cast(&1)))
        |> Enum.with_index()
        |> Enum.each(fn {id, index} ->
          Repo.update_all(from(t in Task, where: t.id == ^id), set: [position: index])
        end)

        {:ok, :moved}
      end
    end)
    |> result()
  end

  def apply_event(%Event{type: :link_created, link: link}) do
    %{source_id: link.source, target_id: link.target, type: link.type, lag: link.lag}
    |> create_link(link.id)
    |> result()
  end

  def apply_event(%Event{type: :link_updated, link: link, changes: changes}) do
    with {:ok, record} <- fetch(Link, link.id) do
      record |> Link.changeset(Map.take(changes, [:type, :lag])) |> Repo.update() |> result()
    end
  end

  def apply_event(%Event{type: :link_deleted, link: link}), do: delete(Link, link.id)

  def apply_event(%Event{}), do: :ok

  # GanttEx fields -> schema fields. The end date is derived from the duration.
  defp task_attrs(fields) do
    {meta, fields} = Map.pop(fields, :meta, %{})
    {parent, fields} = Map.pop(fields, :parent, :unchanged)

    fields
    |> Map.take(
      ~w(text type start_date duration progress open owner planned_start planned_end deadline constraint_type constraint_date)a
    )
    |> then(fn attrs ->
      if parent == :unchanged, do: attrs, else: Map.put(attrs, :parent_id, parent)
    end)
    |> then(fn attrs ->
      case Map.get(meta, :owner, Map.get(meta, "owner")) do
        nil -> attrs
        owner -> Map.put(attrs, :owner, owner)
      end
    end)
  end

  defp next_position(parent) do
    query = from t in Task, select: max(t.position)

    query =
      if parent,
        do: where(query, [t], t.parent_id == ^parent),
        else: where(query, [t], is_nil(t.parent_id))

    (Repo.one(query) || -1) + 1
  end

  # Ids that are not UUIDs (such as temporary "gx-..." ids) are not persisted yet.
  defp fetch(schema, id) do
    with {:ok, uuid} <- Ecto.UUID.cast(id),
         %{} = record <- Repo.get(schema, uuid) do
      {:ok, record}
    else
      _ -> {:error, :not_found}
    end
  end

  defp delete(schema, id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} ->
        Repo.delete_all(from r in schema, where: r.id == ^uuid)
        :ok

      :error ->
        :ok
    end
  end

  defp result({:ok, _}), do: :ok
  defp result({:error, reason}), do: {:error, reason}
end
