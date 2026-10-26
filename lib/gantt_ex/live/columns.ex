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
  | `:add`        | (add button)  | none        |

  Any other field is read from the task `:meta` and is not editable unless an
  `editor` is given. The tree is shown in the column marked with `tree`, or
  in the `:text` column.

      iex> labels = GanttEx.I18n.labels("en")
      iex> columns = GanttEx.Live.Columns.build([], labels)
      iex> Enum.map(columns, &{&1.field, &1.label, &1.tree})
      [{:text, "Task name", true}, {:start_date, "Start time", false}, {:duration, "Duration", false}, {:add, "", false}]
      iex> [owner] = GanttEx.Live.Columns.build([%{field: :owner_name}], labels, widths: %{"owner_name" => 150})
      iex> {owner.label, owner.width, owner.editor, owner.tree}
      {"Owner name", 150, nil, true}
  """

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
          optional(atom()) => term()
        }

  @doc """
  Normalizes column slots (or the default columns when none are given).

  ## Options

    * `:widths` - widths set by the user, keyed by the field as a string.
    * `:readonly` - drops the `:add` column.
  """
  @spec build([map()], map(), keyword()) :: [t()]
  def build(slots, labels, opts \\ []) do
    widths = Keyword.get(opts, :widths, %{})
    slots = if slots == [], do: @defaults, else: slots

    slots =
      if Keyword.get(opts, :readonly, false),
        do: Enum.reject(slots, &(&1.field == :add)),
        else: slots

    columns =
      Enum.map(slots, fn slot ->
        field = Map.fetch!(slot, :field)

        Map.merge(slot, %{
          field: field,
          label: Map.get(slot, :label) || label(field, labels),
          width: Map.get(widths, to_string(field)) || Map.get(slot, :width) || width(field),
          align: Map.get(slot, :align) || align(field),
          tree: Map.get(slot, :tree, false),
          editor: Map.get(slot, :editor, editor(field)),
          sortable: Map.get(slot, :sortable, field != :add),
          inner_block: Map.get(slot, :inner_block)
        })
      end)

    if Enum.any?(columns, & &1.tree) do
      columns
    else
      index = Enum.find_index(columns, &(&1.field == :text)) || 0
      List.update_at(columns, index, &%{&1 | tree: true})
    end
  end

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
  defp label(:add, _labels), do: ""

  defp label(field, _labels),
    do: field |> to_string() |> String.replace("_", " ") |> String.capitalize()

  defp width(:text), do: 220
  defp width(:add), do: 44
  defp width(field) when field in [:duration, :progress], do: 76
  defp width(_field), do: 104

  defp align(field) when field in [:start_date, :end_date, :duration, :progress, :add],
    do: "center"

  defp align(_field), do: "left"

  defp editor(:text), do: :text
  defp editor(field) when field in [:start_date, :end_date], do: :date
  defp editor(:duration), do: :number
  defp editor(:progress), do: :progress
  defp editor(:type), do: :type
  defp editor(_field), do: nil
end
