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
    * `:reorder` - whether rows can be dragged: `:ok`, or why not
      (`:sorted`, `:filtered` or `:disabled`)
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
  attr :show_critical, :boolean, default: false

  attr :filters, :map,
    default: nil,
    doc:
      "`%{definitions, values, queries}` for the search and the filter panel, `nil` to hide them"

  attr :popover, :atom, default: nil, doc: "the open popover: `:filters`, `:columns` or `nil`"

  attr :columns, :any,
    default: nil,
    doc: "every available column for the column chooser (see `GanttEx.Live.Columns.available/3`)"

  slot :inner_block

  def toolbar(assigns) do
    assigns =
      assign(assigns,
        can_zoom_in: GanttEx.Zoom.can_zoom?(assigns.levels, assigns.zoom, :in),
        can_zoom_out: GanttEx.Zoom.can_zoom?(assigns.levels, assigns.zoom, :out),
        lookahead:
          assigns.filters && Enum.find(assigns.filters.definitions, &(&1.kind == :lookahead))
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
        id={"#{@ctx.id}-critical-path"}
        type="button"
        class={["gx-btn", @show_critical && "gx-btn--active"]}
        aria-pressed={to_string(@show_critical)}
        phx-click="toggle_critical"
        phx-target={@ctx.myself}
      >
        <.icon name={:bolt} />
        <span>{@ctx.labels.critical_path}</span>
      </button>

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

      <.lookahead_menu
        :if={@lookahead}
        ctx={@ctx}
        definition={@lookahead}
        value={@filters.values[@lookahead.id]}
        range={@filters[:lookahead]}
      />

      <div class="gx-toolbar-spacer"></div>

      <.search_box
        :if={@filters && Enum.any?(@filters.definitions, &(&1.kind == :search))}
        ctx={@ctx}
        value={@filters.values[:search]}
      />
      <.filter_menu
        :if={@filters && Enum.any?(@filters.definitions, &(&1.kind not in [:search, :lookahead]))}
        ctx={@ctx}
        filters={@filters}
        open={@popover == :filters}
      />
      <.column_menu :if={@columns} ctx={@ctx} columns={@columns} open={@popover == :columns} />

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

  # -- filters -----------------------------------------------------------------

  @doc "Renders the search input of the toolbar (see `GanttEx.Filter`)."
  attr :ctx, :map, required: true
  attr :value, :string, default: nil

  def search_box(assigns) do
    ~H"""
    <form
      id={"#{@ctx.id}-search"}
      class={["gx-search", @value && "gx-search--active"]}
      role="search"
      phx-change="filter_search"
      phx-submit="filter_search"
      phx-target={@ctx.myself}
    >
      <.icon name={:magnifying_glass} class="gx-search-icon" />
      <input
        id={"#{@ctx.id}-search-input"}
        type="search"
        name="search"
        value={@value}
        class="gx-search-input"
        placeholder={@ctx.labels.search_tasks}
        aria-label={@ctx.labels.search_tasks}
        autocomplete="off"
        spellcheck="false"
        phx-debounce="300"
      />
      <button
        :if={@value}
        id={"#{@ctx.id}-search-clear"}
        type="button"
        class="gx-search-clear"
        title={@ctx.labels.clear_search}
        aria-label={@ctx.labels.clear_search}
        phx-click={
          JS.push("filter_clear", value: %{filter: "search"}, target: @ctx.myself)
          |> JS.focus(to: "##{@ctx.id}-search-input")
        }
      >
        <.icon name={:x_mark} />
      </button>
    </form>
    """
  end

  @doc """
  Renders the lookahead menu of the toolbar: the number of weeks to show
  from the current week, or the whole schedule (see `GanttEx.Filter`).
  """
  attr :ctx, :map, required: true
  attr :definition, :map, required: true
  attr :value, :any, default: nil, doc: "the selected number of weeks"
  attr :range, :map, default: nil, doc: "`%{from, to}`, the days shown"

  def lookahead_menu(assigns) do
    assigns =
      assign(assigns,
        selected: Enum.find(assigns.definition.options, &(&1.value == assigns.value)),
        menu_id: "#{assigns.ctx.id}-lookahead"
      )

    ~H"""
    <details id={@menu_id} class="gx-menu gx-lookahead">
      <summary
        id={"#{@menu_id}-toggle"}
        class={["gx-btn", @selected && "gx-btn--active"]}
        title={@range && range_text(@range, @ctx)}
      >
        <.icon name={:calendar_days} />
        <span>{@definition.label}</span>
        <span :if={@selected} class="gx-badge">{@selected.label}</span>
      </summary>
      <div class="gx-menu-list" role="menu" aria-label={@definition.label}>
        <button
          id={"#{@menu_id}-off"}
          type="button"
          role="menuitemradio"
          aria-checked={to_string(is_nil(@selected))}
          class={["gx-menu-item", is_nil(@selected) && "gx-menu-item--checked"]}
          phx-click={lookahead_pick(@ctx, @menu_id, "")}
        >
          <.icon name={:check} class={["gx-menu-check", @selected && "gx-invisible"]} />
          {@ctx.labels.lookahead_off}
        </button>
        <button
          :for={option <- @definition.options}
          id={"#{@menu_id}-#{option.key}"}
          type="button"
          role="menuitemradio"
          aria-checked={to_string(@selected == option)}
          class={["gx-menu-item", @selected == option && "gx-menu-item--checked"]}
          phx-click={lookahead_pick(@ctx, @menu_id, option.key)}
        >
          <.icon name={:check} class={["gx-menu-check", @selected != option && "gx-invisible"]} />
          {option.label}
        </button>
      </div>
    </details>
    """
  end

  defp lookahead_pick(ctx, menu_id, weeks) do
    JS.push("lookahead", value: %{weeks: weeks}, target: ctx.myself)
    |> JS.remove_attribute("open", to: "#" <> menu_id)
  end

  defp range_text(%{from: from, to: to}, ctx) do
    format = &ctx.format.(NaiveDateTime.new!(&1, ~T[00:00:00]), :date)
    "#{format.(from)} – #{format.(to)}"
  end

  @doc """
  Renders the "Filters" toolbar button and its panel. `filters` holds the
  `:definitions` and the normalized `:values` (see `GanttEx.Filter`), and the
  `:queries` typed in the searchable filters.
  """
  attr :ctx, :map, required: true
  attr :filters, :map, required: true
  attr :open, :boolean, default: false

  def filter_menu(assigns) do
    assigns =
      assign(assigns,
        active: map_size(Map.drop(assigns.filters.values, [:search, :lookahead])),
        panel: Enum.reject(assigns.filters.definitions, &(&1.kind in [:search, :lookahead]))
      )

    ~H"""
    <div
      class="gx-popover-anchor"
      phx-click-away={@open && JS.push("close_popover", target: @ctx.myself)}
    >
      <button
        id={"#{@ctx.id}-filters-toggle"}
        type="button"
        class={["gx-btn", (@open or @active > 0) && "gx-btn--active"]}
        aria-haspopup="dialog"
        aria-expanded={to_string(@open)}
        aria-controls={"#{@ctx.id}-filters"}
        phx-click="toggle_popover"
        phx-value-popover="filters"
        phx-target={@ctx.myself}
      >
        <.icon name={:funnel} />
        <span>{@ctx.labels.filters}</span>
        <span
          :if={@active > 0}
          class="gx-badge"
          title={GanttEx.I18n.active_filters(@active, @ctx.locale)}
        >
          {@active}
        </span>
      </button>
      <div
        :if={@open}
        id={"#{@ctx.id}-filters"}
        class="gx-popover gx-filters"
        role="dialog"
        aria-label={@ctx.labels.filters}
        phx-mounted={JS.focus_first(to: "##{@ctx.id}-filters-form")}
        phx-window-keydown={
          JS.push("close_popover", target: @ctx.myself)
          |> JS.focus(to: "##{@ctx.id}-filters-toggle")
        }
        phx-key="Escape"
      >
        <header class="gx-popover-header">
          <h2 class="gx-popover-title">{@ctx.labels.filters}</h2>
          <button
            :if={@active > 0}
            id={"#{@ctx.id}-filters-clear"}
            type="button"
            class="gx-text-btn"
            phx-click="filters_clear"
            phx-target={@ctx.myself}
          >
            {@ctx.labels.clear_filters}
          </button>
          <button
            type="button"
            class="gx-btn gx-btn--icon gx-btn--small"
            aria-label={@ctx.labels.close}
            phx-click={
              JS.push("close_popover", target: @ctx.myself)
              |> JS.focus(to: "##{@ctx.id}-filters-toggle")
            }
          >
            <.icon name={:x_mark} />
          </button>
        </header>
        <form
          id={"#{@ctx.id}-filters-form"}
          class="gx-filters-form"
          phx-change="filters_change"
          phx-submit="filters_change"
          phx-target={@ctx.myself}
        >
          <.filter_field
            :for={definition <- @panel}
            ctx={@ctx}
            definition={definition}
            value={Map.get(@filters.values, definition.id)}
            query={Map.get(@filters.queries, definition.id, "")}
          />
        </form>
      </div>
    </div>
    """
  end

  @doc """
  Renders the "Columns" toolbar button and the column chooser: every
  available column can be shown or hidden, moved with the drag handle or
  the arrow buttons, and the defaults restored.
  """
  attr :ctx, :map, required: true
  attr :columns, :list, required: true, doc: "from `GanttEx.Live.Columns.available/3`"
  attr :open, :boolean, default: false

  def column_menu(assigns) do
    assigns = assign(assigns, last: length(assigns.columns) - 1)

    ~H"""
    <div
      class="gx-popover-anchor"
      phx-click-away={@open && JS.push("close_popover", target: @ctx.myself)}
    >
      <button
        id={"#{@ctx.id}-columns-toggle"}
        type="button"
        class={["gx-btn gx-btn--icon", @open && "gx-btn--active"]}
        title={@ctx.labels.columns}
        aria-label={@ctx.labels.columns}
        aria-haspopup="dialog"
        aria-expanded={to_string(@open)}
        aria-controls={"#{@ctx.id}-columns"}
        phx-click="toggle_popover"
        phx-value-popover="columns"
        phx-target={@ctx.myself}
      >
        <.icon name={:view_columns} />
      </button>
      <div
        :if={@open}
        id={"#{@ctx.id}-columns"}
        class="gx-popover gx-columns"
        role="dialog"
        aria-label={@ctx.labels.columns}
        phx-mounted={JS.focus_first(to: "##{@ctx.id}-columns-form")}
        phx-window-keydown={
          JS.push("close_popover", target: @ctx.myself)
          |> JS.focus(to: "##{@ctx.id}-columns-toggle")
        }
        phx-key="Escape"
      >
        <header class="gx-popover-header">
          <h2 class="gx-popover-title">{@ctx.labels.columns}</h2>
          <button
            id={"#{@ctx.id}-columns-reset"}
            type="button"
            class="gx-text-btn"
            phx-click="columns_reset"
            phx-target={@ctx.myself}
          >
            <.icon name={:arrow_path} /> {@ctx.labels.reset}
          </button>
          <button
            type="button"
            class="gx-btn gx-btn--icon gx-btn--small"
            aria-label={@ctx.labels.close}
            phx-click={
              JS.push("close_popover", target: @ctx.myself)
              |> JS.focus(to: "##{@ctx.id}-columns-toggle")
            }
          >
            <.icon name={:x_mark} />
          </button>
        </header>
        <form
          id={"#{@ctx.id}-columns-form"}
          class="gx-columns-form"
          phx-change="columns_visibility"
          phx-target={@ctx.myself}
        >
          <input type="hidden" name="visible[]" value="" />
          <div class="gx-column-list" data-gx-column-list="vertical">
            <ul role="list">
              <li
                :for={{col, index} <- Enum.with_index(@columns)}
                id={"#{@ctx.id}-column-#{dom_key(col.key)}"}
                class={["gx-column-item", not col.visible && "gx-column-item--hidden"]}
                data-gx-column={col.key}
                data-gx-column-item={col.key}
              >
                <span class="gx-column-grip" title={@ctx.labels.drag_to_reorder} aria-hidden="true">
                  <.icon name={:grip} />
                </span>
                <label class="gx-option gx-column-check">
                  <input
                    type="checkbox"
                    name="visible[]"
                    value={col.key}
                    checked={col.visible}
                    disabled={col.tree}
                  />
                  <span class="gx-option-check" aria-hidden="true"><.icon name={:check} /></span>
                  <span class="gx-truncate">{col.title}</span>
                </label>
                <button
                  type="button"
                  class="gx-action gx-column-move"
                  title={@ctx.labels.move_up}
                  aria-label={"#{@ctx.labels.move_up}: #{col.title}"}
                  disabled={index == 0}
                  data-gx-no-drag
                  data-gx-move="up"
                  phx-click="column_move"
                  phx-value-field={col.key}
                  phx-value-direction="up"
                  phx-target={@ctx.myself}
                >
                  <.icon name={:chevron_up} />
                </button>
                <button
                  type="button"
                  class="gx-action gx-column-move"
                  title={@ctx.labels.move_down}
                  aria-label={"#{@ctx.labels.move_down}: #{col.title}"}
                  disabled={index == @last}
                  data-gx-no-drag
                  data-gx-move="down"
                  phx-click="column_move"
                  phx-value-field={col.key}
                  phx-value-direction="down"
                  phx-target={@ctx.myself}
                >
                  <.icon name={:chevron_down} />
                </button>
              </li>
            </ul>
            <span
              id={"#{@ctx.id}-columns-marker"}
              class="gx-column-marker"
              aria-hidden="true"
              phx-update="ignore"
              data-gx-column-marker
            ></span>
          </div>
        </form>
      </div>
    </div>
    """
  end

  attr :ctx, :map, required: true
  attr :definition, :map, required: true
  attr :value, :any, default: nil
  attr :query, :string, default: ""

  defp filter_field(%{definition: %{kind: :dates}} = assigns) do
    assigns =
      assign(assigns,
        dom_id: filter_dom_id(assigns.ctx, assigns.definition),
        invalid: GanttEx.Filter.invalid_range?(assigns.value)
      )

    ~H"""
    <fieldset id={@dom_id} class="gx-filter gx-filter--dates">
      <legend class="gx-filter-legend">
        <span>{@definition.label}</span>
        <.filter_clear :if={@value} ctx={@ctx} definition={@definition} />
      </legend>
      <div class="gx-filter-dates">
        <label class="gx-field" for={"#{@dom_id}-from"}>
          <span>{@ctx.labels.from}</span>
          <input
            id={"#{@dom_id}-from"}
            type="date"
            name={"filters[#{@definition.id}][from]"}
            value={@value && @value.from && Date.to_iso8601(@value.from)}
            class="gx-input gx-input--small"
          />
        </label>
        <label class="gx-field" for={"#{@dom_id}-to"}>
          <span>{@ctx.labels.to}</span>
          <input
            id={"#{@dom_id}-to"}
            type="date"
            name={"filters[#{@definition.id}][to]"}
            value={@value && @value.to && Date.to_iso8601(@value.to)}
            class={["gx-input gx-input--small", @invalid && "gx-input--invalid"]}
            aria-invalid={to_string(@invalid)}
          />
        </label>
      </div>
      <p :if={@invalid} class="gx-error">{@ctx.labels.end_before_start}</p>
    </fieldset>
    """
  end

  # Statuses and types: checkable chips
  defp filter_field(%{definition: %{kind: kind}} = assigns) when kind in [:status, :type] do
    assigns =
      assign(assigns,
        dom_id: filter_dom_id(assigns.ctx, assigns.definition),
        selected: MapSet.new(List.wrap(assigns.value), &GanttEx.Filter.option_key/1)
      )

    ~H"""
    <fieldset id={@dom_id} class="gx-filter">
      <legend class="gx-filter-legend">
        <span>{@definition.label}</span>
        <.filter_clear :if={@value} ctx={@ctx} definition={@definition} />
      </legend>
      <input type="hidden" name={"filters[#{@definition.id}][]"} value="" />
      <div class="gx-chips">
        <label
          :for={option <- @definition.options}
          id={"#{@dom_id}-#{option.key}"}
          class={["gx-chip-check", MapSet.member?(@selected, option.key) && "gx-chip-check--on"]}
        >
          <input
            type="checkbox"
            name={"filters[#{@definition.id}][]"}
            value={option.key}
            checked={MapSet.member?(@selected, option.key)}
          />
          <span
            :if={@definition.kind == :type}
            class={["gx-type-dot", "gx-type-dot--#{option.key}"]}
          ></span>
          <.option_visual option={option} />
          <span>{option.label}</span>
        </label>
      </div>
    </fieldset>
    """
  end

  # Custom filters: a combobox with removable chips, a search input and the options
  defp filter_field(%{definition: %{kind: :options}} = assigns) do
    definition = assigns.definition
    selected = List.wrap(assigns.value)
    selected_keys = MapSet.new(selected, &GanttEx.Filter.option_key/1)
    query = if definition.searchable, do: assigns.query, else: ""
    {shown, more} = GanttEx.Filter.search_options(definition, query, 50)
    shown_keys = MapSet.new(shown, & &1.key)

    assigns =
      assign(assigns,
        dom_id: filter_dom_id(assigns.ctx, definition),
        chips: Enum.filter(definition.options, &MapSet.member?(selected_keys, &1.key)),
        selected_keys: selected_keys,
        # selected options filtered out of the list keep being submitted
        kept: Enum.reject(selected_keys, &MapSet.member?(shown_keys, &1)),
        shown: shown,
        more: more,
        input_type: if(definition.multiple, do: "checkbox", else: "radio")
      )

    ~H"""
    <fieldset
      id={@dom_id}
      class={["gx-filter gx-combobox", @definition.searchable && "gx-combobox--searchable"]}
    >
      <legend class="gx-filter-legend">
        <span>{@definition.label}</span>
        <.filter_clear :if={@value} ctx={@ctx} definition={@definition} />
      </legend>
      <div :if={@chips != []} class="gx-chips gx-combobox-chips">
        <span :for={option <- @chips} id={"#{@dom_id}-chip-#{dom_key(option.key)}"} class="gx-chip">
          <.option_visual option={option} />
          <span class="gx-truncate">{option.label}</span>
          <button
            type="button"
            class="gx-chip-remove"
            title={GanttEx.I18n.remove(option.label, @ctx.locale)}
            aria-label={GanttEx.I18n.remove(option.label, @ctx.locale)}
            phx-click="filter_remove"
            phx-value-filter={@definition.id}
            phx-value-value={option.key}
            phx-target={@ctx.myself}
          >
            <.icon name={:x_mark} />
          </button>
        </span>
      </div>
      <div :if={@definition.searchable} class="gx-combobox-search">
        <.icon name={:magnifying_glass} />
        <input
          id={"#{@dom_id}-query"}
          type="search"
          name={"queries[#{@definition.id}]"}
          value={@query}
          class="gx-combobox-input"
          placeholder={@definition.placeholder || @ctx.labels.search}
          aria-label={"#{@ctx.labels.search}: #{@definition.label}"}
          aria-controls={"#{@dom_id}-options"}
          autocomplete="off"
          spellcheck="false"
          phx-debounce="250"
        />
      </div>
      <input type="hidden" name={"filters[#{@definition.id}][]"} value="" />
      <input :for={key <- @kept} type="hidden" name={"filters[#{@definition.id}][]"} value={key} />
      <div
        id={"#{@dom_id}-options"}
        class="gx-options"
        role="group"
        aria-label={@definition.label}
      >
        <label
          :for={option <- @shown}
          id={"#{@dom_id}-option-#{dom_key(option.key)}"}
          class={["gx-option", MapSet.member?(@selected_keys, option.key) && "gx-option--checked"]}
        >
          <input
            type={@input_type}
            name={"filters[#{@definition.id}][]"}
            value={option.key}
            checked={MapSet.member?(@selected_keys, option.key)}
          />
          <span class={["gx-option-check", "gx-option-check--#{@input_type}"]} aria-hidden="true">
            <.icon name={:check} />
          </span>
          <.option_visual option={option} />
          <span class="gx-option-text">
            <span class="gx-truncate">{option.label}</span>
            <span :if={option.hint} class="gx-option-hint gx-truncate">{option.hint}</span>
          </span>
        </label>
        <p :if={@shown == []} class="gx-options-empty">{@ctx.labels.no_options}</p>
        <p :if={@more > 0} class="gx-options-more">
          {GanttEx.I18n.more_options(@more, @ctx.locale)}
        </p>
      </div>
    </fieldset>
    """
  end

  attr :ctx, :map, required: true
  attr :definition, :map, required: true

  defp filter_clear(assigns) do
    ~H"""
    <button
      id={"#{filter_dom_id(@ctx, @definition)}-clear"}
      type="button"
      class="gx-text-btn"
      phx-click="filter_clear"
      phx-value-filter={@definition.id}
      phx-target={@ctx.myself}
    >
      {@ctx.labels.clear}
    </button>
    """
  end

  attr :option, :map, required: true

  # The avatar, logo, color or icon of an option
  defp option_visual(assigns) do
    ~H"""
    <%= cond do %>
      <% @option.image -> %>
        <img class="gx-avatar" src={@option.image} alt="" loading="lazy" />
      <% @option[:icon] -> %>
        <span class={["gx-option-icon", "gx-option-icon--#{@option.key}"]}>
          <.icon name={@option.icon} />
        </span>
      <% @option.color -> %>
        <span class="gx-dot" style={"--gx-dot: #{@option.color}"}></span>
      <% true -> %>
    <% end %>
    """
  end

  defp filter_dom_id(ctx, definition), do: "#{ctx.id}-filter-#{dom_key(to_string(definition.id))}"

  @doc """
  Renders the bar shown while filters are active: how many tasks match, the
  active filters (each one can be removed) and a "Clear filters" action.
  """
  attr :ctx, :map, required: true
  attr :filters, :map, required: true, doc: "`%{definitions, values}`"
  attr :matched, :integer, required: true
  attr :total, :integer, required: true

  def filter_status(assigns) do
    active =
      for definition <- assigns.filters.definitions,
          value = Map.get(assigns.filters.values, definition.id),
          value != nil,
          do:
            {definition,
             filter_summary(
               definition,
               value,
               Map.put(assigns.ctx, :lookahead, assigns.filters[:lookahead])
             )}

    assigns = assign(assigns, active: active)

    ~H"""
    <div id={"#{@ctx.id}-filter-bar"} class="gx-filter-bar">
      <span class="gx-filter-count" role="status">
        <.icon name={:funnel} />
        {GanttEx.I18n.filtered_tasks(@matched, @total, @ctx.locale)}
      </span>
      <span
        :for={{definition, summary} <- @active}
        id={"#{filter_dom_id(@ctx, definition)}-active"}
        class="gx-chip gx-chip--summary"
      >
        <span class="gx-truncate">
          <span :if={definition.kind != :search} class="gx-chip-label">{definition.label}:</span>
          {summary}
        </span>
        <button
          type="button"
          class="gx-chip-remove"
          title={GanttEx.I18n.remove(definition.label, @ctx.locale)}
          aria-label={GanttEx.I18n.remove(definition.label, @ctx.locale)}
          phx-click="filter_clear"
          phx-value-filter={definition.id}
          phx-target={@ctx.myself}
        >
          <.icon name={:x_mark} />
        </button>
      </span>
      <button
        id={"#{@ctx.id}-clear-filters"}
        type="button"
        class="gx-text-btn"
        phx-click="filters_clear"
        phx-target={@ctx.myself}
      >
        {@ctx.labels.clear_filters}
      </button>
    </div>
    """
  end

  defp filter_summary(%{kind: :search}, value, _ctx), do: "“#{value}”"

  defp filter_summary(%{kind: :dates}, %{from: from, to: to}, ctx) do
    format = &(&1 && ctx.format.(NaiveDateTime.new!(&1, ~T[00:00:00]), :date))

    case {format.(from), format.(to)} do
      {from, nil} -> "≥ #{from}"
      {nil, to} -> "≤ #{to}"
      {from, to} -> "#{from} – #{to}"
    end
  end

  defp filter_summary(%{kind: :lookahead} = definition, weeks, ctx) do
    label = Enum.find_value(definition.options, &(&1.value == weeks && &1.label))

    case Map.get(ctx, :lookahead) do
      nil -> label
      range -> "#{label} · #{range_text(range, ctx)}"
    end
  end

  defp filter_summary(definition, values, _ctx) do
    keys = MapSet.new(values, &GanttEx.Filter.option_key/1)

    definition.options
    |> Enum.filter(&MapSet.member?(keys, &1.key))
    |> Enum.map_join(", ", & &1.label)
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
    <div class="gx-grid-head" role="row" data-gx-column-list="horizontal">
      <div
        :for={{col, index} <- Enum.with_index(@columns)}
        id={"#{@ctx.id}-head-#{dom_key(column_key(col))}"}
        role="columnheader"
        class={["gx-head-cell", col.tree && "gx-cell--tree", "gx-align-#{col.align}"]}
        style={column_style(col, index)}
        aria-sort={aria_sort(@sort, col)}
        data-gx-column={column_key(col)}
      >
        <%= cond do %>
          <% col.field == :actions -> %>
            <span class="gx-sr-only">{col.label}</span>
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
      <span
        id={"#{@ctx.id}-head-marker"}
        class="gx-column-marker"
        aria-hidden="true"
        phx-update="ignore"
        data-gx-column-marker
      ></span>
    </div>
    """
  end

  defp column_key(col), do: Map.get_lazy(col, :key, fn -> to_string(col.field) end)

  # The tree column takes the free width but keeps a minimum: when the grid is
  # narrowed, the columns on its right are clipped before the task names
  defp column_style(%{tree: true}, _index), do: "flex: 1 1 0; min-width: 120px"
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
      id={"#{@ctx.id}-row-#{dom_key(@row[:uid] || @row.key)}"}
      class={[
        "gx-row",
        @row.selected && "gx-row--selected",
        @row.task.type == :project && "gx-row--project",
        @row[:group] && "gx-row--group",
        @row.task.blocked && "gx-row--blocked",
        @row.task.restrictions > 0 && "gx-row--restricted"
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
      class={["gx-toggle", @row.open && "gx-toggle--open", @row[:loading] && "gx-toggle--loading"]}
      aria-label={if(@row.open, do: @ctx.labels.collapse, else: @ctx.labels.expand)}
      phx-click="toggle"
      phx-value-key={@row.key}
      phx-target={@ctx.myself}
    >
      <.icon name={:chevron_right} />
    </button>
    <span :if={not @row.has_children} class="gx-toggle-spacer"></span>
    <span :if={not @row[:group]} class={["gx-type-dot", "gx-type-dot--#{@row.task.type}"]}></span>
    <span class="gx-truncate">
      <%= if @column.inner_block && not @row[:group] do %>
        {render_slot(@column, @row.task)}
      <% else %>
        {cell_value(@row.task, @column, @ctx)}
      <% end %>
    </span>
    <.status_flags :if={not @row[:group]} ctx={@ctx} task={@row.task} />
    <span :if={@row[:group]} class="gx-count">{@row.count}</span>
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

  defp cell_content(%{column: %{field: :actions}} = assigns) do
    ~H"""
    <div :if={not @row[:group]} class="gx-actions">
      <.row_action
        :for={action <- @column.actions}
        :if={action_shown?(action, @row.task, @ctx)}
        ctx={@ctx}
        row={@row}
        action={action}
      />
    </div>
    """
  end

  defp cell_content(%{column: %{field: field, inner_block: nil}} = assigns)
       when field in [:total_slack, :free_slack] do
    assigns = assign(assigns, :slack, assigns.row[:slack] && Map.fetch!(assigns.row.slack, field))

    ~H"""
    <span class={["gx-truncate", @slack == 0 && "gx-critical-text"]}>
      {if @slack, do: GanttEx.I18n.duration(@slack, @ctx.unit, @ctx.locale)}
    </span>
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
      <%= if @column.inner_block && not @row[:group] do %>
        {render_slot(@column, @row.task)}
      <% else %>
        {cell_value(@row.task, @column, @ctx)}
      <% end %>
    </span>
    """
  end

  attr :ctx, :map, required: true
  attr :task, :map, required: true

  # The lock of blocked tasks and the number of open restrictions, next to the name
  defp status_flags(assigns) do
    assigns =
      assign(assigns,
        restrictions:
          assigns.task.restrictions > 0 &&
            GanttEx.I18n.restrictions(assigns.task.restrictions, assigns.ctx.locale)
      )

    ~H"""
    <span
      :if={@task.blocked}
      class="gx-flag gx-flag--blocked"
      role="img"
      title={@ctx.labels.blocked}
      aria-label={@ctx.labels.blocked}
    >
      <.icon name={:lock_closed} />
    </span>
    <span
      :if={@restrictions}
      class="gx-flag gx-flag--restricted"
      role="img"
      title={@restrictions}
      aria-label={@restrictions}
    >
      <.icon name={:exclamation_triangle} />
      <span class="gx-flag-count" aria-hidden="true">{@task.restrictions}</span>
    </span>
    """
  end

  # Actions that edit are hidden on read-only tasks
  defp action_shown?(%{editing: true}, task, ctx) when ctx.readonly or task.readonly, do: false
  defp action_shown?(%{id: :edit, builtin: true}, _task, ctx), do: ctx.lightbox
  defp action_shown?(_action, _task, _ctx), do: true

  attr :ctx, :map, required: true
  attr :row, :map, required: true
  attr :action, :map, required: true

  defp row_action(%{action: %{id: :drag, builtin: true}} = assigns) do
    reorder = Map.get(assigns.ctx, :reorder, :ok)

    assigns =
      assign(assigns,
        disabled: reorder != :ok,
        title:
          case reorder do
            :ok -> assigns.ctx.labels.drag_to_reorder
            :sorted -> assigns.ctx.labels.reorder_sorted
            :filtered -> assigns.ctx.labels.reorder_filtered
            _disabled -> assigns.ctx.labels.reorder_disabled
          end
      )

    ~H"""
    <button
      id={action_dom_id(@ctx, @row, @action)}
      type="button"
      class="gx-action gx-action--drag"
      title={@title}
      aria-label={@title}
      aria-disabled={to_string(@disabled)}
      data-gx-drag-handle
      phx-keydown={not @disabled && "row_key"}
      phx-value-row={@row.key}
      phx-target={@ctx.myself}
    >
      <.icon name={:grip} />
    </button>
    """
  end

  defp row_action(assigns) do
    %{action: action, row: %{task: task}, ctx: ctx} = assigns
    block = action.builtin and action.id == :block

    assigns =
      assign(assigns,
        icon: if(block and task.blocked, do: :lock_closed, else: action.icon),
        label: if(block and task.blocked, do: ctx.labels.unblock_task, else: action.label),
        on: block and task.blocked
      )

    ~H"""
    <button
      id={action_dom_id(@ctx, @row, @action)}
      type="button"
      class={["gx-action", "gx-action--#{dom_key(to_string(@action.id))}", @on && "gx-action--on"]}
      title={@label}
      aria-label={@label}
      phx-click="row_action"
      phx-value-action={@action.id}
      phx-value-key={@row.key}
      phx-target={@ctx.myself}
    >
      <.icon name={@icon} />
    </button>
    """
  end

  defp action_dom_id(ctx, row, action),
    do: "#{ctx.id}-row-#{dom_key(row[:uid] || row.key)}-#{dom_key(to_string(action.id))}"

  @doc false
  def cell_value(task, %{field: field}, ctx) do
    case field do
      :text ->
        task.text

      :start_date ->
        ctx.format.(task.start_date, ctx.date_pattern)

      :end_date ->
        ctx.format.(TaskForm.display_end(task, ctx.unit), ctx.date_pattern)

      :duration ->
        to_string(task.duration)

      :progress ->
        "#{round(task.progress * 100)}%"

      :type ->
        Map.fetch!(ctx.labels, task.type)

      :constraint_type ->
        if(task.constraint_type, do: Map.fetch!(ctx.labels, task.constraint_type), else: "")

      field when field in [:total_slack, :free_slack] ->
        ""

      :planned_start ->
        ctx.format.(task.planned_start, ctx.date_pattern)

      :resources ->
        Enum.map_join(task.resources, ", ", fn assignment ->
          case Map.get(ctx[:resources] || %{}, Store.key(assignment.id)) do
            nil -> to_string(assignment.id)
            resource -> resource.text
          end
        end)

      :planned_end ->
        ctx.format.(
          TaskForm.inclusive_end(task.planned_end, task.planned_start, ctx.unit),
          ctx.date_pattern
        )

      :deadline ->
        ctx.format.(task.deadline, ctx.date_pattern)

      field ->
        task.meta |> meta_value(field) |> to_string()
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
      :start_date ->
        TaskForm.input_date(task.start_date, ctx.unit)

      :planned_start ->
        TaskForm.input_date(task.planned_start, ctx.unit)

      :planned_end ->
        TaskForm.input_date(
          TaskForm.inclusive_end(task.planned_end, task.planned_start, ctx.unit),
          ctx.unit
        )

      :deadline ->
        TaskForm.input_date(task.deadline, ctx.unit)

      :end_date ->
        TaskForm.input_date(TaskForm.display_end(task, ctx.unit), ctx.unit)

      :progress ->
        task.progress |> Kernel.*(100) |> round() |> Integer.to_string()

      :type ->
        Atom.to_string(task.type)

      :duration ->
        to_string(task.duration)

      :text ->
        task.text

      field ->
        task.meta |> meta_value(field) |> to_string()
    end
  end

  defp type_options(labels) do
    [{labels.task, "task"}, {labels.project, "project"}, {labels.milestone, "milestone"}]
  end

  # -- scale -------------------------------------------------------------------

  @doc "Renders the time scale header."
  attr :rows, :list, required: true
  attr :width, :integer, required: true
  attr :band, :map, default: nil, doc: "`%{x, width}`, the week of the weekly plan"

  def scale(assigns) do
    ~H"""
    <div class="gx-scale" style={"width: #{@width}px"} aria-hidden="true">
      <div
        :if={@band}
        class="gx-scale-band"
        style={"left: #{px(@band.x)}; width: #{px(@band.width)}"}
      >
      </div>
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
      id={"#{@ctx.id}-bar-#{dom_key(@bar.uid)}"}
      class={[
        "gx-bar",
        "gx-bar--#{@bar.kind}",
        @bar.selected && "gx-bar--selected",
        @bar.drag == "none" && "gx-bar--locked",
        @bar[:critical] && "gx-bar--critical",
        @bar[:segment] && "gx-bar--segment",
        @bar[:deadline] && @bar.deadline.overdue && "gx-bar--overdue",
        @bar.task.blocked && "gx-bar--blocked",
        @bar.task.restrictions > 0 && "gx-bar--restricted",
        @bar[:summary] && "gx-bar--summary",
        @bar[:commitment] == :committed && "gx-bar--committed",
        @bar[:commitment] == :not_committed && "gx-bar--not-committed",
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
        <span :if={@bar[:summary]} class="gx-summary-cap gx-summary-cap--start"></span>
        <span :if={@bar[:summary]} class="gx-summary-cap gx-summary-cap--end"></span>
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
      <span :if={@bar[:slack_width]} class="gx-slack" style={"width: #{px(@bar.slack_width)}"}></span>
      <span :if={@bar.progress_editable} class="gx-progress-handle" data-gx-progress-handle></span>
      <span
        :if={@bar[:constraint_x]}
        class={["gx-constraint", "gx-constraint--#{@bar.task.constraint_type}"]}
        style={"left: #{px(@bar.constraint_x)}"}
        title={"#{Map.fetch!(@ctx.labels, @bar.task.constraint_type)} · #{@ctx.format.(@bar.task.constraint_date, @ctx.date_pattern)}"}
      ></span>
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
      "--gx-p: #{decimal(bar.progress * 100)}%",
      task.color && "; --gx-bar-bg: #{task.color}",
      task.progress_color && "; --gx-bar-progress: #{task.progress_color}",
      task.text_color && "; --gx-bar-text: #{task.text_color}"
    ]
    |> Enum.filter(& &1)
    |> IO.iodata_to_binary()
  end

  defp bar_label(bar, ctx) do
    task = bar.task

    [
      "#{task.text}, #{Map.fetch!(ctx.labels, task.type)}, " <>
        "#{ctx.format.(task.start_date, ctx.date_pattern)} – " <>
        "#{ctx.format.(TaskForm.display_end(task, ctx.unit), ctx.date_pattern)}",
      task.blocked && ctx.labels.blocked,
      task.restrictions > 0 && GanttEx.I18n.restrictions(task.restrictions, ctx.locale)
    ]
    |> Enum.filter(& &1)
    |> Enum.join(", ")
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
      <%= if @task.planned_start && @task.planned_end do %>
        <dt>{@ctx.labels.baseline}</dt>
        <dd>
          {@ctx.format.(@task.planned_start, @ctx.date_pattern)} – {@ctx.format.(
            TaskForm.inclusive_end(@task.planned_end, @task.planned_start, @ctx.unit),
            @ctx.date_pattern
          )}
        </dd>
      <% end %>
      <%= if @task.deadline do %>
        <dt>{@ctx.labels.deadline}</dt>
        <dd>{@ctx.format.(@task.deadline, @ctx.date_pattern)}</dd>
      <% end %>
    </dl>
    <p :if={@task.blocked or @task.restrictions > 0} class="gx-summary-tags">
      <span :if={@task.blocked} class="gx-tag gx-tag--blocked">
        <.icon name={:lock_closed} /> {@ctx.labels.blocked}
      </span>
      <span :if={@task.restrictions > 0} class="gx-tag gx-tag--restricted">
        <.icon name={:exclamation_triangle} />
        {GanttEx.I18n.restrictions(@task.restrictions, @ctx.locale)}
      </span>
    </p>
    """
  end

  @doc "Renders the resource panel: the load of every resource per column."
  attr :ctx, :map, required: true
  attr :rows, :list, required: true
  attr :width, :integer, required: true
  attr :show_grid, :boolean, default: true

  def resource_panel(assigns) do
    ~H"""
    <section class="gx-resources" aria-label={@ctx.labels.resources}>
      <div class="gx-resources-row gx-resources-row--head">
        <div :if={@show_grid} class="gx-resources-name">{@ctx.labels.resources}</div>
        <div class="gx-resources-cells" style={"width: #{@width}px"}></div>
      </div>
      <div
        :for={row <- @rows}
        id={"#{@ctx.id}-resource-#{dom_key(Store.key(row.resource.id))}"}
        class={["gx-resources-row", row.overloaded && "gx-resources-row--overloaded"]}
      >
        <div :if={@show_grid} class="gx-resources-name">
          <span class="gx-truncate">{row.resource.text}</span>
          <span class="gx-resources-capacity">{row.resource.capacity}</span>
        </div>
        <div class="gx-resources-cells" style={"width: #{@width}px"}>
          <div
            :for={cell <- row.cells}
            class={["gx-load", cell.overload && "gx-load--over"]}
            style={"left: #{px(cell.x)}; width: #{px(cell.width)}; --gx-load: #{min(cell.load / max(cell.capacity, 0.001), 1.5) * 100 / 1.5}%"}
            title={"#{@ctx.labels.load}: #{format_load(cell.load)} / #{format_load(cell.capacity)}"}
          >
            <span>{format_load(cell.load)}</span>
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp format_load(value) do
    if value == Float.round(value),
      do: value |> trunc() |> Integer.to_string(),
      else: decimal(Float.round(value, 1))
  end

  @doc "Renders the tasks rolled up on the rows of their ancestor projects."
  attr :ctx, :map, required: true
  attr :rollups, :list, required: true

  def rollups(assigns) do
    ~H"""
    <div class="gx-rollups" aria-hidden="true">
      <div
        :for={rollup <- @rollups}
        id={"#{@ctx.id}-#{dom_key(rollup.uid)}"}
        class={["gx-rollup", "gx-rollup--#{rollup.kind}"]}
        style={"left: #{px(rollup.x)}; top: #{px(rollup.y)}; width: #{px(rollup.width)}"}
        title={rollup.task.text}
      >
      </div>
    </div>
    """
  end

  @doc "Renders the baselines and deadlines of the bars (they do not move while dragging)."
  attr :ctx, :map, required: true
  attr :bars, :list, required: true

  def row_marks(assigns) do
    ~H"""
    <div class="gx-row-marks" aria-hidden="true">
      <%= for bar <- @bars do %>
        <div
          :if={bar.baseline}
          class={["gx-baseline", bar.baseline[:milestone] && "gx-baseline--milestone"]}
          style={
            "left: #{px(bar.baseline.x)}; top: #{px(bar.baseline.y)}" <>
              if(bar.baseline[:milestone], do: "", else: "; width: #{px(bar.baseline.width)}")
          }
        >
        </div>
        <%= if bar[:deadline] do %>
          <div
            :if={bar.deadline.gap.width > 0}
            class={["gx-deadline-gap", bar.deadline.overdue && "gx-deadline-gap--overdue"]}
            style={"left: #{px(bar.deadline.gap.x)}; top: #{px(bar.deadline.y + bar.deadline.height / 2)}; width: #{px(bar.deadline.gap.width)}"}
          >
          </div>
          <div
            class={["gx-deadline", bar.deadline.overdue && "gx-deadline--overdue"]}
            style={"left: #{px(bar.deadline.x)}; top: #{px(bar.deadline.y)}; height: #{px(bar.deadline.height)}"}
            title={"#{@ctx.labels.deadline}: #{bar.task.text} · #{@ctx.format.(bar.deadline.date, @ctx.date_pattern)}"}
          >
          </div>
        <% end %>
      <% end %>
    </div>
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
        class={[
          "gx-link",
          link.selected && "gx-link--selected",
          link[:critical] && "gx-link--critical"
        ]}
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

  @doc """
  Renders the week of the weekly plan on the chart: `plan` has the `:band`
  (`%{x, width}`) and the `:label` of the week.
  """
  attr :ctx, :map, required: true
  attr :plan, :map, required: true

  def week_band(assigns) do
    ~H"""
    <div
      id={"#{@ctx.id}-week-plan"}
      class="gx-week-band"
      style={"left: #{px(@plan.band.x)}; width: #{px(@plan.band.width)}"}
      title={@plan.label || @ctx.labels.week_plan}
    >
      <span class="gx-week-band-label">{@plan.label || @ctx.labels.week_plan}</span>
    </div>
    """
  end

  @doc """
  Renders the legend of the chart: `entries` are maps with a `:key`, a
  `:label` and a `:kind` (what the swatch draws), and an optional `:color`.
  """
  attr :ctx, :map, required: true
  attr :entries, :list, required: true

  def legend(assigns) do
    ~H"""
    <div id={"#{@ctx.id}-legend"} class="gx-legend" aria-label={@ctx.labels.legend}>
      <span class="gx-legend-title">{@ctx.labels.legend}</span>
      <ul class="gx-legend-list">
        <li
          :for={entry <- @entries}
          id={"#{@ctx.id}-legend-#{entry.key}"}
          class={["gx-legend-item", entry.kind == :group && "gx-legend-group"]}
        >
          <.legend_swatch :if={entry.kind != :group} kind={entry.kind} color={entry[:color]} />
          <span>{entry.label}</span>
        </li>
      </ul>
    </div>
    """
  end

  attr :kind, :any, required: true
  attr :color, :string, default: nil

  defp legend_swatch(%{kind: {:icon, _icon}} = assigns) do
    ~H"""
    <span class="gx-legend-icon" style={@color && "color: #{@color}"} aria-hidden="true">
      <.icon name={elem(@kind, 1)} />
    </span>
    """
  end

  defp legend_swatch(assigns) do
    assigns = assign(assigns, :class, swatch_class(assigns.kind))

    ~H"""
    <span
      class={["gx-swatch", @class]}
      style={@color && "--gx-swatch: #{@color}"}
      aria-hidden="true"
    ></span>
    """
  end

  defp swatch_class({:summary, :bracket}), do: "gx-swatch--bracket"
  defp swatch_class({:summary, _style}), do: "gx-swatch--project"
  defp swatch_class({:shape, shape}) when shape in [:dot, :line], do: "gx-swatch--#{shape}"
  defp swatch_class({:shape, _shape}), do: "gx-swatch--custom"

  defp swatch_class(kind) when is_atom(kind),
    do: "gx-swatch--" <> String.replace(to_string(kind), "_", "-")

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

  attr :offset, :any,
    default: nil,
    doc: "where the bar was clicked, from its start: the left of the popup (`nil` for the start)"

  attr :editable, :boolean, default: true

  def quick_info(assigns) do
    ~H"""
    <div
      id={"#{@ctx.id}-quick-info"}
      class="gx-popup gx-quick-info"
      role="dialog"
      aria-label={@bar.task.text}
      style={"left: #{px(quick_info_left(@bar, @offset))}; top: #{px(@bar.y + @bar.height + 10)}"}
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

  defp quick_info_left(bar, offset) when is_number(offset), do: max(bar.x + offset, 0)
  defp quick_info_left(bar, _offset), do: max(bar.x, 0)

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
            <fieldset :if={:resources in @sections and @ctx[:resources] != %{}} class="gx-fieldset">
              <legend>{@ctx.labels.resources}</legend>
              <input type="hidden" name={@lightbox.form[:resources].name <> "[]"} value="" />
              <div class="gx-checks">
                <label
                  :for={{key, resource} <- Enum.sort_by(@ctx.resources, &elem(&1, 1).text)}
                  class="gx-check"
                >
                  <input
                    type="checkbox"
                    name={@lightbox.form[:resources].name <> "[]"}
                    value={key}
                    checked={key in List.wrap(@lightbox.form[:resources].value)}
                  />
                  <span>{resource.text}</span>
                </label>
              </div>
            </fieldset>
            <fieldset :if={:baseline in @sections} class="gx-fieldset">
              <legend>{@ctx.labels.baseline}</legend>
              <div class="gx-field-row">
                <.field
                  field={@lightbox.form[:planned_start]}
                  type={TaskForm.date_input_type(@ctx.unit)}
                  label={@ctx.labels.planned_start}
                />
                <.field
                  field={@lightbox.form[:planned_end]}
                  type={TaskForm.date_input_type(@ctx.unit)}
                  label={@ctx.labels.planned_end}
                />
              </div>
            </fieldset>
            <.field
              :if={:deadline in @sections}
              field={@lightbox.form[:deadline]}
              type={TaskForm.date_input_type(@ctx.unit)}
              label={@ctx.labels.deadline}
            />
            <fieldset :if={:constraint in @sections} class="gx-fieldset">
              <legend>{@ctx.labels.constraint}</legend>
              <div class="gx-field-row">
                <.field
                  field={@lightbox.form[:constraint_type]}
                  type="select"
                  label={@ctx.labels.constraint_type}
                  options={
                    for type <- GanttEx.Task.constraint_types(),
                        do:
                          {Map.fetch!(@ctx.labels, type),
                           if(type == :asap, do: "", else: Atom.to_string(type))}
                  }
                />
                <.field
                  :if={@lightbox.form[:constraint_type].value not in [nil, "", "asap", "alap"]}
                  field={@lightbox.form[:constraint_date]}
                  type={TaskForm.date_input_type(@ctx.unit)}
                  label={@ctx.labels.constraint_date}
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

      iex> GanttEx.Live.Components.px(1200.0)
      "1200px"
  """
  @spec px(number()) :: String.t()
  def px(value) when is_integer(value), do: "#{value}px"

  def px(value) when is_float(value), do: decimal(value) <> "px"

  @doc false
  # Plain decimal notation (Float.to_string/1 may use exponents: "1.2e3").
  def decimal(value) when is_integer(value), do: Integer.to_string(value)

  def decimal(value) when is_float(value) do
    value
    |> :erlang.float_to_binary([:compact, decimals: 2])
    |> String.replace_suffix(".0", "")
  end

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
