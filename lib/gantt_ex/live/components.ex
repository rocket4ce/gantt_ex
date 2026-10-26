defmodule GanttEx.Live.Components do
  @moduledoc """
  Function components that make up `GanttEx.Live.Gantt`.

  They render pre-computed data (rows, bars and links built by
  `GanttEx.Store`, `GanttEx.Timeline` and `GanttEx.Layout`) and send their
  events to the component given in `ctx.myself`. Most applications only need
  `GanttEx.Live.Gantt`; these are public to document the generated markup and
  to allow custom layouts.

  Every component receives a `ctx` map with:

    * `:id` - the DOM id of the chart
    * `:myself` - the `phx-target` of the events
    * `:labels` - translated labels (see `GanttEx.I18n.labels/1`)
    * `:format` - a date formatter (see `GanttEx.I18n.formatter/1`)
    * `:date_pattern` - the pattern used for dates in the grid
    * `:unit` - the duration unit
    * `:readonly`, `:inline_edit`, `:tooltips`, `:lightbox` - feature flags
  """

  use Phoenix.Component

  import GanttEx.Live.Icons

  alias GanttEx.{Store, TaskForm}
  alias Phoenix.LiveView.JS

  # -- toolbar -----------------------------------------------------------------

  @doc "Renders the toolbar: add, expand/collapse, zoom, today, export, print and fullscreen."
  attr :ctx, :map, required: true
  attr :zoom, :atom, required: true
  attr :levels, :list, required: true
  attr :export_formats, :list, default: []
  attr :can_add, :boolean, default: true
  attr :show_history, :boolean, default: false
  attr :can_undo, :boolean, default: false
  attr :can_redo, :boolean, default: false
  slot :inner_block

  def toolbar(assigns) do
    assigns =
      assign(assigns,
        can_zoom_in: GanttEx.Zoom.can_zoom?(assigns.levels, assigns.zoom, :in),
        can_zoom_out: GanttEx.Zoom.can_zoom?(assigns.levels, assigns.zoom, :out)
      )

    ~H"""
    <div class="gx-toolbar" role="toolbar" aria-label={@ctx.labels.chart}>
      <button
        :if={@can_add}
        id={"#{@ctx.id}-add-task"}
        type="button"
        class="gx-btn gx-btn--primary"
        phx-click="add"
        phx-value-parent=""
        phx-target={@ctx.myself}
      >
        <.icon name={:plus} />
        <span>{@ctx.labels.add_task}</span>
      </button>

      <div :if={@show_history} class="gx-toolbar-group">
        <button
          id={"#{@ctx.id}-undo"}
          type="button"
          class="gx-btn gx-btn--icon"
          title={@ctx.labels.undo}
          aria-label={@ctx.labels.undo}
          disabled={not @can_undo}
          phx-click="undo"
          phx-target={@ctx.myself}
        >
          <.icon name={:undo} />
        </button>
        <button
          id={"#{@ctx.id}-redo"}
          type="button"
          class="gx-btn gx-btn--icon"
          title={@ctx.labels.redo}
          aria-label={@ctx.labels.redo}
          disabled={not @can_redo}
          phx-click="redo"
          phx-target={@ctx.myself}
        >
          <.icon name={:redo} />
        </button>
      </div>

      <div class="gx-toolbar-group">
        <button
          id={"#{@ctx.id}-expand-all"}
          type="button"
          class="gx-btn gx-btn--icon"
          title={@ctx.labels.expand_all}
          aria-label={@ctx.labels.expand_all}
          phx-click="expand_all"
          phx-target={@ctx.myself}
        >
          <.icon name={:bars_down} />
        </button>
        <button
          id={"#{@ctx.id}-collapse-all"}
          type="button"
          class="gx-btn gx-btn--icon"
          title={@ctx.labels.collapse_all}
          aria-label={@ctx.labels.collapse_all}
          phx-click="collapse_all"
          phx-target={@ctx.myself}
        >
          <.icon name={:bars_up} />
        </button>
      </div>

      <div class="gx-toolbar-group gx-segmented" role="group" aria-label={@ctx.labels.zoom}>
        <button
          id={"#{@ctx.id}-zoom-out"}
          type="button"
          class="gx-btn gx-btn--icon"
          title={@ctx.labels.zoom_out}
          aria-label={@ctx.labels.zoom_out}
          disabled={not @can_zoom_out}
          phx-click="zoom_out"
          phx-target={@ctx.myself}
        >
          <.icon name={:zoom_out} />
        </button>
        <button
          :for={level <- @levels}
          id={"#{@ctx.id}-zoom-#{level.name}"}
          type="button"
          class={["gx-segment", level.name == @zoom && "gx-segment--active"]}
          aria-pressed={to_string(level.name == @zoom)}
          phx-click="zoom"
          phx-value-level={level.name}
          phx-target={@ctx.myself}
        >
          {Map.get(@ctx.labels, level.name) || Map.get(level, :label) || to_string(level.name)}
        </button>
        <button
          id={"#{@ctx.id}-zoom-in"}
          type="button"
          class="gx-btn gx-btn--icon"
          title={@ctx.labels.zoom_in}
          aria-label={@ctx.labels.zoom_in}
          disabled={not @can_zoom_in}
          phx-click="zoom_in"
          phx-target={@ctx.myself}
        >
          <.icon name={:zoom_in} />
        </button>
      </div>

      <button
        id={"#{@ctx.id}-today"}
        type="button"
        class="gx-btn"
        phx-click="today"
        phx-target={@ctx.myself}
      >
        <.icon name={:calendar} />
        <span>{@ctx.labels.today}</span>
      </button>

      <div class="gx-toolbar-spacer"></div>

      {render_slot(@inner_block)}

      <details :if={@export_formats != []} id={"#{@ctx.id}-export"} class="gx-menu">
        <summary class="gx-btn" title={@ctx.labels.export}>
          <.icon name={:download} />
          <span>{@ctx.labels.export}</span>
        </summary>
        <div class="gx-menu-list" role="menu">
          <button
            :for={format <- @export_formats}
            id={"#{@ctx.id}-export-#{format}"}
            type="button"
            role="menuitem"
            class="gx-menu-item"
            phx-click={
              JS.push("export", value: %{format: format}, target: @ctx.myself)
              |> JS.remove_attribute("open", to: "##{@ctx.id}-export")
            }
          >
            {export_label(format)}
          </button>
          <button
            id={"#{@ctx.id}-print"}
            type="button"
            role="menuitem"
            class="gx-menu-item"
            phx-click={
              JS.remove_attribute("open", to: "##{@ctx.id}-export")
              |> JS.dispatch("gantt_ex:print", to: "##{@ctx.id}")
            }
          >
            <.icon name={:printer} /> {@ctx.labels.print}
          </button>
        </div>
      </details>

      <button
        id={"#{@ctx.id}-fullscreen"}
        type="button"
        class="gx-btn gx-btn--icon"
        title={@ctx.labels.fullscreen}
        aria-label={@ctx.labels.fullscreen}
        phx-click={JS.dispatch("gantt_ex:fullscreen", to: "##{@ctx.id}")}
      >
        <.icon name={:expand} />
      </button>
    </div>
    """
  end

  defp export_label(:json), do: "JSON"
  defp export_label(:csv), do: "CSV (Excel)"
  defp export_label(:ical), do: "iCalendar (.ics)"
  defp export_label(:ms_project), do: "MS Project (.xml)"
  defp export_label(:svg), do: "SVG (.svg)"
  defp export_label(:png), do: "PNG (.png)"
  defp export_label(other), do: to_string(other)

  # -- grid --------------------------------------------------------------------

  @doc "Renders the header of the task grid."
  attr :ctx, :map, required: true
  attr :columns, :list, required: true
  attr :sort, :any, default: nil
  attr :grid_width, :integer, required: true

  def grid_header(assigns) do
    ~H"""
    <div class="gx-grid-head" role="row">
      <div
        :for={{col, index} <- Enum.with_index(@columns)}
        role="columnheader"
        class={["gx-head-cell", col.tree && "gx-cell--tree", "gx-align-#{col.align}"]}
        style={column_style(col, index)}
        aria-sort={aria_sort(@sort, col)}
      >
        <%= cond do %>
          <% col.field == :add -> %>
            <button
              :if={not @ctx.readonly}
              type="button"
              class="gx-add"
              title={@ctx.labels.add_task}
              aria-label={@ctx.labels.add_task}
              phx-click="add"
              phx-value-parent=""
              phx-target={@ctx.myself}
            >
              <.icon name={:plus} />
            </button>
          <% col.sortable -> %>
            <button
              type="button"
              class="gx-sort"
              phx-click="sort"
              phx-value-field={col.field}
              phx-target={@ctx.myself}
            >
              <span class="gx-truncate">{col.label}</span>
              <.icon :if={@sort == {col.field, :asc}} name={:arrow_up} class="gx-sort-icon" />
              <.icon :if={@sort == {col.field, :desc}} name={:arrow_down} class="gx-sort-icon" />
            </button>
          <% true -> %>
            <span class="gx-truncate">{col.label}</span>
        <% end %>
        <span
          :if={not col.tree}
          class="gx-col-resizer"
          data-gx-resize-column={col.field}
          data-gx-col-index={index}
          data-gx-width={col.width}
          aria-hidden="true"
        ></span>
      </div>
      <span
        class="gx-splitter"
        role="separator"
        aria-orientation="vertical"
        aria-label={@ctx.labels.resize}
        data-gx-resize-column="__grid"
        data-gx-width={@grid_width}
      ></span>
    </div>
    """
  end

  defp column_style(%{tree: true}, _index), do: "flex: 1 1 0; min-width: 0"
  defp column_style(_col, index), do: "width: var(--gx-col-#{index}); flex: none"

  defp aria_sort({field, :asc}, %{field: field}), do: "ascending"
  defp aria_sort({field, :desc}, %{field: field}), do: "descending"
  defp aria_sort(_sort, %{sortable: true}), do: "none"
  defp aria_sort(_sort, _col), do: nil

  @doc "Renders a row of the task grid."
  attr :ctx, :map, required: true
  attr :row, :map, required: true
  attr :columns, :list, required: true
  attr :editing, :any, default: nil, doc: "the field being edited inline in this row"

  def grid_row(assigns) do
    ~H"""
    <div
      id={"#{@ctx.id}-row-#{dom_key(@row.key)}"}
      class={[
        "gx-row",
        @row.selected && "gx-row--selected",
        @row.task.type == :project && "gx-row--project"
      ]}
      role="row"
      aria-level={@row.level + 1}
      aria-expanded={@row.has_children && to_string(@row.open)}
      aria-selected={to_string(@row.selected)}
      data-gx-row={@row.key}
      phx-click="select"
      phx-value-key={@row.key}
      phx-target={@ctx.myself}
    >
      <div
        :for={{col, index} <- Enum.with_index(@columns)}
        role="gridcell"
        class={["gx-cell", col.tree && "gx-cell--tree", "gx-align-#{col.align}"]}
        style={column_style(col, index)}
        phx-click={editable_cell?(col, @row, @ctx) && "cell_click"}
        phx-value-key={@row.key}
        phx-value-field={col.field}
        phx-target={@ctx.myself}
      >
        <%= if @editing == col.field do %>
          <.cell_editor ctx={@ctx} row={@row} column={col} />
        <% else %>
          <.cell_content ctx={@ctx} row={@row} column={col} />
        <% end %>
      </div>
    </div>
    """
  end

  defp editable_cell?(col, row, ctx) do
    ctx.inline_edit and not ctx.readonly and not row.task.readonly and not is_nil(col.editor) and
      not (col.field in [:start_date, :end_date, :duration] and row.task.type == :project and
             row.has_children)
  end

  attr :ctx, :map, required: true
  attr :row, :map, required: true
  attr :column, :map, required: true

  defp cell_content(%{column: %{tree: true}} = assigns) do
    ~H"""
    <span class="gx-indent" style={"width: #{@row.level * 18}px"}></span>
    <button
      :if={@row.has_children}
      type="button"
      class={["gx-toggle", @row.open && "gx-toggle--open"]}
      aria-label={if(@row.open, do: @ctx.labels.collapse, else: @ctx.labels.expand)}
      phx-click="toggle"
      phx-value-key={@row.key}
      phx-target={@ctx.myself}
    >
      <.icon name={:chevron_right} />
    </button>
    <span :if={not @row.has_children} class="gx-toggle-spacer"></span>
    <span class={["gx-type-dot", "gx-type-dot--#{@row.task.type}"]}></span>
    <span class="gx-truncate">
      <%= if @column.inner_block do %>
        {render_slot(@column, @row.task)}
      <% else %>
        {cell_value(@row.task, @column, @ctx)}
      <% end %>
    </span>
    """
  end

  defp cell_content(%{column: %{field: :add}} = assigns) do
    ~H"""
    <button
      :if={not @ctx.readonly and not @row.task.readonly}
      type="button"
      class="gx-add"
      title={@ctx.labels.add_subtask}
      aria-label={@ctx.labels.add_subtask}
      phx-click="add"
      phx-value-parent={@row.key}
      phx-target={@ctx.myself}
    >
      <.icon name={:plus} />
    </button>
    """
  end

  defp cell_content(%{column: %{field: :wbs, inner_block: nil}} = assigns) do
    ~H"""
    <span class="gx-truncate gx-wbs">{@row.wbs}</span>
    """
  end

  defp cell_content(assigns) do
    ~H"""
    <span class="gx-truncate">
      <%= if @column.inner_block do %>
        {render_slot(@column, @row.task)}
      <% else %>
        {cell_value(@row.task, @column, @ctx)}
      <% end %>
    </span>
    """
  end

  @doc false
  def cell_value(task, %{field: field}, ctx) do
    case field do
      :text -> task.text
      :start_date -> ctx.format.(task.start_date, ctx.date_pattern)
      :end_date -> ctx.format.(TaskForm.display_end(task, ctx.unit), ctx.date_pattern)
      :duration -> to_string(task.duration)
      :progress -> "#{round(task.progress * 100)}%"
      :type -> Map.fetch!(ctx.labels, task.type)
      field -> task.meta |> meta_value(field) |> to_string()
    end
  end

  defp meta_value(meta, field) when is_atom(field) do
    Map.get(meta, field, Map.get(meta, Atom.to_string(field)))
  end

  defp meta_value(meta, field), do: Map.get(meta, field)

  attr :ctx, :map, required: true
  attr :row, :map, required: true
  attr :column, :map, required: true

  defp cell_editor(assigns) do
    assigns = assign(assigns, :value, editor_value(assigns.row.task, assigns.column, assigns.ctx))

    ~H"""
    <form
      id={"#{@ctx.id}-cell-editor"}
      class="gx-cell-editor"
      phx-submit="cell_save"
      phx-change={@column.editor == :type && "cell_save"}
      phx-target={@ctx.myself}
    >
      <input type="hidden" name="key" value={@row.key} />
      <input type="hidden" name="field" value={@column.field} />
      <%= if @column.editor == :type do %>
        <select
          id={"#{@ctx.id}-cell-input"}
          name="value"
          class="gx-input gx-input--cell"
          phx-mounted={JS.focus()}
          phx-keydown="cell_cancel"
          phx-key="Escape"
          phx-target={@ctx.myself}
        >
          {Phoenix.HTML.Form.options_for_select(type_options(@ctx.labels), @value)}
        </select>
      <% else %>
        <input
          id={"#{@ctx.id}-cell-input"}
          name="value"
          type={editor_input_type(@column.editor, @ctx.unit)}
          value={@value}
          min={@column.editor in [:number, :progress] && "0"}
          max={@column.editor == :progress && "100"}
          class="gx-input gx-input--cell"
          autocomplete="off"
          phx-mounted={JS.focus()}
          phx-blur="cell_save"
          phx-value-key={@row.key}
          phx-value-field={@column.field}
          phx-keydown="cell_cancel"
          phx-key="Escape"
          phx-target={@ctx.myself}
        />
      <% end %>
    </form>
    """
  end

  defp editor_input_type(:date, unit), do: TaskForm.date_input_type(unit)
  defp editor_input_type(type, _unit) when type in [:number, :progress], do: "number"
  defp editor_input_type(_type, _unit), do: "text"

  defp editor_value(task, %{field: field}, ctx) do
    case field do
      :start_date -> TaskForm.input_date(task.start_date, ctx.unit)
      :end_date -> TaskForm.input_date(TaskForm.display_end(task, ctx.unit), ctx.unit)
      :progress -> task.progress |> Kernel.*(100) |> round() |> Integer.to_string()
      :type -> Atom.to_string(task.type)
      :duration -> to_string(task.duration)
      :text -> task.text
      field -> task.meta |> meta_value(field) |> to_string()
    end
  end

  defp type_options(labels) do
    [{labels.task, "task"}, {labels.project, "project"}, {labels.milestone, "milestone"}]
  end

  # -- scale -------------------------------------------------------------------

  @doc "Renders the time scale header."
  attr :rows, :list, required: true
  attr :width, :integer, required: true

  def scale(assigns) do
    ~H"""
    <div class="gx-scale" style={"width: #{@width}px"} aria-hidden="true">
      <div :for={cells <- @rows} class="gx-scale-row">
        <div
          :for={cell <- cells}
          class={["gx-scale-cell", cell.class]}
          style={"left: #{px(cell.x)}; width: #{px(cell.width)}"}
        >
          <span class="gx-truncate">{cell.label}</span>
        </div>
      </div>
    </div>
    """
  end

  # -- chart -------------------------------------------------------------------

  @doc """
  Renders a task bar with its drag handles, link points and tooltip.

  `bar` is a bar from `GanttEx.Layout.build/4` with these extra keys:
  `:selected`, `:drag` (`"move"` or `"none"`), `:resizable`,
  `:progress_editable`, `:linkable` and `:class`.
  """
  attr :ctx, :map, required: true
  attr :bar, :map, required: true
  attr :task_text, :list, default: []
  attr :tooltip, :list, default: []

  def task_bar(assigns) do
    ~H"""
    <div
      id={"#{@ctx.id}-bar-#{dom_key(@bar.key)}"}
      class={[
        "gx-bar",
        "gx-bar--#{@bar.kind}",
        @bar.selected && "gx-bar--selected",
        @bar.drag == "none" && "gx-bar--locked",
        @bar.class
      ]}
      style={bar_style(@bar)}
      role="button"
      tabindex="-1"
      aria-label={bar_label(@bar, @ctx)}
      data-gx-bar={@bar.key}
      data-gx-drag={@bar.drag}
      phx-click="select"
      phx-value-key={@bar.key}
      phx-value-source="bar"
      phx-target={@ctx.myself}
    >
      <div class="gx-bar-body">
        <div :if={@bar.kind != :milestone} class="gx-bar-progress"></div>
        <span class="gx-bar-text">
          <%= if @task_text != [] do %>
            {render_slot(@task_text, @bar.task)}
          <% else %>
            {@bar.task.text}
          <% end %>
        </span>
      </div>
      <%= if @bar.resizable do %>
        <span class="gx-handle gx-handle--start" data-gx-handle="start"></span>
        <span class="gx-handle gx-handle--end" data-gx-handle="end"></span>
      <% end %>
      <span :if={@bar.progress_editable} class="gx-progress-handle" data-gx-progress-handle></span>
      <%= if @bar.linkable do %>
        <span class="gx-link-point gx-link-point--start" data-gx-link-point="start"></span>
        <span class="gx-link-point gx-link-point--end" data-gx-link-point="end"></span>
      <% end %>
      <div :if={@ctx.tooltips} class="gx-tooltip" role="tooltip">
        <%= if @tooltip != [] do %>
          {render_slot(@tooltip, @bar.task)}
        <% else %>
          <.task_summary ctx={@ctx} task={@bar.task} />
        <% end %>
      </div>
    </div>
    """
  end

  defp bar_style(bar) do
    task = bar.task

    [
      "--gx-x: #{px(bar.x)}; --gx-y: #{px(bar.y)}; --gx-w: #{px(bar.width)}; ",
      "--gx-p: #{Float.round(bar.progress * 100, 2)}%",
      task.color && "; --gx-bar-bg: #{task.color}",
      task.progress_color && "; --gx-bar-progress: #{task.progress_color}",
      task.text_color && "; --gx-bar-text: #{task.text_color}"
    ]
    |> Enum.filter(& &1)
    |> IO.iodata_to_binary()
  end

  defp bar_label(bar, ctx) do
    task = bar.task

    "#{task.text}, #{Map.fetch!(ctx.labels, task.type)}, " <>
      "#{ctx.format.(task.start_date, ctx.date_pattern)} – " <>
      "#{ctx.format.(TaskForm.display_end(task, ctx.unit), ctx.date_pattern)}"
  end

  @doc "Renders the default summary of a task (tooltip and quick info body)."
  attr :ctx, :map, required: true
  attr :task, :map, required: true

  def task_summary(assigns) do
    ~H"""
    <p class="gx-summary-title">{@task.text}</p>
    <dl class="gx-summary">
      <dt>{@ctx.labels.start}</dt>
      <dd>{@ctx.format.(@task.start_date, @ctx.date_pattern)}</dd>
      <%= if @task.type != :milestone do %>
        <dt>{@ctx.labels.end}</dt>
        <dd>{@ctx.format.(TaskForm.display_end(@task, @ctx.unit), @ctx.date_pattern)}</dd>
        <dt>{@ctx.labels.duration}</dt>
        <dd>{GanttEx.I18n.duration(@task.duration || 0, @ctx.unit, @ctx.locale)}</dd>
        <dt>{@ctx.labels.progress}</dt>
        <dd>{round(@task.progress * 100)}%</dd>
      <% end %>
    </dl>
    """
  end

  @doc "Renders the dependency arrows."
  attr :ctx, :map, required: true
  attr :links, :list, required: true
  attr :width, :integer, required: true
  attr :height, :integer, required: true

  def links(assigns) do
    ~H"""
    <svg class="gx-links" width={@width} height={@height} aria-hidden="true">
      <g
        :for={link <- @links}
        :key={link.key}
        class={["gx-link", link.selected && "gx-link--selected"]}
        style={link.link.color && "--gx-link-color: #{link.link.color}"}
        data-gx-link={link.key}
        phx-click={not @ctx.readonly && "select_link"}
        phx-value-key={link.key}
        phx-target={@ctx.myself}
      >
        <path class="gx-link-hit" d={link.d} />
        <path class="gx-link-line" d={link.d} />
        <path class="gx-link-arrow" d={link.arrow_d} />
      </g>
    </svg>
    """
  end

  @doc "Renders the weekend / non-working time highlights."
  attr :highlights, :list, required: true

  def highlights(assigns) do
    ~H"""
    <div class="gx-highlights" aria-hidden="true">
      <div
        :for={h <- @highlights}
        class="gx-highlight"
        style={"left: #{px(h.x)}; width: #{px(h.width)}"}
      >
      </div>
    </div>
    """
  end

  @doc "Renders the timeline markers (see `GanttEx.Marker`)."
  attr :ctx, :map, required: true
  attr :markers, :list, required: true

  def markers(assigns) do
    ~H"""
    <div
      :for={item <- @markers}
      id={"#{@ctx.id}-marker-#{dom_key(item.key)}"}
      class={["gx-marker", item.marker.class]}
      style={"left: #{px(item.x)}" <> if(item.marker.color, do: "; --gx-marker-color: #{item.marker.color}", else: "")}
      title={"#{item.marker.text} · #{@ctx.format.(item.marker.date, @ctx.date_pattern)}"}
    >
      <span :if={item.marker.text != ""} class="gx-marker-label">{item.marker.text}</span>
    </div>
    """
  end

  # -- popups ------------------------------------------------------------------

  @doc "Renders the quick info popup shown below a selected bar."
  attr :ctx, :map, required: true
  attr :bar, :map, required: true
  attr :editable, :boolean, default: true

  def quick_info(assigns) do
    ~H"""
    <div
      id={"#{@ctx.id}-quick-info"}
      class="gx-popup gx-quick-info"
      role="dialog"
      aria-label={@bar.task.text}
      style={"left: #{px(max(@bar.x, 0))}; top: #{px(@bar.y + @bar.height + 10)}"}
      phx-click-away="close_quick_info"
      phx-target={@ctx.myself}
    >
      <button
        type="button"
        class="gx-btn gx-btn--icon gx-popup-close"
        aria-label={@ctx.labels.close}
        phx-click="close_quick_info"
        phx-target={@ctx.myself}
      >
        <.icon name={:x_mark} />
      </button>
      <.task_summary ctx={@ctx} task={@bar.task} />
      <div :if={@editable} class="gx-popup-actions">
        <button
          :if={@ctx.lightbox}
          id={"#{@ctx.id}-quick-info-edit"}
          type="button"
          class="gx-btn"
          phx-click="open_lightbox"
          phx-value-key={@bar.key}
          phx-target={@ctx.myself}
        >
          <.icon name={:pencil} /> {@ctx.labels.edit}
        </button>
        <button
          id={"#{@ctx.id}-quick-info-delete"}
          type="button"
          class="gx-btn gx-btn--danger-ghost"
          phx-click="request_delete"
          phx-value-key={@bar.key}
          phx-target={@ctx.myself}
        >
          <.icon name={:trash} /> {@ctx.labels.delete}
        </button>
      </div>
    </div>
    """
  end

  @doc "Renders the lightbox: the task editor dialog."
  attr :ctx, :map, required: true
  attr :lightbox, :map, required: true, doc: "`%{mode, form, key, parent_options}`"
  attr :sections, :list, required: true
  slot :extra, doc: "custom fields, receives the form"

  def lightbox(assigns) do
    ~H"""
    <div
      class="gx-backdrop"
      phx-window-keydown="lightbox_cancel"
      phx-key="Escape"
      phx-target={@ctx.myself}
    >
      <div
        id={"#{@ctx.id}-lightbox"}
        class="gx-dialog"
        role="dialog"
        aria-modal="true"
        aria-labelledby={"#{@ctx.id}-lightbox-title"}
        phx-click-away="lightbox_cancel"
        phx-target={@ctx.myself}
      >
        <header class="gx-dialog-header">
          <h2 id={"#{@ctx.id}-lightbox-title"}>
            {if(@lightbox.mode == :new, do: @ctx.labels.new_task, else: @ctx.labels.edit_task)}
          </h2>
          <button
            type="button"
            class="gx-btn gx-btn--icon"
            aria-label={@ctx.labels.close}
            phx-click="lightbox_cancel"
            phx-target={@ctx.myself}
          >
            <.icon name={:x_mark} />
          </button>
        </header>
        <.form
          for={@lightbox.form}
          id={"#{@ctx.id}-lightbox-form"}
          phx-change="lightbox_change"
          phx-submit="lightbox_save"
          phx-target={@ctx.myself}
        >
          <div class="gx-dialog-body">
            <.field
              :if={:text in @sections}
              field={@lightbox.form[:text]}
              label={@ctx.labels.description}
              phx-mounted={JS.focus()}
              autocomplete="off"
            />
            <div :if={:type in @sections or :parent in @sections} class="gx-field-row">
              <.field
                :if={:type in @sections}
                field={@lightbox.form[:type]}
                type="select"
                label={@ctx.labels.type}
                options={type_options(@ctx.labels)}
              />
              <.field
                :if={:parent in @sections}
                field={@lightbox.form[:parent]}
                type="select"
                label={@ctx.labels.parent}
                options={[{@ctx.labels.no_parent, ""} | @lightbox.parent_options]}
              />
            </div>
            <fieldset :if={:time in @sections} class="gx-fieldset">
              <legend>{@ctx.labels.time_period}</legend>
              <div class="gx-field-row">
                <.field
                  field={@lightbox.form[:start_date]}
                  type={TaskForm.date_input_type(@ctx.unit)}
                  label={@ctx.labels.start}
                />
                <.field
                  :if={@lightbox.form[:type].value != "milestone"}
                  field={@lightbox.form[:duration]}
                  type="number"
                  min="0"
                  label={"#{@ctx.labels.duration} (#{GanttEx.I18n.duration(0, @ctx.unit, @ctx.locale) |> String.replace(~r/^0\s*/, "")})"}
                />
              </div>
            </fieldset>
            <.field
              :if={:progress in @sections and @lightbox.form[:type].value != "milestone"}
              field={@lightbox.form[:progress]}
              type="range"
              min="0"
              max="100"
              step="5"
              label={"#{@ctx.labels.progress}: #{@lightbox.form[:progress].value}%"}
            />
            {render_slot(@extra, @lightbox.form)}
          </div>
          <footer class="gx-dialog-footer">
            <button
              :if={@lightbox.mode == :edit}
              id={"#{@ctx.id}-lightbox-delete"}
              type="button"
              class="gx-btn gx-btn--danger-ghost"
              phx-click="request_delete"
              phx-value-key={@lightbox.key}
              phx-target={@ctx.myself}
            >
              <.icon name={:trash} /> {@ctx.labels.delete}
            </button>
            <span class="gx-toolbar-spacer"></span>
            <button
              type="button"
              class="gx-btn"
              phx-click="lightbox_cancel"
              phx-target={@ctx.myself}
            >
              {@ctx.labels.cancel}
            </button>
            <button id={"#{@ctx.id}-lightbox-save"} type="submit" class="gx-btn gx-btn--primary">
              {@ctx.labels.save}
            </button>
          </footer>
        </.form>
      </div>
    </div>
    """
  end

  @doc "Renders the dependency editor dialog."
  attr :ctx, :map, required: true
  attr :editor, :map, required: true, doc: "`%{key, form, source, target}`"

  def link_editor(assigns) do
    ~H"""
    <div class="gx-backdrop" phx-window-keydown="link_close" phx-key="Escape" phx-target={@ctx.myself}>
      <div
        id={"#{@ctx.id}-link-editor"}
        class="gx-dialog gx-dialog--small"
        role="dialog"
        aria-modal="true"
        aria-labelledby={"#{@ctx.id}-link-title"}
        phx-click-away="link_close"
        phx-target={@ctx.myself}
      >
        <header class="gx-dialog-header">
          <h2 id={"#{@ctx.id}-link-title"}>{@ctx.labels.link}</h2>
          <button
            type="button"
            class="gx-btn gx-btn--icon"
            aria-label={@ctx.labels.close}
            phx-click="link_close"
            phx-target={@ctx.myself}
          >
            <.icon name={:x_mark} />
          </button>
        </header>
        <.form
          for={@editor.form}
          id={"#{@ctx.id}-link-form"}
          phx-submit="link_save"
          phx-target={@ctx.myself}
        >
          <div class="gx-dialog-body">
            <p class="gx-link-route">
              <span class="gx-truncate">{@editor.source.text}</span>
              <span aria-hidden="true">→</span>
              <span class="gx-truncate">{@editor.target.text}</span>
            </p>
            <div class="gx-field-row">
              <.field
                field={@editor.form[:type]}
                type="select"
                label={@ctx.labels.type}
                options={
                  for type <- GanttEx.Link.types(),
                      do: {Map.fetch!(@ctx.labels, type), Atom.to_string(type)}
                }
              />
              <.field field={@editor.form[:lag]} type="number" label={@ctx.labels.lag} />
            </div>
          </div>
          <footer class="gx-dialog-footer">
            <button
              id={"#{@ctx.id}-link-delete"}
              type="button"
              class="gx-btn gx-btn--danger-ghost"
              phx-click="request_delete_link"
              phx-value-key={@editor.key}
              phx-target={@ctx.myself}
            >
              <.icon name={:trash} /> {@ctx.labels.delete}
            </button>
            <span class="gx-toolbar-spacer"></span>
            <button type="button" class="gx-btn" phx-click="link_close" phx-target={@ctx.myself}>
              {@ctx.labels.cancel}
            </button>
            <button id={"#{@ctx.id}-link-save"} type="submit" class="gx-btn gx-btn--primary">
              {@ctx.labels.save}
            </button>
          </footer>
        </.form>
      </div>
    </div>
    """
  end

  @doc "Renders a confirmation dialog."
  attr :ctx, :map, required: true
  attr :confirm, :map, required: true, doc: "`%{message, detail}`"

  def confirm(assigns) do
    ~H"""
    <div
      class="gx-backdrop gx-backdrop--top"
      phx-window-keydown="confirm_no"
      phx-key="Escape"
      phx-target={@ctx.myself}
    >
      <div
        id={"#{@ctx.id}-confirm"}
        class="gx-dialog gx-dialog--small"
        role="alertdialog"
        aria-modal="true"
        aria-labelledby={"#{@ctx.id}-confirm-message"}
      >
        <div class="gx-dialog-body gx-confirm">
          <span class="gx-confirm-icon"><.icon name={:exclamation} /></span>
          <div>
            <p id={"#{@ctx.id}-confirm-message"} class="gx-confirm-message">{@confirm.message}</p>
            <p :if={@confirm[:detail]} class="gx-confirm-detail">{@confirm.detail}</p>
          </div>
        </div>
        <footer class="gx-dialog-footer">
          <span class="gx-toolbar-spacer"></span>
          <button
            id={"#{@ctx.id}-confirm-no"}
            type="button"
            class="gx-btn"
            phx-click="confirm_no"
            phx-target={@ctx.myself}
          >
            {@ctx.labels.no}
          </button>
          <button
            id={"#{@ctx.id}-confirm-yes"}
            type="button"
            class="gx-btn gx-btn--danger"
            phx-click="confirm_yes"
            phx-target={@ctx.myself}
            phx-mounted={JS.focus()}
          >
            {@ctx.labels.yes}
          </button>
        </footer>
      </div>
    </div>
    """
  end

  # -- form fields -------------------------------------------------------------

  @doc """
  Renders a labelled form field with its errors. Errors are expected to be
  already translated strings (`{message, []}` tuples).
  """
  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, required: true
  attr :type, :string, default: "text"
  attr :options, :list, default: []
  attr :rest, :global, include: ~w(min max step autocomplete)

  def field(%{type: "select"} = assigns) do
    ~H"""
    <div class="gx-field">
      <label for={@field.id}>{@label}</label>
      <select id={@field.id} name={@field.name} class="gx-input" {@rest}>
        {Phoenix.HTML.Form.options_for_select(@options, @field.value)}
      </select>
      <.field_errors field={@field} />
    </div>
    """
  end

  def field(assigns) do
    ~H"""
    <div class={["gx-field", @type == "range" && "gx-field--range"]}>
      <label for={@field.id}>{@label}</label>
      <input
        id={@field.id}
        name={@field.name}
        type={@type}
        value={Phoenix.HTML.Form.normalize_value(@type, @field.value)}
        class={["gx-input", @field.errors != [] && "gx-input--invalid"]}
        aria-invalid={to_string(@field.errors != [])}
        {@rest}
      />
      <.field_errors field={@field} />
    </div>
    """
  end

  attr :field, Phoenix.HTML.FormField, required: true

  defp field_errors(assigns) do
    ~H"""
    <p :for={{message, _opts} <- @field.errors} class="gx-error">{message}</p>
    """
  end

  # -- helpers -----------------------------------------------------------------

  @doc """
  Formats a pixel value for inline styles.

      iex> GanttEx.Live.Components.px(12.5)
      "12.5px"

      iex> GanttEx.Live.Components.px(40)
      "40px"
  """
  @spec px(number()) :: String.t()
  def px(value) when is_integer(value), do: "#{value}px"

  def px(value) when is_float(value),
    do: "#{Float.round(value, 2)}px" |> String.replace(".0px", "px")

  @doc """
  Turns a key into a string usable in DOM ids.

      iex> GanttEx.Live.Components.dom_key("42")
      "42"

      iex> GanttEx.Live.Components.dom_key("a b") =~ ~r/^k[0-9a-z]+$/
      true
  """
  @spec dom_key(Store.key()) :: String.t()
  def dom_key(key) do
    if Regex.match?(~r/^[A-Za-z0-9_-]+$/, key),
      do: key,
      else:
        ("k" <> Integer.to_string(:erlang.phash2(key, 4_294_967_296), 36)) |> String.downcase()
  end
end
