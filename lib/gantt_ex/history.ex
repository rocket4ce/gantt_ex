defmodule GanttEx.History do
  @moduledoc """
  Undo and redo for a `GanttEx.Store`.

  The history keeps snapshots of the store (cheap, thanks to immutable data
  structures). Undoing returns the previous snapshot together with the
  changes that lead to it (see `GanttEx.Store.diff/2`), so they can be
  persisted like any other change.

      iex> store = GanttEx.Store.new!([%{id: 1, text: "A", start_date: ~D[2025-01-01]}])
      iex> history = GanttEx.History.new()
      iex> {:ok, changed, _} = GanttEx.Store.update_task(store, 1, %{text: "B"})
      iex> history = GanttEx.History.record(history, store)
      iex> {:ok, history, restored, [{:task_updated, task, %{changes: changes}}]} = GanttEx.History.undo(history, changed)
      iex> {task.text, changes, GanttEx.History.can_redo?(history)}
      {"A", %{text: "A"}, true}
      iex> {:ok, _history, _store, [{:task_updated, %{text: "B"}, _}]} = GanttEx.History.redo(history, restored)
      iex> GanttEx.History.undo(GanttEx.History.new(), store)
      :empty
  """

  alias GanttEx.Store

  defstruct past: [], future: [], limit: 50

  @type t :: %__MODULE__{past: [Store.t()], future: [Store.t()], limit: pos_integer()}

  @doc """
  Creates an empty history.

  ## Options

    * `:limit` - how many steps are kept. Defaults to `50`.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []), do: %__MODULE__{limit: Keyword.get(opts, :limit, 50)}

  @doc """
  Records `store` as the state before a change. Clears the redo steps.
  """
  @spec record(t(), Store.t()) :: t()
  def record(%__MODULE__{} = history, %Store{} = store) do
    %{history | past: Enum.take([store | history.past], history.limit), future: []}
  end

  @doc """
  Goes back one step from `current`. Returns the restored store and the
  changes from `current` to it, or `:empty`.
  """
  @spec undo(t(), Store.t()) :: {:ok, t(), Store.t(), [Store.change()]} | :empty
  def undo(%__MODULE__{past: []}, _current), do: :empty

  def undo(%__MODULE__{past: [previous | past]} = history, %Store{} = current) do
    {:ok, %{history | past: past, future: [current | history.future]}, previous,
     Store.diff(current, previous)}
  end

  @doc """
  Goes forward one step from `current`, or returns `:empty`.
  """
  @spec redo(t(), Store.t()) :: {:ok, t(), Store.t(), [Store.change()]} | :empty
  def redo(%__MODULE__{future: []}, _current), do: :empty

  def redo(%__MODULE__{future: [next | future]} = history, %Store{} = current) do
    {:ok, %{history | past: [current | history.past], future: future}, next,
     Store.diff(current, next)}
  end

  @doc "Returns `true` when there is something to undo."
  @spec can_undo?(t()) :: boolean()
  def can_undo?(%__MODULE__{past: past}), do: past != []

  @doc "Returns `true` when there is something to redo."
  @spec can_redo?(t()) :: boolean()
  def can_redo?(%__MODULE__{future: future}), do: future != []
end
