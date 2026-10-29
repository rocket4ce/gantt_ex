defmodule GanttEx.Live.Columns do
  @moduledoc """
  Builds the grid columns from the `:column` slots of `GanttEx.Live.Gantt`.

  Built-in fields get a translated label, a width, an alignment and an
  inline editor by default:

  | Field         | Label         | Editor      |
  | ------------- | ------------- | ----------- |
  | `:text`       | Task name     | `:text`     |
  | `:start_date` | Start time    | `:date`     |
  | `:end_date`   | End time      | `:date`     |
  | `:duration`   | Duration      | `:number`   |
  | `:progress`   | Progress      | `:progress` |
  | `:type`       | Type          | `:type`     |
  | `:wbs`        | WBS           | none        |
  | `:add`        | (add button)  | none        |
  | `:actions`    | (row actions) | none        |

  Any other field is read from the task `:meta` and is not editable unless an
  `editor` is given. The tree is shown in the column marked with `tree`, or
  in the `:text` column.

  ## Row actions

  The `:actions` column shows compact buttons on every row, given in its
  `actions` attribute (`#{inspect([:drag, :edit, :delete])}` by default):

    * `:drag` - a handle to drag the row (reorder or re-parent it), also
      moved with the arrow keys
    * `:rename` - edits the task name in place
    * `:edit` - opens the lightbox
    * `:block` - blocks or unblocks the task
    * `:restriction` - asks the host to add a restriction (a `:task_action` event)
    * `:detail` - asks the host to open the task (a `:task_action` event)
    * `:delete` - deletes the task, after confirmation
    * `%{id: :approve, icon: :check, label: "Approve"}` - a custom action,
      reported as a `:task_action` event. `icon` is one of
      `GanttEx.Live.Icons.names/0`.

  Any action may be given as a map with a `:when` function, which receives
  the task and tells whether its row offers the action:
  `%{id: :restriction, when: &(&1.progress < 1)}`. The action is ignored
  for the other tasks, also when it comes from the client.

  Read-only charts drop the actions that edit (all of them but `:detail`
  and the custom ones). The column is as wide as its actions, and its
  buttons show when the row is hovered, focused or selected, or always with
  `reveal: :always` (`<:column field={:actions} actions={...} reveal={:always} />`).

      iex> labels = GanttEx.I18n.labels("en")
      iex> [column] = GanttEx.Live.Columns.build([%{field: :actions, actions: [:drag, :detail, %{id: :pin, icon: :bolt, label: "Pin"}]}], labels, readonly: true)
      iex> {Enum.map(column.actions, &{&1.id, &1.label}), column.width}
      {[detail: "Open detail", pin: "Pin"], 66}

      iex> labels = GanttEx.I18n.labels("en")
      iex> columns = GanttEx.Live.Columns.build([], labels)
      iex> Enum.map(columns, &{&1.field, &1.label, &1.tree})
      [{:text, "Task name", true}, {:start_date, "Start time", false}, {:duration, "Duration", false}, {:add, "", false}]
      iex> [owner] = GanttEx.Live.Columns.build([%{field: :owner_name}], labels, widths: %{"owner_name" => 150})
      iex> {owner.label, owner.width, owner.editor, owner.tree}
      {"Owner name", 150, nil, true}

  ## Layout

  Columns marked `hidden` are available but not shown until the user adds
  them with the column chooser. The user can also reorder and resize the
  columns; that layout is a map of field names (strings):

      %{order: ["wbs", "text", "start_date"], hidden: ["cost"], widths: %{"text" => 300}, grid_width: nil}

  Fields that are not columns are ignored. Columns missing from `order`
  (such as new slots) are added at the end, in slot order, and shown unless
  their slot is `hidden` or they are in `hidden`. The tree column is always
  shown.

      iex> labels = GanttEx.I18n.labels("en")
      iex> slots = [%{field: :text}, %{field: :start_date}, %{field: :cost, hidden: true}, %{field: :wbs}]
      iex> layout = %{"order" => ["wbs", "gone", "text"], "hidden" => ["start_date"]}
      iex> GanttEx.Live.Columns.build(slots, labels, layout: layout) |> Enum.map(& &1.key)
      ["wbs", "text"]
      iex> GanttEx.Live.Columns.available(slots, labels, layout: layout) |> Enum.map(&{&1.key, &1.visible})
      [{"wbs", true}, {"text", true}, {"start_date", false}, {"cost", false}]
  """

  # computed or multi-valued fields
  @unsortable [:add, :actions, :wbs, :total_slack, :free_slack, :resources]

  @default_actions [:drag, :edit, :delete]

  # built-in row actions: their icon and whether they edit the task
  @actions %{
    drag: {:grip, true},
    rename: {:pencil, true},
    edit: {:pencil_square, true},
    block: {:lock_open, true},
    restriction: {:triangle_plus, true},
    detail: {:arrow_top_right_on_square, false},
    delete: {:trash, true}
  }

  @defaults [
    %{field: :text, tree: true, width: 220},
    %{field: :start_date, width: 104},
    %{field: :duration, width: 76},
    %{field: :add, width: 44}
  ]

  @typedoc "A normalized column."
  @type t :: %{
          required(:field) => atom() | String.t(),
          required(:label) => String.t(),
          required(:width) => pos_integer(),
          required(:align) => String.t(),
          required(:tree) => boolean(),
          required(:editor) => atom() | nil,
          required(:sortable) => boolean(),
          required(:inner_block) => term(),
          required(:key) => String.t(),
          required(:visible) => boolean(),
          optional(atom()) => term()
        }

  @typedoc "The user's layout of the columns (see \"Layout\" above)."
  @type layout :: %{
          order: [String.t()] | nil,
          hidden: [String.t()] | nil,
          widths: %{String.t() => pos_integer()},
          grid_width: pos_integer() | nil
        }

  @doc """
  Normalizes column slots (or the default columns when none are given) and
  returns the visible ones, in the order of the layout.

  ## Options

    * `:widths` - widths set by the user, keyed by the field as a string.
    * `:readonly` - drops the `:add` column, and the actions that edit.
    * `:layout` - the user's layout (see "Layout" above).
  """
  @spec build([map()], map(), keyword()) :: [t()]
  def build(slots, labels, opts \\ []) do
    slots |> available(labels, opts) |> Enum.filter(& &1.visible)
  end

  @doc """
  Like `build/3`, but returns every column, the hidden ones included (with
  `visible: false`): the choices of the column chooser.
  """
  @spec available([map()], map(), keyword()) :: [t()]
  def available(slots, labels, opts \\ []) do
    layout = opts |> Keyword.get(:layout) |> normalize_layout()
    widths = Map.merge(layout.widths, Keyword.get(opts, :widths, %{}))
    readonly = Keyword.get(opts, :readonly, false)
    slots = if slots == [], do: @defaults, else: slots
    slots = if readonly, do: Enum.reject(slots, &(&1.field == :add)), else: slots

    columns =
      slots
      |> Enum.map(fn slot ->
        field = Map.fetch!(slot, :field)
        key = to_string(field)
        actions = if field == :actions, do: actions(slot, labels, readonly), else: []
        label = Map.get(slot, :label) || label(field, labels)

        Map.merge(slot, %{
          field: field,
          key: key,
          label: label,
          title: title(field, label, labels),
          width: Map.get(widths, key) || Map.get(slot, :width) || width(field, length(actions)),
          align: Map.get(slot, :align) || align(field),
          tree: Map.get(slot, :tree, false),
          editor: Map.get(slot, :editor, editor(field)),
          sortable: Map.get(slot, :sortable, field not in @unsortable),
          inner_block: Map.get(slot, :inner_block),
          actions: actions,
          hidden: Map.get(slot, :hidden, false) == true
        })
      end)
      # read-only charts may have no action left
      |> Enum.reject(&(&1.field == :actions and &1.actions == []))

    columns =
      if Enum.any?(columns, & &1.tree) do
        columns
      else
        index = Enum.find_index(columns, &(&1.field == :text)) || 0
        List.update_at(columns, index, &%{&1 | tree: true})
      end

    arrange(columns, layout)
  end

  # Orders the columns as in the layout and decides which ones are shown.
  defp arrange(columns, layout) do
    ordered =
      case layout.order do
        nil ->
          columns

        order ->
          by_key = Enum.group_by(columns, & &1.key)
          listed = order |> Enum.uniq() |> Enum.flat_map(&Map.get(by_key, &1, []))
          listed_keys = MapSet.new(listed, & &1.key)
          listed ++ Enum.reject(columns, &MapSet.member?(listed_keys, &1.key))
      end

    known = MapSet.new(layout.order || [])
    hidden = MapSet.new(layout.hidden || [])

    Enum.map(ordered, fn column ->
      # new columns (not in the layout) are shown unless their slot hides them
      visible =
        cond do
          column.tree -> true
          MapSet.member?(hidden, column.key) -> false
          layout.hidden && MapSet.member?(known, column.key) -> true
          true -> not column.hidden
        end

      Map.put(column, :visible, visible)
    end)
  end

  @doc """
  Normalizes a layout given by the host (atom or string keys). Invalid
  entries are dropped and widths are kept between 32 and 800 pixels.

      iex> GanttEx.Live.Columns.normalize_layout(%{"order" => [:text, "wbs", 3], "widths" => %{text: 2000, wbs: "x"}})
      %{order: ["text", "wbs"], hidden: nil, widths: %{"text" => 800}, grid_width: nil}

      iex> GanttEx.Live.Columns.normalize_layout(nil)
      %{order: nil, hidden: nil, widths: %{}, grid_width: nil}
  """
  @spec normalize_layout(map() | keyword() | nil) :: layout()
  def normalize_layout(nil), do: %{order: nil, hidden: nil, widths: %{}, grid_width: nil}
  def normalize_layout(layout) when is_list(layout), do: layout |> Map.new() |> normalize_layout()

  def normalize_layout(layout) when is_map(layout) do
    get = fn key -> Map.get(layout, key, Map.get(layout, Atom.to_string(key))) end

    widths =
      for {field, width} <- get.(:widths) || %{},
          is_atom(field) or is_binary(field),
          is_number(width),
          into: %{},
          do: {to_string(field), width |> round() |> max(32) |> min(800)}

    %{
      order: keys(get.(:order)),
      hidden: keys(get.(:hidden)),
      widths: widths,
      grid_width:
        case get.(:grid_width) do
          width when is_number(width) -> width |> round() |> max(120) |> min(2000)
          _ -> nil
        end
    }
  end

  defp keys(list) when is_list(list),
    do: for(key <- list, is_atom(key) or is_binary(key), not is_nil(key), do: to_string(key))

  defp keys(_value), do: nil

  @doc """
  Returns the layout of the given columns (from `available/3`), as reported
  to the host: every field in order, the hidden ones, the widths set by the
  user and the width of the grid when the user set it.

      iex> labels = GanttEx.I18n.labels("en")
      iex> state = %{order: nil, hidden: ["duration"], widths: %{"text" => 300, "gone" => 90}, grid_width: nil}
      iex> GanttEx.Live.Columns.build([], labels) |> length()
      4
      iex> [] |> GanttEx.Live.Columns.available(labels, layout: state) |> GanttEx.Live.Columns.layout(state)
      %{order: ["text", "start_date", "duration", "add"], hidden: ["duration"], widths: %{"text" => 300}, grid_width: nil}
  """
  @spec layout([t()], layout()) :: layout()
  def layout(columns, state) do
    keys = Enum.map(columns, & &1.key)

    %{
      order: keys,
      hidden: for(column <- columns, not column.visible, do: column.key),
      widths: Map.take(state.widths, keys),
      grid_width: state.grid_width
    }
  end

  @doc """
  Returns the width of an `:actions` column with `count` actions.

      iex> GanttEx.Live.Columns.actions_width(3)
      92
  """
  @spec actions_width(non_neg_integer()) :: pos_integer()
  def actions_width(count), do: 14 + 26 * max(count, 1)

  defp actions(slot, labels, readonly) do
    slot
    |> Map.get(:actions, @default_actions)
    |> List.wrap()
    |> Enum.map(&action(&1, labels))
    |> Enum.uniq_by(& &1.id)
    |> Enum.reject(&(readonly and &1.editing))
  end

  defp action(id, labels) when is_map_key(@actions, id) do
    {icon, editing} = Map.fetch!(@actions, id)

    %{
      id: id,
      icon: icon,
      label: action_label(id, labels),
      editing: editing,
      builtin: true,
      when: nil
    }
  end

  defp action(%{id: id} = action, labels) when is_map_key(@actions, id),
    do: id |> action(labels) |> Map.put(:when, condition(action))

  defp action(%{id: id} = action, _labels) when is_atom(id) or is_binary(id) do
    icon = Map.get(action, :icon, :bolt)

    if icon not in GanttEx.Live.Icons.names() do
      raise ArgumentError,
            "unknown icon #{inspect(icon)} for the action #{inspect(id)}, " <>
              "expected one of GanttEx.Live.Icons.names/0"
    end

    %{
      id: id,
      icon: icon,
      label: to_string(Map.get(action, :label) || id),
      editing: false,
      builtin: false,
      when: condition(action)
    }
  end

  defp action(other, _labels) do
    raise ArgumentError,
          "invalid row action #{inspect(other)}: expected one of " <>
            "#{inspect(Map.keys(@actions))} or a map with an :id, an :icon and a :label"
  end

  defp condition(action) do
    case Map.get(action, :when) do
      nil ->
        nil

      fun when is_function(fun, 1) ->
        fun

      other ->
        raise ArgumentError,
              "invalid :when #{inspect(other)} for the action #{inspect(action.id)}, " <>
                "expected a function receiving the task"
    end
  end

  @doc "Whether the row of `task` offers `action` (its `:when` function)."
  @spec action_allowed?(map(), GanttEx.Task.t()) :: boolean()
  def action_allowed?(%{when: fun}, task) when is_function(fun, 1), do: fun.(task) == true
  def action_allowed?(_action, _task), do: true

  defp action_label(:drag, labels), do: labels.drag_to_reorder
  defp action_label(:rename, labels), do: labels.rename
  defp action_label(:edit, labels), do: labels.edit
  defp action_label(:block, labels), do: labels.block_task
  defp action_label(:restriction, labels), do: labels.add_restriction
  defp action_label(:detail, labels), do: labels.open_detail
  defp action_label(:delete, labels), do: labels.delete

  @doc "Returns the sum of the column widths."
  @spec total_width([t()]) :: non_neg_integer()
  def total_width(columns), do: columns |> Enum.map(& &1.width) |> Enum.sum()

  @doc "Finds a column by its field sent as a string by the client."
  @spec find([t()], String.t()) :: t() | nil
  def find(columns, field), do: Enum.find(columns, &(to_string(&1.field) == field))

  defp label(:text, labels), do: labels.task_name
  defp label(:start_date, labels), do: labels.start_time
  defp label(:end_date, labels), do: labels.end_time
  defp label(:duration, labels), do: labels.duration
  defp label(:progress, labels), do: labels.progress
  defp label(:type, labels), do: labels.type
  defp label(:wbs, labels), do: labels.wbs
  defp label(:constraint_type, labels), do: labels.constraint
  defp label(:total_slack, labels), do: labels.total_slack
  defp label(:planned_start, labels), do: labels.planned_start
  defp label(:resources, labels), do: labels.resources
  defp label(:planned_end, labels), do: labels.planned_end
  defp label(:deadline, labels), do: labels.deadline
  defp label(:free_slack, labels), do: labels.free_slack
  defp label(:add, _labels), do: ""
  defp label(:actions, labels), do: labels.actions

  defp label(field, _labels),
    do: field |> to_string() |> String.replace("_", " ") |> String.capitalize()

  # The name of a column in the column chooser
  defp title(:add, _label, labels), do: labels.add_task
  defp title(:actions, _label, labels), do: labels.actions
  defp title(_field, label, _labels), do: label

  defp width(:actions, count), do: actions_width(count)
  defp width(:text, _count), do: 220
  defp width(:add, _count), do: 44
  defp width(:wbs, _count), do: 64
  defp width(:resources, _count), do: 140
  defp width(:constraint_type, _count), do: 150
  defp width(field, _count) when field in [:duration, :progress], do: 76
  defp width(field, _count) when field in [:total_slack, :free_slack], do: 96
  defp width(_field, _count), do: 104

  defp align(field)
       when field in [
              :start_date,
              :end_date,
              :duration,
              :progress,
              :add,
              :planned_start,
              :planned_end,
              :deadline
            ],
       do: "center"

  defp align(_field), do: "left"

  defp editor(:text), do: :text

  defp editor(field)
       when field in [:start_date, :end_date, :planned_start, :planned_end, :deadline],
       do: :date

  defp editor(:duration), do: :number
  defp editor(:progress), do: :progress
  defp editor(:type), do: :type
  defp editor(_field), do: nil
end
