defmodule GanttEx.Resource do
  @moduledoc """
  A resource (a person, a team, a machine...) that tasks are assigned to.

    * `:id` - identifier referenced by task assignments. Required.
    * `:text` - display name.
    * `:capacity` - how many units it can work per working day (8 hours by
      default). Assignments use the same units.
    * `:color` - an optional CSS color.

  Tasks reference resources in their `:resources` field (see
  `cast_assignments/1`), and `GanttEx.ResourceLoad` computes how loaded each
  resource is.

      iex> {:ok, resource} = GanttEx.Resource.new(%{"id" => "ana", "text" => "Ana", "capacity" => "6"})
      iex> {resource.id, resource.text, resource.capacity}
      {"ana", "Ana", 6}

      iex> GanttEx.Resource.new(text: "Nobody")
      {:error, {:missing, :id}}
  """

  alias GanttEx.Task

  defstruct [:id, text: "", capacity: 8, color: nil]

  @type t :: %__MODULE__{
          id: Task.id(),
          text: String.t(),
          capacity: number(),
          color: String.t() | nil
        }

  @typedoc "A task assignment: the resource and the units per working day (nil = full capacity)."
  @type assignment :: %{id: Task.id(), value: number() | nil}

  @doc "Builds a resource from a map, keyword list or struct."
  @spec new(map() | keyword() | t()) :: {:ok, t()} | {:error, term()}
  def new(%__MODULE__{} = resource), do: {:ok, resource}
  def new(attrs) when is_list(attrs), do: attrs |> Map.new() |> new()

  def new(%{__struct__: _} = struct), do: struct |> Map.from_struct() |> new()

  def new(attrs) when is_map(attrs) do
    get = fn key -> Map.get(attrs, key, Map.get(attrs, Atom.to_string(key))) end

    with {:ok, id} <- fetch_id(get.(:id)),
         {:ok, capacity} <- cast_number(get.(:capacity) || 8) |> or_error(:capacity),
         {:ok, color} <- Task.cast_color(get.(:color)) |> or_error(:color) do
      {:ok,
       %__MODULE__{
         id: id,
         text: to_string(get.(:text) || get.(:name) || id),
         capacity: capacity,
         color: color
       }}
    end
  end

  @doc "Like `new/1` but raises `ArgumentError`."
  @spec new!(map() | keyword() | t()) :: t()
  def new!(attrs) do
    case new(attrs) do
      {:ok, resource} ->
        resource

      {:error, reason} ->
        raise ArgumentError, "invalid resource #{inspect(reason)}: #{inspect(attrs)}"
    end
  end

  @doc """
  Casts task assignments: a list of resource ids, or of maps with an id and a
  value (`%{resource_id: 1, value: 4}`, `%{"id" => 1, "value" => "4"}`...).

      iex> GanttEx.Resource.cast_assignments([1, %{resource_id: 2, value: 4}, %{"id" => "3", "value" => "2.5"}])
      {:ok, [%{id: 1, value: nil}, %{id: 2, value: 4}, %{id: "3", value: 2.5}]}

      iex> GanttEx.Resource.cast_assignments(nil)
      {:ok, []}

      iex> GanttEx.Resource.cast_assignments([%{value: 1}])
      :error
  """
  @spec cast_assignments(term()) :: {:ok, [assignment()]} | :error
  def cast_assignments(nil), do: {:ok, []}

  def cast_assignments(list) when is_list(list) do
    Enum.reduce_while(list, {:ok, []}, fn item, {:ok, acc} ->
      case cast_assignment(item) do
        {:ok, assignment} -> {:cont, {:ok, [assignment | acc]}}
        :error -> {:halt, :error}
      end
    end)
    |> case do
      {:ok, acc} -> {:ok, acc |> Enum.reverse() |> Enum.uniq_by(& &1.id)}
      :error -> :error
    end
  end

  def cast_assignments(_value), do: :error

  defp cast_assignment(%{} = map) do
    get = fn key -> Map.get(map, key, Map.get(map, Atom.to_string(key))) end
    id = get.(:resource_id) || get.(:id)
    value = get.(:value)

    with false <- is_nil(id),
         {:ok, value} <-
           if(is_nil(value) or value == "", do: {:ok, nil}, else: cast_number(value)) do
      {:ok, %{id: id, value: value}}
    else
      _ -> :error
    end
  end

  defp cast_assignment(id) when is_integer(id) or is_binary(id) or is_atom(id),
    do: {:ok, %{id: id, value: nil}}

  defp cast_assignment(_item), do: :error

  defp fetch_id(id) when id in [nil, ""], do: {:error, {:missing, :id}}
  defp fetch_id(id), do: {:ok, id}

  defp cast_number(value) when is_number(value) and value >= 0, do: {:ok, value}

  defp cast_number(value) when is_binary(value) do
    case Float.parse(String.trim(value)) do
      {number, ""} -> cast_number(if number == trunc(number), do: trunc(number), else: number)
      _ -> :error
    end
  end

  defp cast_number(_value), do: :error

  defp or_error({:ok, value}, _field), do: {:ok, value}
  defp or_error(:error, field), do: {:error, {:invalid, field}}
end
