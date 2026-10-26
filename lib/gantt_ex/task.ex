defmodule GanttEx.Task do
  @moduledoc """
  A task (row) of the Gantt chart.

  Tasks mirror the DHTMLX Gantt data model:

    * `:id` - unique identifier (integer, string or atom). Required.
    * `:text` - the task name.
    * `:start_date`, `:end_date` - `NaiveDateTime` boundaries (end is exclusive).
    * `:duration` - integer amount of the chart's duration unit (`:day` by default).
    * `:progress` - completion between `0.0` and `1.0`.
    * `:parent` - id of the parent task, `nil` for root tasks.
    * `:type` - `:task`, `:project` (summary task whose dates are computed from
      its children) or `:milestone` (zero-duration event).
    * `:open` - whether the children are expanded initially.
    * `:readonly` - disables editing for this task.
    * `:color`, `:text_color`, `:progress_color` - optional CSS colors.
    * `:calendar_id` - the working-time calendar of the task (see `GanttEx.Calendar`).
    * `:constraint_type`, `:constraint_date` - scheduling constraint used by
      auto-scheduling (see `GanttEx.Scheduler` and `constraint_types/0`).
    * `:planned_start`, `:planned_end` - the baseline (the original plan).
    * `:deadline` - the date the task must be finished by.
    * `:render` - `:split` draws the children of the task on its own row.
    * `:rollup` - also show the task on the rows of its ancestor projects.
    * `:meta` - any additional fields (for custom grid columns, templates, ...).

  Only one or two of `:start_date`, `:end_date` and `:duration` are needed: the
  missing one is computed by `GanttEx.Store` (see `GanttEx.Store.new/3`).

  ## Building tasks

  `new/1` accepts maps (atom or string keys), keyword lists and structs, such
  as Ecto schemas. Unknown fields are kept in `:meta`, and `:parent_id` is
  accepted as an alias of `:parent`:

      iex> {:ok, task} = GanttEx.Task.new(%{"id" => 1, "text" => "Design", "start_date" => "2025-01-06", "duration" => 3, "owner" => "Ana"})
      iex> {task.id, task.text, task.start_date, task.duration, task.meta}
      {1, "Design", ~N[2025-01-06 00:00:00], 3, %{"owner" => "Ana"}}

      iex> {:ok, task} = GanttEx.Task.new(id: 2, parent_id: 1, type: "milestone", start_date: ~D[2025-01-10])
      iex> {task.parent, task.type}
      {1, :milestone}

      iex> GanttEx.Task.new(%{text: "No id"})
      {:error, {:missing, :id}}

      iex> GanttEx.Task.new(%{id: 1, progress: 50})
      {:error, {:invalid, :progress}}
  """

  alias GanttEx.Dates

  @types [:task, :project, :milestone]

  @fields [
    :id,
    :text,
    :start_date,
    :end_date,
    :duration,
    :progress,
    :parent,
    :type,
    :open,
    :readonly,
    :color,
    :text_color,
    :progress_color,
    :calendar_id,
    :constraint_type,
    :constraint_date,
    :planned_start,
    :planned_end,
    :deadline,
    :render,
    :rollup
  ]

  @aliases %{parent_id: :parent}
  @string_keys Map.new(@fields ++ Map.keys(@aliases) ++ [:meta], &{Atom.to_string(&1), &1})

  @enforce_keys [:id]
  defstruct id: nil,
            text: "",
            start_date: nil,
            end_date: nil,
            duration: nil,
            progress: 0.0,
            parent: nil,
            type: :task,
            open: true,
            readonly: false,
            color: nil,
            text_color: nil,
            progress_color: nil,
            calendar_id: nil,
            constraint_type: nil,
            constraint_date: nil,
            planned_start: nil,
            planned_end: nil,
            deadline: nil,
            render: nil,
            rollup: false,
            meta: %{}

  @typedoc "A task or link identifier."
  @type id :: integer() | String.t() | atom()

  @typedoc "The kind of task."
  @type type :: :task | :project | :milestone

  @typedoc """
  A scheduling constraint: as soon/late as possible, start/finish no
  earlier/later than a date, or must start/finish on a date.
  """
  @type constraint :: :asap | :alap | :snet | :snlt | :fnet | :fnlt | :mso | :mfo

  @typedoc "Casting errors returned by `new/1` and `change/2`."
  @type error :: {:missing, atom()} | {:invalid, atom()}

  @type t :: %__MODULE__{
          id: id(),
          text: String.t(),
          start_date: NaiveDateTime.t() | nil,
          end_date: NaiveDateTime.t() | nil,
          duration: non_neg_integer() | nil,
          progress: float(),
          parent: id() | nil,
          type: type(),
          open: boolean(),
          readonly: boolean(),
          color: String.t() | nil,
          text_color: String.t() | nil,
          progress_color: String.t() | nil,
          calendar_id: term(),
          constraint_type: constraint() | nil,
          constraint_date: NaiveDateTime.t() | nil,
          planned_start: NaiveDateTime.t() | nil,
          planned_end: NaiveDateTime.t() | nil,
          deadline: NaiveDateTime.t() | nil,
          render: :split | nil,
          rollup: boolean(),
          meta: map()
        }

  @constraints [:asap, :alap, :snet, :snlt, :fnet, :fnlt, :mso, :mfo]

  @doc """
  Returns the supported constraint types.

      iex> GanttEx.Task.constraint_types()
      [:asap, :alap, :snet, :snlt, :fnet, :fnlt, :mso, :mfo]
  """
  @spec constraint_types() :: [constraint()]
  def constraint_types, do: @constraints

  @doc """
  Casts a constraint type (DHTMLX codes such as `"snet"` or atoms).

      iex> GanttEx.Task.cast_constraint("mso")
      {:ok, :mso}

      iex> GanttEx.Task.cast_constraint("")
      {:ok, nil}
  """
  @spec cast_constraint(term()) :: {:ok, constraint() | nil} | :error
  def cast_constraint(value) when value in [nil, ""], do: {:ok, nil}
  def cast_constraint(value) when value in @constraints, do: {:ok, value}

  def cast_constraint(value) when is_binary(value) do
    case Enum.find(@constraints, &(Atom.to_string(&1) == String.downcase(value))) do
      nil -> :error
      constraint -> {:ok, constraint}
    end
  end

  def cast_constraint(_value), do: :error

  @doc """
  Returns the supported task types.

      iex> GanttEx.Task.types()
      [:task, :project, :milestone]
  """
  @spec types() :: [type()]
  def types, do: @types

  @doc """
  Builds a task from a map, keyword list or struct. See the module docs.
  """
  @spec new(map() | keyword() | struct()) :: {:ok, t()} | {:error, error()}
  def new(%__MODULE__{} = task), do: {:ok, task}

  def new(attrs) do
    {known, meta} = split(attrs)

    with {:ok, id} <- fetch_id(known) do
      cast(%__MODULE__{id: id}, Map.delete(known, :id), meta)
    end
  end

  @doc """
  Like `new/1` but raises `ArgumentError` on invalid attributes.

      iex> GanttEx.Task.new!(id: 1, text: "Kickoff", start_date: ~D[2025-01-01]).text
      "Kickoff"
  """
  @spec new!(map() | keyword() | struct()) :: t()
  def new!(attrs) do
    case new(attrs) do
      {:ok, task} ->
        task

      {:error, reason} ->
        raise ArgumentError, "invalid task #{inspect(reason)}: #{inspect(attrs)}"
    end
  end

  @doc """
  Applies `attrs` on top of an existing task, casting only the given fields.

  The `:id` cannot be changed. Unknown fields are merged into `:meta`.

      iex> task = GanttEx.Task.new!(id: 1, text: "Draft", start_date: ~D[2025-01-01])
      iex> {:ok, task} = GanttEx.Task.change(task, %{"text" => "Final", "progress" => "0.25"})
      iex> {task.text, task.progress}
      {"Final", 0.25}
  """
  @spec change(t(), map() | keyword()) :: {:ok, t()} | {:error, error()}
  def change(%__MODULE__{} = task, attrs) do
    {known, meta} = split(attrs)
    cast(task, Map.delete(known, :id), meta)
  end

  @doc """
  Returns `true` for milestones.

      iex> GanttEx.Task.milestone?(GanttEx.Task.new!(id: 1, type: :milestone))
      true
  """
  @spec milestone?(t()) :: boolean()
  def milestone?(%__MODULE__{type: type}), do: type == :milestone

  @doc """
  Returns `true` for project (summary) tasks.

      iex> GanttEx.Task.project?(GanttEx.Task.new!(id: 1))
      false
  """
  @spec project?(t()) :: boolean()
  def project?(%__MODULE__{type: type}), do: type == :project

  @doc """
  Converts the task into a plain map, handy to persist it.

  `:meta` fields are merged at the top level unless `meta: false` is given.

      iex> task = GanttEx.Task.new!(id: 1, text: "A", start_date: ~D[2025-01-01], duration: 2, priority: :high)
      iex> GanttEx.Task.to_map(task) |> Map.take([:id, :text, :duration, :priority])
      %{id: 1, text: "A", duration: 2, priority: :high}
  """
  @spec to_map(t(), keyword()) :: map()
  def to_map(%__MODULE__{} = task, opts \\ []) do
    base = Map.take(task, @fields)

    if Keyword.get(opts, :meta, true), do: Map.merge(task.meta, base), else: base
  end

  @doc """
  Casts a task type from an atom or string.

      iex> GanttEx.Task.cast_type("project")
      {:ok, :project}

      iex> GanttEx.Task.cast_type(nil)
      {:ok, :task}

      iex> GanttEx.Task.cast_type("epic")
      :error
  """
  @spec cast_type(term()) :: {:ok, type()} | :error
  def cast_type(nil), do: {:ok, :task}
  def cast_type(type) when type in @types, do: {:ok, type}

  def cast_type(type) when is_binary(type) do
    case Enum.find(@types, &(Atom.to_string(&1) == type)) do
      nil -> :error
      type -> {:ok, type}
    end
  end

  def cast_type(_type), do: :error

  # -- casting -----------------------------------------------------------------

  defp cast(task, known, meta) do
    Enum.reduce_while(known, {:ok, %{task | meta: Map.merge(task.meta, meta)}}, fn {key, value},
                                                                                   {:ok, acc} ->
      case cast_field(key, value) do
        {:ok, value} -> {:cont, {:ok, Map.put(acc, key, value)}}
        :error -> {:halt, {:error, {:invalid, key}}}
      end
    end)
  end

  defp cast_field(:text, nil), do: {:ok, ""}
  defp cast_field(:text, text) when is_binary(text), do: {:ok, text}
  defp cast_field(:text, text) when is_atom(text) or is_number(text), do: {:ok, to_string(text)}
  defp cast_field(:text, _text), do: :error

  defp cast_field(key, value)
       when key in [
              :start_date,
              :end_date,
              :constraint_date,
              :planned_start,
              :planned_end,
              :deadline
            ],
       do: Dates.cast(value)

  defp cast_field(:constraint_type, value), do: cast_constraint(value)
  defp cast_field(:render, value) when value in [nil, ""], do: {:ok, nil}
  defp cast_field(:render, value) when value in [:split, "split"], do: {:ok, :split}
  defp cast_field(:render, _value), do: :error
  defp cast_field(:rollup, value), do: cast_boolean(value)
  defp cast_field(:type, value), do: cast_type(value)
  defp cast_field(:parent, value), do: {:ok, cast_parent(value)}
  defp cast_field(:calendar_id, value), do: {:ok, if(value == "", do: nil, else: value)}
  defp cast_field(:duration, value), do: cast_duration(value)
  defp cast_field(:progress, value), do: cast_progress(value)
  defp cast_field(key, value) when key in [:open, :readonly], do: cast_boolean(value)

  defp cast_field(key, value) when key in [:color, :text_color, :progress_color],
    do: cast_color(value)

  defp cast_parent(value) when value in [nil, 0, "0", ""], do: nil
  defp cast_parent(value), do: value

  defp cast_duration(nil), do: {:ok, nil}
  defp cast_duration(value) when is_integer(value) and value >= 0, do: {:ok, value}
  defp cast_duration(value) when is_float(value) and value >= 0, do: {:ok, round(value)}

  defp cast_duration(value) when is_binary(value) do
    case Float.parse(String.trim(value)) do
      {number, ""} -> cast_duration(number)
      _ -> :error
    end
  end

  defp cast_duration(_value), do: :error

  defp cast_progress(nil), do: {:ok, 0.0}

  defp cast_progress(value) when is_number(value) and value >= 0 and value <= 1,
    do: {:ok, value / 1}

  defp cast_progress(value) when is_binary(value) do
    case Float.parse(String.trim(value)) do
      {number, ""} -> cast_progress(number)
      _ -> :error
    end
  end

  defp cast_progress(_value), do: :error

  defp cast_boolean(value) when value in [true, "true", 1, "1"], do: {:ok, true}
  defp cast_boolean(value) when value in [false, "false", 0, "0", nil], do: {:ok, false}
  defp cast_boolean(_value), do: :error

  @doc false
  # Colors are interpolated into inline styles, so only allow characters that
  # cannot escape the CSS property (no `;`, `:`, quotes or `url(...)`).
  def cast_color(nil), do: {:ok, nil}
  def cast_color(""), do: {:ok, nil}

  def cast_color(color) when is_binary(color) do
    if Regex.match?(~r/^[#a-zA-Z0-9(),.%\/+\s-]{1,64}$/, color) and
         not (String.downcase(color) =~ ~r/url\s*\(|expression\s*\(/) do
      {:ok, color}
    else
      :error
    end
  end

  def cast_color(_color), do: :error

  defp fetch_id(%{id: id}) when not is_nil(id) and id != "", do: {:ok, id}
  defp fetch_id(_known), do: {:error, {:missing, :id}}

  # Splits arbitrary attributes into known (atom-keyed) fields and meta.
  @doc false
  def split(attrs) when is_list(attrs), do: attrs |> Map.new() |> split()

  def split(%{__struct__: _} = struct) do
    struct
    |> Map.from_struct()
    |> Map.drop([:__meta__])
    |> Map.reject(fn {_key, value} -> not_loaded?(value) end)
    |> split()
  end

  def split(attrs) when is_map(attrs) do
    {explicit_meta, attrs} = pop_meta(attrs)

    {known, meta} =
      Enum.reduce(attrs, {%{}, %{}}, fn {key, value}, {known, meta} ->
        case normalize_key(key) do
          nil -> {known, Map.put(meta, key, value)}
          field -> {Map.update(known, field, value, &prefer_canonical(&1, value, key)), meta}
        end
      end)

    {known, Map.merge(meta, explicit_meta)}
  end

  defp pop_meta(attrs) do
    case Map.pop(attrs, :meta) do
      {nil, attrs} ->
        case Map.pop(attrs, "meta") do
          {meta, attrs} when is_map(meta) -> {meta, attrs}
          {_meta, attrs} -> {%{}, attrs}
        end

      {meta, attrs} when is_map(meta) ->
        {meta, attrs}

      {_meta, attrs} ->
        {%{}, attrs}
    end
  end

  defp normalize_key(key) when is_binary(key),
    do: key |> then(&Map.get(@string_keys, &1)) |> canonical()

  defp normalize_key(key) when is_atom(key), do: canonical(key)
  defp normalize_key(_key), do: nil

  defp canonical(nil), do: nil
  defp canonical(:meta), do: nil
  defp canonical(key) when is_map_key(@aliases, key), do: Map.fetch!(@aliases, key)
  defp canonical(key) when key in @fields, do: key
  defp canonical(_key), do: nil

  # When both `parent` and `parent_id` are given, `parent` wins.
  defp prefer_canonical(existing, value, key) when key in [:parent, "parent"],
    do: value || existing

  defp prefer_canonical(existing, _value, _key), do: existing

  defp not_loaded?(%{__struct__: Ecto.Association.NotLoaded}), do: true
  defp not_loaded?(_value), do: false
end
