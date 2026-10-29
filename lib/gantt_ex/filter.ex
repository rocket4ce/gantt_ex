defmodule GanttEx.Filter do
  @moduledoc """
  Search and filters for the tasks of a chart.

  `GanttEx.Live.Gantt` offers a search input and a filter panel built from
  its `:filters` attribute. This module holds their logic, so it can be used
  and tested without LiveView: it normalizes filter *definitions* (what is
  offered) and *values* (what is selected), and finds the matching tasks.

  ## Definitions

  The built-in filters are given by name:

    * `:search` - the text or the WBS code of the tasks, ignoring case and
      accents. A WBS code such as `"1.2"` also matches the tasks below it.
    * `:status` - not started, in progress, completed, overdue (not
      complete and past its end or its deadline), critical (only offered
      while the critical path is shown), blocked and with open restrictions
      (see `GanttEx.Task`)
    * `:type` - tasks, projects and milestones
    * `:dates` - tasks overlapping a range of days
    * `:lookahead` - tasks overlapping the next weeks (Last Planner
      lookahead): from the start of the current week (`:week_start` of the
      chart) and as many weeks as chosen. The chart offers it as its own
      toolbar menu and shows only those weeks. Not in the defaults; the
      weeks offered can be changed with `%{id: :lookahead, weeks: [2, 4, 6]}`.

  Custom filters are maps:

      %{
        id: :responsible,
        label: "Responsible",
        field: :responsible_id,
        options: [
          {"Unassigned", nil},
          %{label: "Ana Pérez", value: 1, image: "/avatars/ana.png", hint: "Site manager"},
          %{label: "Concrete Ltd.", value: 2, color: "#0ea5e9"}
        ],
        multiple: true,
        searchable: true,
        placeholder: "Search people"
      }

    * `:id` (required) - an atom or a string, the key of the filter in the values.
    * `:label` - defaults to the id, humanized.
    * `:field` - a task field, a `:meta` key or a 1-arity function returning
      the value (or the list of values) of a task. Defaults to the id.
      `:resources` is the list of the assigned resource ids.
    * `:options` - `{label, value}` tuples or maps with `:label`, `:value`
      and optionally `:image` (the URL of a small avatar or logo), `:color`
      (a CSS color shown as a dot) and `:hint` (a secondary text). The `nil`
      value matches tasks without value (such as "Unassigned").
    * `:multiple` - several options can be selected. Defaults to `true`.
    * `:searchable` - the options can be searched as you type. Defaults to
      `true` with more than 8 options.
    * `:placeholder` - the placeholder of the search input.

  Built-in filters can also be given as maps to change their `:label`, such
  as `%{id: :status, label: "Estado"}`.

  ## Values

  A map keyed by filter id, as returned by `normalize/2`: only the active
  filters are present.

      %{
        search: "slab",
        status: [:overdue, :blocked],
        type: [:task],
        dates: %{from: ~D[2025-01-01], to: ~D[2025-01-31]},
        lookahead: 3,
        responsible: [1, nil]
      }

  The values selected in a filter combine with OR, and the filters combine
  with AND. When the value of a task is a list (such as its resources), any
  of them can match.

  ## Example

      iex> labels = GanttEx.I18n.labels("en")
      iex> filters = GanttEx.Filter.definitions([:search, :status], labels)
      iex> store = GanttEx.Store.new!([
      ...>   %{id: 1, text: "Structure", type: :project},
      ...>   %{id: 2, text: "Losa de hormigón", parent: 1, start_date: ~D[2025-01-06], blocked: true},
      ...>   %{id: 3, text: "Hormigón muros", parent: 1, start_date: ~D[2025-01-08]},
      ...>   %{id: 4, text: "Paint", start_date: ~D[2025-01-10]}
      ...> ])
      iex> values = GanttEx.Filter.normalize(%{"search" => "HORMIGON ", "status" => ["blocked"]}, filters)
      iex> values
      %{search: "HORMIGON", status: [:blocked]}
      iex> {visible, matched} = GanttEx.Filter.visible(store, filters, values)
      iex> {Enum.sort(visible), matched}
      {[1, 2], 1}
  """

  alias GanttEx.{Dates, Store, Task, TaskForm}

  @defaults [:search, :status, :type, :dates]
  @builtins @defaults ++ [:lookahead]
  @lookahead_weeks [1, 2, 3, 4, 6]
  @statuses [:not_started, :in_progress, :completed, :overdue, :critical, :blocked, :restricted]
  @none "__none__"
  @searchable_above 8

  @typedoc "The kind of a filter: one of the built-in ones, or `:options` for custom filters."
  @type kind :: :search | :status | :type | :dates | :lookahead | :options

  @typedoc "A normalized option."
  @type option :: %{
          required(:value) => term(),
          required(:key) => String.t(),
          required(:label) => String.t(),
          required(:image) => String.t() | nil,
          required(:color) => String.t() | nil,
          required(:hint) => String.t() | nil,
          optional(:icon) => atom()
        }

  @typedoc "A normalized filter definition, as returned by `definitions/3`."
  @type definition :: %{
          id: atom() | String.t(),
          kind: kind(),
          label: String.t(),
          field: atom() | String.t() | (Task.t() -> term()) | nil,
          options: [option()],
          multiple: boolean(),
          searchable: boolean(),
          placeholder: String.t() | nil
        }

  @typedoc "Filter values keyed by filter id (see the module docs)."
  @type values :: %{optional(atom() | String.t()) => term()}

  @typedoc """
  What matching needs to know besides the tasks:

    * `:today` - the current date, for `:overdue` and `:lookahead`. Defaults to now.
    * `:week_start` - the first ISO day of the week, for `:lookahead`. Defaults to `1`.
    * `:unit` - the duration unit, to know when a deadline is past. Defaults to `:day`.
    * `:analysis` - a `GanttEx.CriticalPath.analyze/1` result, for `:critical`.
    * `:wbs` - the WBS codes (`GanttEx.Store.wbs_codes/1`), for the search.
    * `:index` - a `search_index/2`, to avoid normalizing texts on every search.
    * `:filter` - a 1-arity function that must also return `true` (the
      `:filter` attribute of the chart).
  """
  @type context :: %{
          optional(:today) => NaiveDateTime.t(),
          optional(:unit) => Dates.unit(),
          optional(:week_start) => 1..7,
          optional(:analysis) => map() | nil,
          optional(:wbs) => %{Task.id() => String.t()},
          optional(:index) => search_index(),
          optional(:filter) => (Task.t() -> boolean()) | nil
        }

  @typedoc "The normalized text of every task, see `search_index/2`."
  @type search_index :: %{Task.id() => {String.t(), String.t()}}

  @doc """
  Returns the default filters: `[:search, :status, :type, :dates]`.
  """
  @spec defaults() :: [atom()]
  def defaults, do: @defaults

  @doc """
  Returns the statuses of the `:status` filter.

      iex> GanttEx.Filter.statuses()
      [:not_started, :in_progress, :completed, :overdue, :critical, :blocked, :restricted]
  """
  @spec statuses() :: [atom()]
  def statuses, do: @statuses

  # -- definitions -------------------------------------------------------------

  @doc """
  Normalizes the filters offered by a chart (see the module docs).

  `false`, `nil` and `[]` offer no filters. Labels come from
  `GanttEx.I18n.labels/1`.

  ## Options

    * `:critical` - offer the `:critical` status. Defaults to `false`.

  ## Examples

      iex> labels = GanttEx.I18n.labels("en")
      iex> [status, owner] = GanttEx.Filter.definitions([:status, %{id: :owner, options: [{"Ana", 1}, {"Luis", 2}]}], labels)
      iex> Enum.map(status.options, & &1.value)
      [:not_started, :in_progress, :completed, :overdue, :blocked, :restricted]
      iex> {owner.kind, owner.label, owner.field, owner.multiple, owner.searchable}
      {:options, "Owner", :owner, true, false}
      iex> GanttEx.Filter.definitions(false, labels)
      []
  """
  @spec definitions(list() | boolean() | nil, map(), keyword()) :: [definition()]
  def definitions(filters, labels, opts \\ [])
  def definitions(filters, _labels, _opts) when filters in [nil, false, []], do: []
  def definitions(true, labels, opts), do: definitions(@defaults, labels, opts)

  def definitions(filters, labels, opts) when is_list(filters) do
    filters
    |> Enum.map(&definition(&1, labels, opts))
    |> Enum.uniq_by(& &1.id)
  end

  defp definition(id, labels, opts) when id in @builtins, do: builtin(id, labels, opts)

  defp definition(%{id: :lookahead, weeks: weeks} = map, labels, opts) when is_list(weeks) do
    weeks = weeks |> Enum.filter(&(is_integer(&1) and &1 > 0)) |> Enum.uniq() |> Enum.sort()

    map
    |> Map.delete(:weeks)
    |> definition(labels, opts)
    |> Map.put(:options, lookahead_options(weeks, labels))
  end

  defp definition(%{id: id} = map, labels, opts)
       when id in @builtins and not is_map_key(map, :options) and not is_map_key(map, :field) do
    id
    |> builtin(labels, opts)
    |> Map.merge(Map.take(map, [:label, :placeholder]))
  end

  defp definition(%{id: id} = map, _labels, _opts) when is_atom(id) or is_binary(id) do
    options = map |> Map.get(:options, []) |> Enum.map(&option/1)

    %{
      id: id,
      kind: :options,
      label: to_string(Map.get(map, :label) || humanize(id)),
      field: Map.get(map, :field, id),
      options: options,
      multiple: Map.get(map, :multiple, true),
      searchable: Map.get(map, :searchable, length(options) > @searchable_above),
      placeholder: Map.get(map, :placeholder)
    }
  end

  defp definition(other, _labels, _opts) do
    raise ArgumentError,
          "invalid filter #{inspect(other)}: expected one of #{inspect(@builtins)} " <>
            "or a map with an :id (see GanttEx.Filter)"
  end

  defp builtin(:search, labels, _opts),
    do: base(:search, labels.search_tasks, %{placeholder: labels.search_tasks})

  defp builtin(:status, labels, opts) do
    statuses =
      if Keyword.get(opts, :critical, false), do: @statuses, else: @statuses -- [:critical]

    base(:status, labels.status, %{options: Enum.map(statuses, &status_option(&1, labels))})
  end

  defp builtin(:type, labels, _opts) do
    options =
      for type <- Task.types(), do: option(%{label: Map.fetch!(labels, type), value: type})

    base(:type, labels.type, %{options: options})
  end

  defp builtin(:dates, labels, _opts), do: base(:dates, labels.dates, %{})

  defp builtin(:lookahead, labels, _opts) do
    base(:lookahead, labels.lookahead, %{
      options: lookahead_options(@lookahead_weeks, labels),
      multiple: false
    })
  end

  defp base(id, label, extra) do
    Map.merge(
      %{
        id: id,
        kind: id,
        label: label,
        field: nil,
        options: [],
        multiple: true,
        searchable: false,
        placeholder: nil
      },
      extra
    )
  end

  defp lookahead_options(weeks, labels) do
    for count <- weeks,
        do: option(%{label: GanttEx.I18n.duration(count, :week, labels.locale), value: count})
  end

  defp status_option(status, labels) do
    {color, icon} =
      case status do
        :not_started -> {"var(--gx-muted)", nil}
        :in_progress -> {"var(--gx-accent)", nil}
        :completed -> {"var(--gx-success)", nil}
        :overdue -> {"var(--gx-danger)", nil}
        :critical -> {"var(--gx-critical, #e11d48)", nil}
        :blocked -> {nil, :lock_closed}
        :restricted -> {nil, :exclamation_triangle}
      end

    %{label: Map.fetch!(labels, status), value: status}
    |> option()
    |> Map.merge(%{color: color, icon: icon})
  end

  defp option({label, value}), do: option(%{label: label, value: value})

  defp option(%{} = map) do
    value = Map.get(map, :value)

    color =
      case Task.cast_color(Map.get(map, :color)) do
        {:ok, color} -> color
        :error -> nil
      end

    %{
      value: value,
      key: option_key(value),
      label: to_string(Map.get(map, :label) || value),
      image: blank_to_nil(Map.get(map, :image)),
      color: color,
      hint: blank_to_nil(Map.get(map, :hint))
    }
  end

  defp option(value), do: option(%{label: value, value: value})

  defp blank_to_nil(value) when value in [nil, ""], do: nil
  defp blank_to_nil(value), do: to_string(value)

  defp humanize(id), do: id |> to_string() |> String.replace("_", " ") |> String.capitalize()

  @doc """
  Returns the string that identifies an option value in the DOM and in
  client events. `nil` (no value) has its own key.

      iex> GanttEx.Filter.option_key(42)
      "42"

      iex> GanttEx.Filter.option_key(:blocked)
      "blocked"

      iex> GanttEx.Filter.option_key(nil)
      "__none__"
  """
  @spec option_key(term()) :: String.t()
  def option_key(nil), do: @none
  def option_key(value), do: Store.key(value)

  @doc """
  Returns the options of a filter that match a search, and how many more
  matched beyond `limit`. Labels and hints are searched, ignoring case and
  accents.

      iex> [owner] = GanttEx.Filter.definitions([%{id: :owner, options: [{"Ana Pérez", 1}, {"Luis", 2}, %{label: "Marta", value: 3, hint: "Pereira Ltd."}]}], GanttEx.I18n.labels("en"))
      iex> {options, 0} = GanttEx.Filter.search_options(owner, "pere")
      iex> Enum.map(options, & &1.label)
      ["Ana Pérez", "Marta"]
      iex> {[%{label: "Ana Pérez"}], 2} = GanttEx.Filter.search_options(owner, "", 1)
  """
  @spec search_options(definition(), String.t() | nil, pos_integer()) ::
          {[option()], non_neg_integer()}
  def search_options(definition, query, limit \\ 50) do
    query = search_text(query || "") |> String.trim()

    matching =
      if query == "",
        do: definition.options,
        else: Enum.filter(definition.options, &option_matches?(&1, query))

    {Enum.take(matching, limit), max(length(matching) - limit, 0)}
  end

  defp option_matches?(option, query) do
    String.contains?(search_text(option.label), query) or
      (option.hint != nil and String.contains?(search_text(option.hint), query))
  end

  # -- values ------------------------------------------------------------------

  @doc """
  Normalizes filter values (from the host or from the client) against the
  definitions: strings are mapped back to the option values, unknown options
  and filters are dropped, dates are cast to `Date`s and empty filters are
  removed. Custom filter values are always lists, even with `multiple: false`.

      iex> filters = GanttEx.Filter.definitions([:search, :status, :dates, %{id: :owner, options: [{"Ana", 1}, {"Nobody", nil}]}], GanttEx.I18n.labels("en"))
      iex> GanttEx.Filter.normalize(%{"status" => ["blocked", "bogus", ""], "owner" => ["1", "__none__"], "dates" => %{"from" => "2025-01-06", "to" => ""}, "search" => "  "}, filters)
      %{status: [:blocked], owner: [1, nil], dates: %{from: ~D[2025-01-06], to: nil}}
      iex> GanttEx.Filter.normalize(nil, filters)
      %{}
  """
  @spec normalize(map() | keyword() | nil, [definition()]) :: values()
  def normalize(values, definitions) do
    values = if is_list(values), do: Map.new(values), else: values || %{}

    Enum.reduce(definitions, %{}, fn definition, acc ->
      case normalize_value(definition, fetch(values, definition.id)) do
        nil -> acc
        value -> Map.put(acc, definition.id, value)
      end
    end)
  end

  defp fetch(values, id) when is_atom(id),
    do: Map.get(values, id, Map.get(values, Atom.to_string(id)))

  defp fetch(values, id), do: Map.get(values, id)

  defp normalize_value(_definition, nil), do: nil

  defp normalize_value(%{kind: :search}, value) when is_binary(value) do
    case value |> String.trim() |> String.slice(0, 200) do
      "" -> nil
      value -> value
    end
  end

  defp normalize_value(%{kind: :search}, _value), do: nil

  defp normalize_value(%{kind: :dates}, value) when is_map(value) or is_list(value) do
    value = Map.new(value)
    from = cast_date(fetch(value, :from))
    to = cast_date(fetch(value, :to))
    if from || to, do: %{from: from, to: to}
  end

  defp normalize_value(%{kind: :dates}, _value), do: nil

  defp normalize_value(%{kind: :lookahead, options: options}, value) do
    key = value |> List.wrap() |> List.last() |> option_key()
    Enum.find_value(options, &(&1.key == key && &1.value))
  end

  defp normalize_value(%{options: options} = definition, value) do
    keys = value |> List.wrap() |> Enum.map(&option_key/1)
    by_key = Map.new(options, &{&1.key, &1})

    selected =
      if definition.multiple do
        selected = MapSet.new(keys)
        for option <- options, MapSet.member?(selected, option.key), do: option.value
      else
        keys
        |> Enum.filter(&Map.has_key?(by_key, &1))
        |> Enum.take(-1)
        |> Enum.map(&Map.fetch!(by_key, &1).value)
      end

    if selected != [], do: selected
  end

  defp cast_date(%Date{} = date), do: date
  defp cast_date(%NaiveDateTime{} = datetime), do: NaiveDateTime.to_date(datetime)
  defp cast_date(%DateTime{} = datetime), do: DateTime.to_date(datetime)

  defp cast_date(value) when is_binary(value) and byte_size(value) >= 10 do
    case Date.from_iso8601(binary_part(value, 0, 10)) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end

  defp cast_date(_value), do: nil

  @doc """
  Returns the number of active filters in normalized values.

      iex> GanttEx.Filter.active_count(%{search: "slab", status: [:blocked]})
      2
  """
  @spec active_count(values()) :: non_neg_integer()
  def active_count(values), do: map_size(values)

  @doc """
  Returns `true` when the date range of a `:dates` value is reversed (it
  matches no task).

      iex> GanttEx.Filter.invalid_range?(%{from: ~D[2025-02-01], to: ~D[2025-01-01]})
      true

      iex> GanttEx.Filter.invalid_range?(%{from: ~D[2025-01-01], to: nil})
      false
  """
  @spec invalid_range?(map() | nil) :: boolean()
  def invalid_range?(%{from: %Date{} = from, to: %Date{} = to}), do: Date.compare(from, to) == :gt
  def invalid_range?(_dates), do: false

  @doc """
  Returns the days of a lookahead of `weeks` weeks: from the first day of
  the week of `today` (weeks start on the ISO day `week_start`) to the last
  day of the last week, both included.

      iex> GanttEx.Filter.lookahead_range(3, ~D[2026-10-28], 1)
      %{from: ~D[2026-10-26], to: ~D[2026-11-15]}

      iex> GanttEx.Filter.lookahead_range(1, ~N[2026-10-28 10:00:00], 7)
      %{from: ~D[2026-10-25], to: ~D[2026-10-31]}
  """
  @spec lookahead_range(pos_integer(), Date.t() | NaiveDateTime.t(), 1..7) :: %{
          from: Date.t(),
          to: Date.t()
        }
  def lookahead_range(weeks, today, week_start \\ 1) do
    today = cast_date(today)
    from = Date.add(today, -Integer.mod(Date.day_of_week(today) - week_start, 7))
    %{from: from, to: Date.add(from, weeks * 7 - 1)}
  end

  # -- matching ----------------------------------------------------------------

  @doc """
  Returns `true` when the task matches every active filter (and the
  `:filter` function of the context). See `matcher/3`.

      iex> filters = GanttEx.Filter.definitions([:type, :dates], GanttEx.I18n.labels("en"))
      iex> task = GanttEx.Task.new!(id: 1, type: :milestone, start_date: ~D[2025-01-31], end_date: ~D[2025-01-31])
      iex> GanttEx.Filter.match?(task, filters, %{type: [:milestone], dates: %{from: ~D[2025-01-31], to: nil}})
      true
      iex> GanttEx.Filter.match?(task, filters, %{dates: %{from: nil, to: ~D[2025-01-30]}})
      false
  """
  @spec match?(Task.t(), [definition()], values(), context()) :: boolean()
  def match?(%Task{} = task, definitions, values, ctx \\ %{}) do
    case matcher(definitions, values, ctx) do
      nil -> true
      fun -> fun.(task)
    end
  end

  @doc """
  Compiles normalized values into a 1-arity function returning `true` for
  the matching tasks, or `nil` when no filter is active. Compile once to
  test many tasks.
  """
  @spec matcher([definition()], values(), context()) :: (Task.t() -> boolean()) | nil
  def matcher(definitions, values, ctx \\ %{}) do
    predicates =
      for definition <- definitions,
          value = Map.get(values, definition.id),
          value != nil,
          do: predicate(definition, value, ctx)

    predicates = if is_function(ctx[:filter], 1), do: [ctx.filter | predicates], else: predicates

    case predicates do
      [] -> nil
      [predicate] -> predicate
      predicates -> fn task -> Enum.all?(predicates, & &1.(task)) end
    end
  end

  @doc """
  Returns `{ids, matched}`: the ids of the tasks to show (the matching
  tasks and their ancestors, to keep the tree readable) and how many tasks
  matched. `ids` is `nil` when no filter is active.

  It runs in linear time: every task is tested once and every ancestor is
  added once. Pass a `:index` (see `search_index/2`) in the context to
  avoid normalizing the texts on every search.
  """
  @spec visible(Store.t(), [definition()], values(), context()) ::
          {MapSet.t(Task.id()) | nil, non_neg_integer()}
  def visible(%Store{} = store, definitions, values, ctx \\ %{}) do
    ctx =
      if Map.has_key?(values, :search) and not Map.has_key?(ctx, :wbs),
        do: Map.put(ctx, :wbs, Store.wbs_codes(store)),
        else: ctx

    case matcher(definitions, values, ctx) do
      nil ->
        {nil, Store.task_count(store)}

      fun ->
        Enum.reduce(store.tasks, {MapSet.new(), 0}, fn {id, task}, {set, count} ->
          if fun.(task), do: {with_ancestors(store, id, set), count + 1}, else: {set, count}
        end)
    end
  end

  # Adds the task and its ancestors, stopping at the first one already added
  # (its own ancestors were added with it).
  defp with_ancestors(_store, nil, set), do: set

  defp with_ancestors(store, id, set) do
    if MapSet.member?(set, id) do
      set
    else
      parent = store.tasks |> Map.get(id) |> then(&(&1 && &1.parent))
      with_ancestors(store, parent, MapSet.put(set, id))
    end
  end

  defp predicate(%{kind: :search}, query, ctx) do
    query = query |> search_text() |> String.trim()
    wbs = if Regex.match?(~r/^\d+(\.\d+)*\.?$/, query), do: String.trim_trailing(query, ".")
    codes = Map.get(ctx, :wbs, %{})
    index = Map.get(ctx, :index, %{})

    fn task ->
      text =
        case Map.get(index, task.id) do
          {text, normalized} when text == task.text -> normalized
          _ -> search_text(task.text)
        end

      String.contains?(text, query) or (wbs != nil and wbs_match?(Map.get(codes, task.id), wbs))
    end
  end

  defp predicate(%{kind: :status}, statuses, ctx) do
    predicates = Enum.map(statuses, &status_predicate(&1, ctx))
    fn task -> Enum.any?(predicates, & &1.(task)) end
  end

  defp predicate(%{kind: :type}, types, _ctx) do
    types = MapSet.new(types)
    fn task -> MapSet.member?(types, task.type) end
  end

  defp predicate(%{kind: :dates}, %{from: from, to: to} = range, _ctx) do
    if invalid_range?(range) do
      fn _task -> false end
    else
      from = from && NaiveDateTime.new!(from, ~T[00:00:00])
      # the last day is included
      to = to && NaiveDateTime.new!(Date.add(to, 1), ~T[00:00:00])
      fn task -> overlaps?(task, from, to) end
    end
  end

  defp predicate(%{kind: :lookahead}, weeks, ctx) do
    today = Map.get_lazy(ctx, :today, &NaiveDateTime.local_now/0)
    range = lookahead_range(weeks, today, Map.get(ctx, :week_start, 1))
    predicate(%{kind: :dates}, range, ctx)
  end

  defp predicate(%{kind: :options, field: field}, selected, _ctx) do
    keys = MapSet.new(selected, &option_key/1)
    get = getter(field)

    fn task ->
      task
      |> get.()
      |> task_values()
      |> Enum.any?(&MapSet.member?(keys, option_key(&1)))
    end
  end

  defp wbs_match?(nil, _query), do: false
  defp wbs_match?(code, query), do: code == query or String.starts_with?(code, query <> ".")

  defp status_predicate(:not_started, _ctx), do: &(&1.progress == 0)
  defp status_predicate(:in_progress, _ctx), do: &(&1.progress > 0 and &1.progress < 1)
  defp status_predicate(:completed, _ctx), do: &(&1.progress >= 1)
  defp status_predicate(:blocked, _ctx), do: & &1.blocked
  defp status_predicate(:restricted, _ctx), do: &(&1.restrictions > 0)

  defp status_predicate(:critical, ctx) do
    case ctx[:analysis] do
      %{tasks: tasks} -> &match?(%{critical: true}, Map.get(tasks, &1.id))
      _ -> fn _task -> false end
    end
  end

  defp status_predicate(:overdue, ctx) do
    today = Map.get_lazy(ctx, :today, fn -> NaiveDateTime.local_now() end)
    unit = Map.get(ctx, :unit, :day)

    fn task ->
      task.progress < 1 and (past?(task.end_date, today) or past_deadline?(task, today, unit))
    end
  end

  defp past?(nil, _today), do: false
  defp past?(date, today), do: NaiveDateTime.compare(date, today) != :gt

  # Deadlines are inclusive days (see GanttEx.Live.Gantt)
  defp past_deadline?(%{deadline: %NaiveDateTime{} = deadline}, today, unit),
    do: past?(TaskForm.parse_end(deadline, unit), today)

  defp past_deadline?(_task, _today, _unit), do: false

  @doc """
  The status of a task on `today`: `:completed`, `:overdue` (not complete
  and past its end or its deadline, as the `:overdue` status filter),
  `:in_progress` or `:not_started`. Works with any map with `:progress`,
  `:end_date` and `:deadline`.

      iex> task = GanttEx.Task.new!(id: 1, start_date: ~D[2025-01-06], duration: 3, progress: 0.5)
      iex> {:ok, task} = GanttEx.Store.schedule(task, :day)
      iex> GanttEx.Filter.task_status(task, ~N[2025-01-07 10:00:00])
      :in_progress
      iex> GanttEx.Filter.task_status(task, ~D[2025-01-10])
      :overdue
      iex> GanttEx.Filter.task_status(%{task | progress: 1.0}, ~D[2025-01-10])
      :completed
  """
  @spec task_status(map(), Date.t() | NaiveDateTime.t(), Dates.unit()) ::
          :completed | :overdue | :in_progress | :not_started
  def task_status(task, today, unit \\ :day)
  def task_status(%{progress: progress}, _today, _unit) when progress >= 1, do: :completed

  def task_status(task, today, unit) do
    today = Dates.cast!(today)

    cond do
      past?(Map.get(task, :end_date), today) or past_deadline?(task, today, unit) -> :overdue
      (Map.get(task, :progress) || 0) > 0 -> :in_progress
      true -> :not_started
    end
  end

  defp overlaps?(%Task{start_date: nil}, _from, _to), do: false

  defp overlaps?(%Task{start_date: start, end_date: finish}, from, to) do
    finish = finish || start

    (is_nil(to) or NaiveDateTime.compare(start, to) == :lt) and
      (is_nil(from) or NaiveDateTime.compare(finish, from) == :gt or
         (finish == start and NaiveDateTime.compare(start, from) != :lt))
  end

  defp getter(fun) when is_function(fun, 1), do: fun
  defp getter(:resources), do: fn task -> Enum.map(task.resources, & &1.id) end

  defp getter(field) when is_atom(field) do
    if Map.has_key?(%Task{id: nil}, field) and field != :meta do
      &Map.get(&1, field)
    else
      key = Atom.to_string(field)
      &Map.get(&1.meta, field, Map.get(&1.meta, key))
    end
  end

  defp getter(field), do: &Map.get(&1.meta, field)

  defp task_values(nil), do: [nil]
  defp task_values([]), do: [nil]
  defp task_values(values) when is_list(values), do: values
  defp task_values(value), do: [value]

  # -- search ------------------------------------------------------------------

  @doc """
  Normalizes a text for searching: lowercase, without accents (Latin,
  Greek and Cyrillic diacritics).

      iex> GanttEx.Filter.search_text("Hormigón ARMADO, 2º piso")
      "hormigon armado, 2º piso"

      iex> GanttEx.Filter.search_text("Fundação") == GanttEx.Filter.search_text("fundacao")
      true
  """
  @spec search_text(term()) :: String.t()
  def search_text(text) do
    text
    |> to_string()
    |> String.normalize(:nfd)
    |> String.replace(~r/[\x{0300}-\x{036f}]/u, "")
    |> String.downcase()
  end

  @doc """
  Returns the normalized text of every task of a store, to pass as the
  `:index` of the context. Entries of a `previous` index whose text did not
  change are reused, so only new or renamed tasks are normalized.

      iex> store = GanttEx.Store.new!([%{id: 1, text: "Éxito", start_date: ~D[2025-01-01]}])
      iex> GanttEx.Filter.search_index(store)
      %{1 => {"Éxito", "exito"}}
  """
  @spec search_index(Store.t(), search_index()) :: search_index()
  def search_index(%Store{} = store, previous \\ %{}) do
    Map.new(store.tasks, fn {id, task} ->
      case previous do
        %{^id => {text, _normalized} = entry} when text == task.text -> {id, entry}
        _ -> {id, {task.text, search_text(task.text)}}
      end
    end)
  end
end
