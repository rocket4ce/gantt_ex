defmodule GanttEx.Link do
  @moduledoc """
  A dependency between two tasks.

  The four dependency types of DHTMLX Gantt are supported:

  | Type                | DHTMLX code | Meaning                                         |
  | ------------------- | ----------- | ----------------------------------------------- |
  | `:finish_to_start`  | `"0"`       | target starts after the source finishes         |
  | `:start_to_start`   | `"1"`       | target starts after the source starts           |
  | `:finish_to_finish` | `"2"`       | target finishes after the source finishes       |
  | `:start_to_finish`  | `"3"`       | target finishes after the source starts         |

  `:lag` is an integer amount of the chart's duration unit (negative values
  are leads).

  ## Examples

      iex> {:ok, link} = GanttEx.Link.new(%{"id" => 1, "source" => 10, "target" => 11, "type" => "1"})
      iex> {link.source, link.target, link.type}
      {10, 11, :start_to_start}

      iex> {:ok, link} = GanttEx.Link.new(id: 2, source_id: 1, target_id: 2, lag: "2")
      iex> {link.type, link.lag}
      {:finish_to_start, 2}

      iex> GanttEx.Link.new(id: 3, source: 1)
      {:error, {:missing, :target}}
  """

  alias GanttEx.Task

  @types [:finish_to_start, :start_to_start, :finish_to_finish, :start_to_finish]
  @codes %{finish_to_start: "0", start_to_start: "1", finish_to_finish: "2", start_to_finish: "3"}
  @fields [:id, :source, :target, :type, :lag, :readonly, :color]
  @aliases %{source_id: :source, target_id: :target}
  @string_keys Map.new(@fields ++ Map.keys(@aliases), &{Atom.to_string(&1), &1})

  @enforce_keys [:id, :source, :target]
  defstruct id: nil,
            source: nil,
            target: nil,
            type: :finish_to_start,
            lag: 0,
            readonly: false,
            color: nil,
            meta: %{}

  @typedoc "Dependency type."
  @type type :: :finish_to_start | :start_to_start | :finish_to_finish | :start_to_finish

  @typedoc "Which edge of a task bar a link is attached to."
  @type side :: :start | :end

  @type t :: %__MODULE__{
          id: Task.id(),
          source: Task.id(),
          target: Task.id(),
          type: type(),
          lag: integer(),
          readonly: boolean(),
          color: String.t() | nil,
          meta: map()
        }

  @doc """
  Returns the supported link types.

      iex> GanttEx.Link.types()
      [:finish_to_start, :start_to_start, :finish_to_finish, :start_to_finish]
  """
  @spec types() :: [type()]
  def types, do: @types

  @doc """
  Builds a link from a map, keyword list or struct.
  """
  @spec new(map() | keyword() | struct()) :: {:ok, t()} | {:error, Task.error()}
  def new(%__MODULE__{} = link), do: {:ok, link}

  def new(attrs) do
    {known, meta} = split(attrs)

    with {:ok, id} <- fetch(known, :id),
         {:ok, source} <- fetch(known, :source),
         {:ok, target} <- fetch(known, :target) do
      cast(
        %__MODULE__{id: id, source: source, target: target},
        Map.drop(known, [:id, :source, :target]),
        meta
      )
    end
  end

  @doc """
  Like `new/1` but raises `ArgumentError` on invalid attributes.

      iex> GanttEx.Link.new!(id: 1, source: 1, target: 2).type
      :finish_to_start
  """
  @spec new!(map() | keyword() | struct()) :: t()
  def new!(attrs) do
    case new(attrs) do
      {:ok, link} ->
        link

      {:error, reason} ->
        raise ArgumentError, "invalid link #{inspect(reason)}: #{inspect(attrs)}"
    end
  end

  @doc """
  Applies `attrs` on top of an existing link. `:id`, `:source` and `:target`
  cannot be changed.

      iex> link = GanttEx.Link.new!(id: 1, source: 1, target: 2)
      iex> {:ok, link} = GanttEx.Link.change(link, %{"type" => "finish_to_finish", "lag" => "-1"})
      iex> {link.type, link.lag}
      {:finish_to_finish, -1}
  """
  @spec change(t(), map() | keyword()) :: {:ok, t()} | {:error, Task.error()}
  def change(%__MODULE__{} = link, attrs) do
    {known, meta} = split(attrs)
    cast(link, Map.drop(known, [:id, :source, :target]), meta)
  end

  @doc """
  Casts a link type from an atom, a DHTMLX code or a string.

      iex> GanttEx.Link.cast_type("2")
      {:ok, :finish_to_finish}

      iex> GanttEx.Link.cast_type(3)
      {:ok, :start_to_finish}

      iex> GanttEx.Link.cast_type("start_to_start")
      {:ok, :start_to_start}

      iex> GanttEx.Link.cast_type("sideways")
      :error
  """
  @spec cast_type(term()) :: {:ok, type()} | :error
  def cast_type(nil), do: {:ok, :finish_to_start}
  def cast_type(type) when type in @types, do: {:ok, type}
  def cast_type(code) when is_integer(code), do: cast_type(Integer.to_string(code))

  def cast_type(type) when is_binary(type) do
    Enum.find_value(@codes, :error, fn {name, code} ->
      if type == code or type == Atom.to_string(name), do: {:ok, name}
    end)
  end

  def cast_type(_type), do: :error

  @doc """
  Returns the DHTMLX numeric code of a link type.

      iex> GanttEx.Link.code(:start_to_start)
      "1"
  """
  @spec code(type()) :: String.t()
  def code(type), do: Map.fetch!(@codes, type)

  @doc """
  Returns the `{source_side, target_side}` edges a link type connects.

      iex> GanttEx.Link.sides(:finish_to_start)
      {:end, :start}

      iex> GanttEx.Link.sides(:start_to_finish)
      {:start, :end}
  """
  @spec sides(type()) :: {side(), side()}
  def sides(:finish_to_start), do: {:end, :start}
  def sides(:start_to_start), do: {:start, :start}
  def sides(:finish_to_finish), do: {:end, :end}
  def sides(:start_to_finish), do: {:start, :end}

  @doc """
  Returns the link type that connects the given edges. This is how a link
  drawn by dragging from one bar edge to another becomes a dependency.

      iex> GanttEx.Link.type_for(:end, :start)
      :finish_to_start

      iex> GanttEx.Link.type_for(:end, :end)
      :finish_to_finish
  """
  @spec type_for(side(), side()) :: type()
  def type_for(:end, :start), do: :finish_to_start
  def type_for(:start, :start), do: :start_to_start
  def type_for(:end, :end), do: :finish_to_finish
  def type_for(:start, :end), do: :start_to_finish

  @doc """
  Converts the link into a plain map, handy to persist it.

      iex> GanttEx.Link.new!(id: 1, source: 1, target: 2) |> GanttEx.Link.to_map() |> Map.take([:source, :target, :type])
      %{source: 1, target: 2, type: :finish_to_start}
  """
  @spec to_map(t(), keyword()) :: map()
  def to_map(%__MODULE__{} = link, opts \\ []) do
    base = Map.take(link, @fields)

    if Keyword.get(opts, :meta, true), do: Map.merge(link.meta, base), else: base
  end

  defp cast(link, known, meta) do
    Enum.reduce_while(known, {:ok, %{link | meta: Map.merge(link.meta, meta)}}, fn {key, value},
                                                                                   {:ok, acc} ->
      case cast_field(key, value) do
        {:ok, value} -> {:cont, {:ok, Map.put(acc, key, value)}}
        :error -> {:halt, {:error, {:invalid, key}}}
      end
    end)
  end

  defp cast_field(:type, value), do: cast_type(value)
  defp cast_field(:color, value), do: Task.cast_color(value)
  defp cast_field(:readonly, value) when value in [true, "true"], do: {:ok, true}
  defp cast_field(:readonly, value) when value in [false, "false", nil], do: {:ok, false}
  defp cast_field(:lag, nil), do: {:ok, 0}
  defp cast_field(:lag, value) when is_integer(value), do: {:ok, value}
  defp cast_field(:lag, value) when is_float(value), do: {:ok, round(value)}

  defp cast_field(:lag, value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {lag, ""} -> {:ok, lag}
      _ -> :error
    end
  end

  defp cast_field(_key, _value), do: :error

  defp fetch(known, key) do
    case Map.get(known, key) do
      value when value in [nil, ""] -> {:error, {:missing, key}}
      value -> {:ok, value}
    end
  end

  defp split(attrs) when is_list(attrs), do: attrs |> Map.new() |> split()

  defp split(%{__struct__: _} = struct) do
    struct |> Map.from_struct() |> Map.drop([:__meta__]) |> split()
  end

  defp split(attrs) when is_map(attrs) do
    {explicit_meta, attrs} = Map.pop(attrs, :meta, Map.get(attrs, "meta", %{}))
    attrs = Map.delete(attrs, "meta")

    {known, meta} =
      Enum.reduce(attrs, {%{}, %{}}, fn {key, value}, {known, meta} ->
        key = if is_binary(key), do: Map.get(@string_keys, key, key), else: key
        field = Map.get(@aliases, key, key)

        cond do
          match?(%{__struct__: Ecto.Association.NotLoaded}, value) -> {known, meta}
          field in @fields -> {Map.update(known, field, value, &(&1 || value)), meta}
          true -> {known, Map.put(meta, key, value)}
        end
      end)

    {known, Map.merge(meta, if(is_map(explicit_meta), do: explicit_meta, else: %{}))}
  end
end
