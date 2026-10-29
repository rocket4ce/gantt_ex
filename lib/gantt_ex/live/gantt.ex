defmodule GanttEx.Live.Gantt do
  @moduledoc """
  An interactive Gantt chart LiveComponent.

      <.live_component
        module={GanttEx.Live.Gantt}
        id="project-gantt"
        tasks={@tasks}
        links={@links}
        locale="es"
      />

  The chart keeps its own UI state (selection, expanded branches, zoom,
  dialogs) and applies every user change immediately. Changes are reported
  to the parent LiveView as `{GanttEx, %GanttEx.Event{}}` messages so they
  can be persisted (see `GanttEx.Event` and the "Persistence" guide).
  Whenever the parent renders the component with different `tasks` or
  `links`, the chart reloads them while preserving its UI state.

  ## Features

    * task grid with tree, configurable/sortable/resizable columns and inline editing
    * a column chooser to show, hide and reorder columns, and draggable headers
    * search and filters (status, type, dates and your own fields)
    * row actions: drag handle, rename, block, add a restriction, open, delete...
    * tasks, projects (dates rolled up from children) and milestones, which can
      be blocked or have open restrictions
    * drag & drop to move, resize and change progress; drag to reorder rows
    * finish-to-start, start-to-start, finish-to-finish and start-to-finish
      dependencies with lag, drawn by dragging between bar edges
    * zoomable time scale (hours to years) and customizable zoom levels
    * lightbox editor, quick info popup and tooltips
    * keyboard navigation, fullscreen, print, export (JSON, CSV, iCal, MS Project)
    * drag on the timeline to create tasks, or to pan the chart
    * 8 bundled languages, light/dark themes and WAI-ARIA roles

  ## Attributes

  Data:

    * `:id` (required) - DOM id of the chart.
    * `:tasks` - list of tasks (maps, keyword lists or structs, see `GanttEx.Task`).
    * `:links` - list of links (see `GanttEx.Link`).
    * `:duration_unit` - unit of durations and lags. Defaults to `:day`.
    * `:work_time` - durations count only working time. Defaults to `false`.
    * `:calendar` - the global working calendar: a `GanttEx.Calendar` or its
      options (`work_days`, `hours`, `holidays`, `working_dates`).
    * `:calendars` - more calendars, referenced by the `:calendar_id` of tasks.
    * `:resize_snap` - with working time, where a bar resized onto a
      non-working day ends: `:extend` grows the task to the next working
      day, `:shrink` shrinks it to the previous one, as MS Project does.
      Defaults to `:extend` (see `GanttEx.Store.schedule/5`).

  Behaviour:

    * `:readonly` - disables every edition. Defaults to `false`.
    * `:lightbox` - opens the task editor on double click / Enter / "+". Defaults to `true`.
    * `:lightbox_sections` - lightbox fields to show, any of `:text`, `:type`,
      `:parent`, `:time` and `:progress`. Defaults to all of them.
    * `:inline_edit` - click a cell of the selected row to edit it. Defaults to `true`.
    * `:quick_info` - show a popup when a bar is clicked. Defaults to `true`.
    * `:tooltips` - show tooltips when hovering bars. Defaults to `true`.
    * `:reorder` - drag rows in the grid to reorder or re-parent tasks. Defaults to `true`.
    * `:links_editable` - draw and edit dependencies. Defaults to `true`.
    * `:auto_scheduling` - after every change, move tasks so that dependencies
      and constraints hold (see `GanttEx.Scheduler`). The lightbox gets a
      constraint section. Defaults to `false`.
    * `:auto_scheduling_strict` - also move tasks earlier, to their earliest
      possible date. Defaults to `false`.
    * `:critical_path` - highlight the critical path (see `GanttEx.CriticalPath`).
      The toolbar has a toggle for it. Defaults to `false`.
    * `:near_critical` - while the critical path is shown, also mark the
      near-critical tasks: off the path, with a total slack of this many
      duration units or less, so a short delay would put them on it (see
      `GanttEx.CriticalPath.near_critical?/3`). The legend explains them and
      the status filter offers them. Defaults to `nil` (not marked).
    * `:show_slack` - draw the free slack of each task after its bar.
      Defaults to `false`.
    * `:resources` - the resources tasks are assigned to (see `GanttEx.Resource`).
      Tasks list their assignments in `:resources`; the lightbox gets a
      `:resources` section and grids can show a `:resources` column.
    * `:auto_types` - tasks with children become projects and projects
      without children become tasks. Defaults to `false`.
    * `:group_by` - group the tasks under virtual rows: a task field (`:type`),
      a `:meta` key (`:owner`), `:resources` (a task appears under each of its
      resources) or a function returning the group(s) of a task.
    * `:group_label` - a function returning the label of a group.
    * `:resource_panel` - show the load of every resource below the chart
      (see `GanttEx.ResourceLoad`). Defaults to `false`.
    * `:baselines` - draw the baseline (`:planned_start` / `:planned_end`)
      below each bar. Deadlines (`:deadline`) are always drawn, and tasks that
      end after them are marked as overdue. Defaults to `false`.
    * `:undo` - undo and redo with the toolbar or Ctrl/Cmd+Z and
      Ctrl/Cmd+Shift+Z (Ctrl+Y). Undone changes are reported as events too.
      Defaults to `true`.
    * `:drag_create` - drag on an empty area of the timeline to create a task
      (otherwise dragging pans the chart; hold Shift for the other behaviour).
      Defaults to `false`.
    * `:smart_rendering` - render only the rows around the visible area.
      `:auto` (the default) enables it above 120 visible rows; `true` or `false`
      force it.
    * `:filter` - a 1-arity function returning `true` for the tasks to show
      (their ancestors are shown too). Combined with the filters of the toolbar.
    * `:notify` - the pid that receives the events. Defaults to the parent LiveView.
    * `:batch_events` - report the changes of each user action as one
      `:batch` event (see `GanttEx.Event`) instead of one event per changed
      task or link. A move with auto-scheduling can change thousands of tasks:
      a batch lets the host persist them at once. Defaults to `false`.

  Filters and columns:

    * `:filters` - the search and filters offered by the toolbar: any of
      `:search`, `:status`, `:type`, `:dates` and `:lookahead`, and custom
      filters given as maps (see `GanttEx.Filter`):

          filters={[:search, :status, %{id: :responsible, label: "Responsible",
                     field: :responsible_id, options: [{"Unassigned", nil} | @people]}]}

      Defaults to `[:search, :status, :type, :dates]`; `false` or `[]` remove
      the search and the filter panel. Matching tasks are shown with their
      ancestors, and rows cannot be reordered while filtering.

      `:lookahead` (Last Planner) has its own toolbar menu to choose a number
      of weeks: from the start of the current week (`:week_start`), the chart
      shows only those weeks and the tasks overlapping them, and switches to
      the `:day` zoom level when the scale was coarser. Its value is the
      number of weeks (`%{lookahead: 3}`).
    * `:filter_values` - the selected filters, to restore them:
      `%{search: "slab", status: [:blocked], responsible: ["uuid-1", nil],
      dates: %{from: ~D[2025-01-01], to: ~D[2025-01-31]}}`. A different value
      replaces what the user selected; rendering the same value again keeps
      it. Changes are reported as `:filters_changed` events.
    * `:column_chooser` - show the column chooser in the toolbar. Defaults to `true`.
    * `:column_layout` - the order, hidden columns, widths and grid width set
      by the user, to restore them: `%{order: ["wbs", "text"], hidden: ["cost"],
      widths: %{"text" => 300}, grid_width: nil}` (see `GanttEx.Live.Columns`).
      Same rule as `:filter_values`; changes are reported as
      `:columns_changed` events.

  Time scale:

    * `:zoom` - initial zoom level name. Defaults to `:day`.
    * `:zoom_levels` - custom levels (see `GanttEx.Zoom`).
    * `:start_date`, `:end_date` - fixed visible range. By default the range
      fits the tasks.
    * `:week_start` - first day of the week (`1` = Monday, `7` = Sunday). Defaults to `1`.
    * `:weekend` - ISO days highlighted as non-working. Defaults to `[6, 7]`.
    * `:today` - the current date, used by the "Today" button. Defaults to now.
    * `:markers` - vertical lines marking dates (see `GanttEx.Marker`).
    * `:today_marker` - add a marker for today. Defaults to `false`.
    * `:plans` - the plans (Last Planner) to show, each one of one week or
      more: `[%{id: 1, week: date, weeks: 2, committed: task_ids, label:
      "Weeks 45-46"}]`. `:week` is any day of its first week and `:weeks`
      defaults to `1`. The period of each plan is highlighted, the bars of
      the tasks committed in any of them are green and the other tasks are
      muted. `[]` (the default), `nil` or `false` show the chart as usual.

  Appearance:

    * `:locale` - one of `GanttEx.I18n.locales/0`. Defaults to `"en"`.
    * `:theme` - `"auto"` (follows `prefers-color-scheme` or a `data-theme`
      attribute on an ancestor), `"light"` or `"dark"`. Defaults to `"auto"`.
    * `:height` - CSS height of the scrollable area. Defaults to `"640px"`.
    * `:row_height`, `:bar_height`, `:scale_height` - sizes in pixels.
    * `:grid_width` - width of the grid in pixels. Defaults to the sum of the
      column widths. `:show_grid` hides it.
    * `:toolbar` - show the built-in toolbar. Defaults to `true`.
    * `:export_formats` - formats offered by the toolbar: `:json`, `:csv`, `:ical`,
      `:ms_project`, `:svg` and `:png` (see `GanttEx.Export`).
    * `:export_filename` - base name of exported files. Defaults to `"gantt"`.
    * `:summary_bars` - how summary tasks (projects with children) are drawn:
      `:bar` (the default, like tasks) or `:bracket` (a thin bar with
      downward ends, as in MS Project) with the name after it.
    * `:legend` - show a legend of the colors and icons of the chart below
      it. Defaults to `false`.
    * `:legend_items` - more legend entries, after the built-in ones:
      `%{label: "Concrete Ltd.", color: "#0ea5e9", shape: :bar}` where
      `:shape` is `:bar` (the default), `:dot` or `:line`, or
      `%{label: "Has photos", icon: :camera}` with an icon of
      `GanttEx.Live.Icons`. Entries with a `:group` (`"Partner"`) are shown
      after the title of their group.
    * `:task_class` - a function returning extra CSS classes for a task bar.
    * `:class` - extra classes for the root element.

  ## Slots

    * `:column` - grid columns. Attributes: `field` (required: `:text`,
      `:start_date`, `:end_date`, `:duration`, `:progress`, `:type`, `:wbs`,
      `:add`, `:actions` or any key of the task `:meta`), `label`, `width`,
      `align`, `tree` (shows the tree in this column), `editor` (`:text`,
      `:date`, `:number`, `:progress`, `:type` or `nil`), `sortable`, `hidden`
      (available in the column chooser but not shown until the user adds it)
      and `actions` (the buttons of an `:actions` column, see
      `GanttEx.Live.Columns`). The inner block receives the task:

          <:column field={:owner} label="Owner" width={120} :let={task}>
            {task.meta[:owner]}
          </:column>
          <:column field={:cost} label="Cost" hidden :let={task}>{task.meta[:cost]}</:column>
          <:column field={:actions} actions={[:drag, :rename, :block, :restriction, :detail]} />

    * `:task_text` - content of the bars, receives the task.
    * `:tooltip` - content of the tooltips, receives the task.
    * `:lightbox_fields` - extra lightbox fields, receives the form. Values
      are stored in the task `:meta`.
    * `:toolbar_actions` - extra content for the toolbar.

  ## Events

  Besides the changes of the data, the parent receives `:task_selected`,
  `:branch_requested`, `:task_action` (a row action it handles, such as
  `:restriction` or `:detail`), `:filters_changed` and `:columns_changed`
  events. See `GanttEx.Event`.

  ## Controlling the chart from the parent

  Use `zoom/2`, `expand_all/1`, `collapse_all/1`, `select/2` and `reload/1`,
  which wrap `Phoenix.LiveView.send_update/2`.

  ## JavaScript

  Drag & drop needs the bundled hook. Add it to your `LiveSocket`:

      import {hooks as ganttHooks} from "phoenix-colocated/gantt_ex"

      const liveSocket = new LiveSocket("/live", Socket, {
        hooks: {...colocatedHooks, ...ganttHooks},
      })

  and the styles to your `app.css`:

      @import "phoenix-colocated/gantt_ex/colocated.css";
  """

  use Phoenix.LiveComponent

  import GanttEx.Live.Components

  alias GanttEx.{
    Dates,
    Event,
    Export,
    Filter,
    History,
    I18n,
    Layout,
    Link,
    LinkForm,
    Store,
    Task,
    TaskForm
  }

  alias GanttEx.{CriticalPath, Marker, Resource, ResourceLoad, Scheduler, Timeline, Zoom}
  alias GanttEx.Live.{Columns, Interaction}

  @hook "GanttEx.Live.Hook.Gantt"

  @defaults [
    locale: "en",
    zoom: :day,
    duration_unit: :day,
    readonly: false,
    height: "640px",
    row_height: 36,
    bar_height: nil,
    scale_height: 32,
    grid_width: nil,
    show_grid: true,
    start_date: nil,
    end_date: nil,
    week_start: 1,
    weekend: [6, 7],
    today: nil,
    toolbar: true,
    tooltips: true,
    quick_info: true,
    lightbox: true,
    lightbox_sections: [:text, :type, :parent, :time, :progress],
    inline_edit: true,
    drag_create: false,
    reorder: true,
    links_editable: true,
    export_formats: [:json, :csv, :ical, :ms_project, :svg, :png],
    smart_rendering: :auto,
    work_time: false,
    calendar: nil,
    calendars: [],
    resize_snap: :extend,
    markers: [],
    today_marker: false,
    plans: [],
    summary_bars: :bar,
    legend: false,
    legend_items: [],
    undo: true,
    auto_scheduling: false,
    auto_scheduling_strict: false,
    critical_path: false,
    near_critical: nil,
    show_slack: false,
    baselines: false,
    resources: [],
    resource_panel: false,
    group_by: nil,
    group_label: nil,
    auto_types: false,
    export_filename: "gantt",
    theme: "auto",
    class: nil,
    task_class: nil,
    filter: nil,
    filters: [:search, :status, :type, :dates],
    column_chooser: true,
    notify: nil,
    batch_events: false,
    column: [],
    task_text: [],
    tooltip: [],
    lightbox_fields: [],
    toolbar_actions: []
  ]

  # -- public API --------------------------------------------------------------

  @doc "Changes the zoom level of the chart with the given `id`."
  @spec zoom(String.t(), atom()) :: :ok
  def zoom(id, level), do: send_update(__MODULE__, id: id, action: {:zoom, level})

  @doc "Expands every branch of the chart."
  @spec expand_all(String.t()) :: :ok
  def expand_all(id), do: send_update(__MODULE__, id: id, action: :expand_all)

  @doc "Collapses every branch of the chart."
  @spec collapse_all(String.t()) :: :ok
  def collapse_all(id), do: send_update(__MODULE__, id: id, action: :collapse_all)

  @doc "Selects the task with `task_id` (or clears the selection with `nil`)."
  @spec select(String.t(), Task.id() | nil) :: :ok
  def select(id, task_id), do: send_update(__MODULE__, id: id, action: {:select, task_id})

  @doc """
  Forces the chart to reload its data from the last `tasks` and `links` it
  received, discarding local changes. Useful when the parent rejected a change
  and its data did not change.
  """
  @spec reload(String.t()) :: :ok
  def reload(id), do: send_update(__MODULE__, id: id, action: :reload)

  # -- lifecycle ---------------------------------------------------------------

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       store: nil,
       data_source: nil,
       collapsed: MapSet.new(),
       selected: nil,
       selection: MapSet.new(),
       selected_link: nil,
       quick_info_key: nil,
       quick_info_offset: nil,
       lightbox_state: nil,
       link_editor: nil,
       confirm: nil,
       editing: nil,
       sort: nil,
       notice: nil,
       zoom_name: nil,
       zoom_attr: nil,
       # `{level before, :day level}` while a lookahead holds the zoom it changed
       lookahead_zoom: nil,
       # columns: the user's layout and the last `:column_layout` received
       column_state: Columns.normalize_layout(nil),
       column_attr: :unset,
       labels_locale: nil,
       timeline: nil,
       viewport: %{top: 0, height: 900},
       # the width of the viewport, reported by the hook (see build_timeline/5)
       viewport_width: nil,
       history: History.new(),
       show_critical: nil,
       analysis: nil,
       loading: MapSet.new(),
       popover: nil,
       # filters: the normalized values, the last `:filter_values` received and
       # what is typed in the searchable filters
       filter_state: %{},
       filter_attr: :unset,
       filter_queries: %{},
       filter_cache: nil,
       search_cache: nil
     )}
  end

  @impl true
  def update(%{action: action}, socket) do
    {:ok, socket |> handle_action(action) |> prepare()}
  end

  def update(assigns, socket) do
    previous_filters = socket.assigns.filter_state

    socket =
      socket
      |> assign(Map.drop(assigns, [:tasks, :links, :zoom_levels, :filter_values, :column_layout]))
      |> assign_defaults(assigns)
      |> load_data(assigns)
      |> assign_i18n()
      |> assign_filter_values(assigns)
      |> assign_column_layout(assigns)
      |> assign_zoom()

    # a lookahead restored from the filter values is read day by day too
    socket =
      lookahead_zoom(socket, previous_filters, socket.assigns.filter_state)

    {:ok, prepare(socket)}
  end

  defp assign_defaults(socket, assigns) do
    socket =
      Enum.reduce(@defaults, socket, fn {key, value}, socket ->
        assign_new(socket, key, fn -> value end)
      end)

    case assigns do
      %{zoom_levels: levels} when is_list(levels) ->
        assign(socket, :zoom_levels, Zoom.normalize!(levels))

      _ ->
        assign_new(socket, :zoom_levels, &Zoom.default_levels/0)
    end
  end

  defp load_data(socket, assigns) do
    {old_tasks, old_links, _opts} = socket.assigns.data_source || {[], [], nil}
    tasks = Map.get(assigns, :tasks, old_tasks)
    links = Map.get(assigns, :links, old_links)

    store_opts = [
      duration_unit: socket.assigns.duration_unit,
      work_time: socket.assigns.work_time,
      calendar: socket.assigns.calendar,
      calendars: socket.assigns.calendars,
      resize_snap: socket.assigns.resize_snap,
      auto_types: socket.assigns.auto_types
    ]

    source = {tasks, links, store_opts}

    cond do
      source == socket.assigns.data_source ->
        socket

      store = patch_store(socket.assigns, tasks, links, store_opts) ->
        assign(socket, store: store, data_source: source)

      true ->
        store = Store.new!(tasks, links, store_opts)

        socket
        |> sync_ui_state(socket.assigns.store, store)
        |> assign(store: store, data_source: source)
    end
  end

  # New data that only changes some tasks (same tasks in the same order, same
  # links and options) updates those tasks in the store: a chart of thousands
  # of tasks gets the changes of other users without being built again.
  defp patch_store(
         %{store: %Store{} = store, data_source: {old, links, opts}},
         tasks,
         links,
         opts
       ) do
    with {:ok, changed} <- changed_tasks(old, tasks, []),
         {:ok, store} <- Store.put_tasks(store, changed) do
      store
    else
      _ -> nil
    end
  end

  defp patch_store(_assigns, _tasks, _links, _opts), do: nil

  defp changed_tasks([same | old], [same | new], acc), do: changed_tasks(old, new, acc)

  defp changed_tasks([previous | old], [task | new], acc) do
    if task_id(previous) == task_id(task),
      do: changed_tasks(old, new, [task | acc]),
      else: :error
  end

  defp changed_tasks([], [], acc), do: {:ok, Enum.reverse(acc)}
  defp changed_tasks(_old, _new, _acc), do: :error

  defp task_id(task) when is_list(task), do: Keyword.get(task, :id)
  defp task_id(task) when is_map(task), do: Map.get(task, :id, Map.get(task, "id"))

  # Keeps the UI state that still makes sense after new data arrives.
  defp sync_ui_state(socket, old_store, store) do
    known? = fn key -> key && Store.task_by_key(store, key) end
    old_ids = if old_store, do: MapSet.new(Map.keys(old_store.tasks)), else: MapSet.new()

    collapsed =
      store
      |> Store.tasks()
      |> Enum.filter(fn task ->
        if MapSet.member?(old_ids, task.id),
          do: MapSet.member?(socket.assigns.collapsed, task.id),
          else: not task.open
      end)
      |> MapSet.new(& &1.id)

    lightbox =
      case socket.assigns.lightbox_state do
        %{mode: :edit, key: key} = state -> if known?.(key), do: state
        state -> state
      end

    assign(socket,
      collapsed: collapsed,
      selected: if(known?.(socket.assigns.selected), do: socket.assigns.selected),
      quick_info_key:
        if(known?.(socket.assigns.quick_info_key), do: socket.assigns.quick_info_key),
      selected_link:
        if(socket.assigns.selected_link && Store.link_by_key(store, socket.assigns.selected_link),
          do: socket.assigns.selected_link
        ),
      link_editor:
        if(socket.assigns.link_editor && Store.link_by_key(store, socket.assigns.link_editor.key),
          do: socket.assigns.link_editor
        ),
      lightbox_state: lightbox,
      editing: nil,
      # branches stop loading once their children arrived (or they are gone)
      loading:
        MapSet.filter(socket.assigns.loading, fn key ->
          case Store.task_by_key(store, key) do
            nil -> false
            task -> Store.child_ids(store, task.id) == []
          end
        end)
    )
  end

  defp assign_i18n(socket) do
    locale = I18n.normalize_locale(socket.assigns.locale)

    if locale == socket.assigns.labels_locale do
      socket
    else
      assign(socket,
        labels_locale: locale,
        labels: I18n.labels(locale),
        format: I18n.formatter(locale)
      )
    end
  end

  # A new `:filter_values` replaces what the user selected; the same one again
  # (the parent re-rendering) keeps it.
  defp assign_filter_values(socket, assigns) do
    case assigns do
      %{filter_values: values} when values != socket.assigns.filter_attr ->
        assign(socket,
          filter_attr: values,
          filter_state: Filter.normalize(values, filter_definitions(socket.assigns, true)),
          filter_queries: %{}
        )

      _ ->
        socket
    end
  end

  # Same rule as `:filter_values`: only a different layout replaces the user's.
  defp assign_column_layout(socket, assigns) do
    case assigns do
      %{column_layout: layout} when layout != socket.assigns.column_attr ->
        assign(socket, column_attr: layout, column_state: Columns.normalize_layout(layout))

      _ ->
        socket
    end
  end

  # Values are kept against every status, so a critical filter survives
  # hiding the critical path (it is ignored meanwhile).
  defp filter_definitions(a, critical),
    do:
      Filter.definitions(a.filters, a.labels,
        critical: critical,
        near_critical: critical and near_critical?(a)
      )

  defp near_critical?(a), do: is_integer(a.near_critical) and a.near_critical > 0

  defp assign_zoom(%{assigns: assigns} = socket) do
    if assigns.zoom != assigns.zoom_attr or is_nil(assigns.zoom_name) do
      assign(socket,
        zoom_name: Zoom.find(assigns.zoom_levels, assigns.zoom).name,
        zoom_attr: assigns.zoom
      )
    else
      socket
    end
  end

  defp handle_action(socket, {:zoom, level}),
    do: assign(socket, :zoom_name, Zoom.find(socket.assigns.zoom_levels, level).name)

  defp handle_action(socket, :expand_all), do: assign(socket, :collapsed, MapSet.new())
  defp handle_action(socket, :collapse_all), do: assign(socket, :collapsed, all_parents(socket))

  defp handle_action(socket, {:select, nil}),
    do: assign(socket, selected: nil, quick_info_key: nil)

  defp handle_action(socket, {:select, id}) do
    case Store.get_task(socket.assigns.store, id) do
      nil -> socket
      task -> assign(socket, selected: Store.key(task.id))
    end
  end

  defp handle_action(socket, :reload) do
    {tasks, links, _opts} = socket.assigns.data_source || {[], [], nil}
    socket |> assign(:data_source, nil) |> load_data(%{tasks: tasks, links: links})
  end

  # -- derived state -----------------------------------------------------------

  # Computes everything the template needs. Called after every state change.
  defp prepare(%{assigns: a} = socket) do
    level = Zoom.find(a.zoom_levels, a.zoom_name)
    today = today(a)
    bar_height = a.bar_height || a.row_height - 12

    ctx_resources =
      Map.new(a.resources, fn r ->
        r = Resource.new!(r)
        {Store.key(r.id), r}
      end)

    available = available_columns(a)
    columns = Enum.filter(available, & &1.visible)
    a = Map.merge(a, %{ctx_resources: ctx_resources, columns: columns})
    selection = normalize_selection(a)
    show_critical = if is_nil(a.show_critical), do: a.critical_path, else: a.show_critical
    {analysis, analysis_cache} = analysis(a, show_critical)
    a = Map.merge(a, %{selection: selection, analysis: analysis, show_critical: show_critical})
    filtering = run_filters(a, today)

    rows = rows(a, filtering)
    grid_width = grid_width(a, columns)
    timeline = build_timeline(a, level, today, filtering.lookahead, grid_width)
    layout = layout(a, rows, timeline, bar_height)
    chart_height = max(layout.height, 0)
    plans = plans(a, timeline)

    socket =
      if {timeline, a.labels_locale, a.store.calendar, a.weekend} == a[:scale_key] do
        socket
      else
        assign(socket,
          timeline: timeline,
          scale_key: {timeline, a.labels_locale, a.store.calendar, a.weekend},
          scale_rows: scale_rows(timeline, a, today),
          highlights: highlights(timeline, a)
        )
      end

    socket
    |> assign(
      selection: selection,
      show_critical: show_critical,
      analysis: analysis,
      analysis_cache: analysis_cache,
      filtering: filtering,
      filter_cache: filtering.cache,
      search_cache: filtering.search_cache,
      reorderable: reorder_state(a, filtering) == :ok and not a.readonly,
      level: level,
      rows: rows,
      rows_cache: {rows_key(a, filtering), rows},
      layout_cache: {layout_key(a, rows, timeline, bar_height), layout},
      bars: layout.bars ++ layout.segments,
      rollups: layout.rollups,
      link_paths: layout.links,
      columns: columns,
      column_choices: a.column_chooser && available,
      grid_width_value: grid_width,
      chart_width: layout.width,
      chart_height: chart_height,
      canvas_width: layout.width + if(a.show_grid, do: grid_width, else: 0),
      snap_px: snap_px(timeline, a.duration_unit),
      resource_rows:
        a.resource_panel && a.resources != [] &&
          ResourceLoad.compute(a.store, a.resources, timeline),
      marker_items: marker_items(a, timeline, today),
      plan_view: plans,
      legend_entries: a.legend && legend_entries(a, show_critical, plans),
      root_style: root_style(a, columns, grid_width, bar_height, level, timeline),
      ctx: %{
        id: a.id,
        myself: a.myself,
        today: today,
        labels: a.labels,
        format: a.format,
        locale: a.labels_locale,
        unit: a.duration_unit,
        date_pattern:
          if(TaskForm.date_input_type(a.duration_unit) == "date", do: :date, else: :datetime),
        readonly: a.readonly,
        inline_edit: a.inline_edit,
        tooltips: a.tooltips,
        lightbox: a.lightbox,
        resources: a.ctx_resources,
        reorder: reorder_state(a, filtering)
      }
    )
    |> apply_window()
  end

  # Smart rendering: only the rows around the viewport (and the bars and links
  # crossing them) are rendered; spacers keep the scroll height.
  @window_buffer 25
  @auto_threshold 120

  # Rows and layout only change with the data, the tree state or the
  # timeline: selecting a task, opening a popover or a lightbox reuses them.
  # Their flags (selection, critical path, ...) are set on the window only.
  defp rows(a, filtering) do
    key = rows_key(a, filtering)

    case a[:rows_cache] do
      {^key, rows} ->
        rows

      _ ->
        Store.rows(a.store,
          collapsed: a.collapsed,
          visible: filtering.visible,
          sort: a.sort,
          group_by: group_spec(a)
        )
    end
  end

  defp rows_key(a, filtering),
    do: {a.store, a.collapsed, filtering.visible, a.sort, group_spec(a)}

  defp layout(a, rows, timeline, bar_height) do
    key = layout_key(a, rows, timeline, bar_height)

    case a[:layout_cache] do
      {^key, layout} ->
        layout

      cached ->
        Layout.build(a.store, rows, timeline,
          row_height: a.row_height,
          bar_height: bar_height,
          baselines: a.baselines,
          # links whose bars did not move keep their path
          link_cache: if(cached, do: elem(cached, 1).link_cache, else: %{})
        )
    end
  end

  defp layout_key(a, rows, timeline, bar_height),
    do: {a.store, rows, timeline, a.row_height, bar_height, a.baselines}

  defp apply_window(%{assigns: a} = socket) do
    count = length(a.rows)

    {first, last} =
      if smart_rendering?(a.smart_rendering, count) do
        %{top: top, height: height} = a.viewport
        # rows may be fewer than the scrolled position (filtered, or new data)
        first = min(max(div(trunc(top), a.row_height) - @window_buffer, 0), count - 1)
        last = min(div(trunc(top + height), a.row_height) + @window_buffer, count - 1)
        {first, max(last, first)}
      else
        {0, count - 1}
      end

    visible? = fn row -> row >= first and row <= last end

    bars = for bar <- a.bars, visible?.(bar.row), do: decorate_bar(bar, a)

    rows =
      for row <- Enum.slice(a.rows, first..last//1) do
        Map.merge(row, %{
          selected: MapSet.member?(a.selection, row.key),
          slack: a.analysis && a.analysis.tasks[row.task.id],
          loading: MapSet.member?(a.loading, row.key)
        })
      end

    links =
      for link <- a.link_paths,
          min(link.source_row, link.target_row) <= last,
          max(link.source_row, link.target_row) >= first do
        Map.merge(link, %{
          selected: link.key == a.selected_link,
          critical:
            a.show_critical and a.analysis != nil and
              MapSet.member?(a.analysis.links, link.link.id)
        })
      end

    assign(socket,
      window: if(smart_rendering?(a.smart_rendering, count), do: "#{first}:#{last}:#{count}"),
      window_rows: rows,
      window_bars: bars,
      window_rollups: Enum.filter(a.rollups, &visible?.(&1.row)),
      window_links: links,
      spacer_top: first * a.row_height,
      spacer_bottom: max(count - 1 - last, 0) * a.row_height,
      quick_info_bar: a.quick_info_key && Enum.find(bars, &(&1.key == a.quick_info_key))
    )
  end

  defp smart_rendering?(:auto, count), do: count > @auto_threshold
  defp smart_rendering?(enabled, count), do: enabled == true and count > 0

  defp group_spec(%{group_by: group_by}) when group_by in [nil, false], do: nil

  defp group_spec(a) do
    resources = a.ctx_resources

    group =
      case a.group_by do
        fun when is_function(fun, 1) ->
          fun

        :resources ->
          fn task ->
            task.resources |> Enum.map(& &1.id) |> then(&if(&1 == [], do: nil, else: &1))
          end

        field ->
          fn task ->
            if Map.has_key?(task, field), do: Map.get(task, field), else: task.meta[field]
          end
      end

    label =
      a.group_label ||
        fn
          nil -> a.labels.unassigned
          value when a.group_by == :resources -> resource_text(resources, value)
          value when is_atom(value) -> Map.get(a.labels, value) || to_string(value)
          value -> to_string(value)
        end

    {group, label}
  end

  defp resource_text(resources, id) do
    case Map.get(resources, Store.key(id)) do
      nil -> to_string(id)
      resource -> resource.text
    end
  end

  # Filters run again only when the data or the values change. Searching uses
  # the normalized text of the tasks, kept until they are renamed.
  defp run_filters(a, today) do
    definitions = filter_definitions(a, a.show_critical)
    values = Filter.normalize(a.filter_state, definitions)
    statuses = Map.get(values, :status, [])

    search_cache =
      case a.search_cache do
        {store, _index, _wbs} = cache when store == a.store ->
          cache

        cache when is_map_key(values, :search) ->
          previous = if cache, do: elem(cache, 1), else: %{}
          {a.store, Filter.search_index(a.store, previous), Store.wbs_codes(a.store)}

        cache ->
          cache
      end

    lookahead =
      case values do
        %{lookahead: weeks} -> Filter.lookahead_range(weeks, today, a.week_start)
        _ -> nil
      end

    key =
      {a.store, values, a.filter,
       (:critical in statuses or :near_critical in statuses) and {a.analysis, a.near_critical},
       :overdue in statuses and today, lookahead}

    {visible, matched} =
      case a.filter_cache do
        {^key, result} ->
          result

        _ ->
          {_store, index, wbs} = search_cache || {nil, %{}, %{}}

          Filter.visible(a.store, definitions, values, %{
            today: today,
            week_start: a.week_start,
            unit: a.duration_unit,
            analysis: a.analysis,
            near_critical: a.near_critical,
            index: index,
            wbs: wbs,
            filter: a.filter
          })
      end

    %{
      definitions: definitions,
      values: values,
      visible: visible,
      matched: matched,
      total: Store.task_count(a.store),
      active: values != %{},
      lookahead: lookahead,
      cache: {key, {visible, matched}},
      search_cache: search_cache
    }
  end

  # Rows can only be dragged when they are shown in tree order.
  defp reorder_state(a, filtering) do
    cond do
      not a.reorder or a.group_by not in [nil, false] -> :disabled
      a.sort -> :sorted
      filtering.visible -> :filtered
      true -> :ok
    end
  end

  # CPM runs when something shows it, and only again when what it depends on
  # changes: not for a new progress or name (see CriticalPath.inputs/1).
  # Returns the analysis and the cache `{store, inputs, analysis}`.
  defp analysis(a, show_critical) do
    needed =
      show_critical or a.show_slack or
        Enum.any?(a.columns, &(&1.field in [:total_slack, :free_slack]))

    cached = a[:analysis_cache]

    cond do
      not needed ->
        {nil, cached}

      cached && elem(cached, 0) == a.store ->
        {elem(cached, 2), cached}

      true ->
        inputs = CriticalPath.inputs(a.store)

        analysis =
          case cached do
            {_store, ^inputs, analysis} -> analysis
            _ -> CriticalPath.analyze(a.store)
          end

        {analysis, {a.store, inputs, analysis}}
    end
  end

  # The selection always contains the primary selected task, when any.
  defp normalize_selection(%{selected: nil}), do: MapSet.new()

  defp normalize_selection(a) do
    if MapSet.member?(a.selection, a.selected),
      do: MapSet.filter(a.selection, &Store.task_by_key(a.store, &1)),
      else: MapSet.new([a.selected])
  end

  defp today(%{today: nil}), do: NaiveDateTime.local_now() |> NaiveDateTime.truncate(:second)
  defp today(%{today: today}), do: Dates.cast!(today)

  defp build_timeline(a, level, today, lookahead, grid_width) do
    {start, finish} =
      case {Dates.cast!(a.start_date), Dates.cast!(a.end_date)} do
        {%NaiveDateTime{} = start, %NaiveDateTime{} = finish} ->
          {start, finish}

        # the lookahead shows its weeks only
        _ when lookahead != nil ->
          {NaiveDateTime.new!(lookahead.from, ~T[00:00:00]),
           NaiveDateTime.new!(Date.add(lookahead.to, 1), ~T[00:00:00])}

        _ ->
          Timeline.fit(Store.date_range(a.store), level.scales,
            week_start: a.week_start,
            today: today
          )
      end

    timeline =
      Timeline.new(
        scales: level.scales,
        start_date: start,
        end_date: finish,
        column_width: level.column_width,
        week_start: a.week_start
      )

    fit_lookahead(timeline, a, lookahead, grid_width)
  end

  # The weeks of a lookahead fill the width of the viewport: their columns
  # grow when the window is shorter than the visible timeline
  defp fit_lookahead(timeline, %{viewport_width: viewport} = a, %{}, grid_width)
       when is_number(viewport) do
    available = viewport - if(a.show_grid, do: grid_width, else: 0)
    columns = max(Timeline.column_count(timeline), 1)
    width = div(max(available, 0), columns)

    if width > timeline.column_width,
      do: %{timeline | column_width: width},
      else: timeline
  end

  defp fit_lookahead(timeline, _a, _lookahead, _grid_width), do: timeline

  defp decorate_bar(bar, a) do
    task = bar.task
    editable = not a.readonly and not task.readonly
    summary = task.type == :project and Store.has_children?(a.store, task.id)

    Map.merge(bar, %{
      selected: MapSet.member?(a.selection, bar.key),
      summary: summary,
      commitment: commitment(task, bar, a.plan_view),
      drag: if(editable and not summary, do: "move", else: "none"),
      resizable: editable and not summary and task.type != :milestone,
      progress_editable: editable and task.type != :milestone,
      linkable: not a.readonly and a.links_editable and not bar.group,
      class: a.task_class && a.task_class.(task),
      constraint_x: constraint_x(task, bar, a),
      deadline: deadline(task, bar, a),
      critical:
        a.show_critical and a.analysis != nil and
          match?(%{critical: true}, a.analysis.tasks[task.id]),
      near_critical:
        a.show_critical and CriticalPath.near_critical?(a.analysis, task, a.near_critical),
      slack_width: slack_width(task, a)
    })
  end

  # Tasks committed in the plans, and the other tasks (muted). Summary tasks and
  # milestones out of the plan keep their colors.
  defp commitment(_task, _bar, nil), do: nil
  defp commitment(_task, %{group: group}, _plan) when group not in [nil, false], do: nil
  defp commitment(%Task{type: :project}, _bar, _plan), do: nil

  defp commitment(task, _bar, plan) do
    cond do
      MapSet.member?(plan.committed, Store.key(task.id)) -> :committed
      task.type == :milestone -> nil
      true -> :not_committed
    end
  end

  # The periods of the plans on the timeline (their band is nil when out of
  # the visible range) and the tasks committed in any of them. nil without
  # plans.
  defp plans(%{plans: plans}, _timeline) when plans in [nil, false, []], do: nil

  defp plans(%{plans: plans} = a, timeline) do
    periods = plans |> List.wrap() |> Enum.map(&plan_period(Map.new(&1), a, timeline))

    %{
      periods: periods,
      committed: Enum.reduce(periods, MapSet.new(), &MapSet.union(&2, &1.committed))
    }
  end

  defp plan_period(plan, a, timeline) do
    get = fn key -> Map.get(plan, key, Map.get(plan, Atom.to_string(key))) end
    from = get.(:week) |> Dates.cast!() |> Dates.floor(:week, week_start: a.week_start)

    weeks =
      case get.(:weeks) do
        weeks when is_integer(weeks) and weeks > 0 -> weeks
        _ -> 1
      end

    to = Dates.add(from, 7 * weeks, :day)
    left = Timeline.x(timeline, Dates.max(from, timeline.start_date))
    right = Timeline.x(timeline, Dates.min(to, timeline.end_date))

    %{
      key: Store.key(get.(:id) || Date.to_iso8601(NaiveDateTime.to_date(from))),
      from: from,
      to: to,
      weeks: weeks,
      label: get.(:label),
      committed: MapSet.new(get.(:committed) || [], &Store.key/1),
      band: if(right > left, do: %{x: left, width: right - left})
    }
  end

  # What the legend explains: the bars and marks the chart can show, then the
  # entries of the host.
  defp legend_entries(a, show_critical, plans) do
    labels = a.labels

    builtin = [
      if(plans, do: %{key: "committed", label: labels.committed, kind: :committed}),
      if(plans,
        do: %{key: "not-committed", label: labels.not_committed, kind: :not_committed}
      ),
      if(plans, do: %{key: "plan", label: labels.plan_period, kind: :plan}),
      %{key: "task", label: labels.task, kind: :task},
      %{key: "progress", label: labels.progress, kind: :progress},
      %{key: "project", label: labels.project, kind: {:summary, a.summary_bars}},
      %{key: "milestone", label: labels.milestone, kind: :milestone},
      if(show_critical, do: %{key: "critical", label: labels.critical_path, kind: :critical}),
      if(show_critical and near_critical?(a),
        do: %{
          key: "near-critical",
          label:
            "#{labels.near_critical} (≤ #{GanttEx.I18n.duration(a.near_critical, a.duration_unit, labels.locale)})",
          kind: :near_critical
        }
      ),
      if(a.baselines, do: %{key: "baseline", label: labels.baseline, kind: :baseline}),
      %{key: "deadline", label: labels.deadline, kind: :deadline},
      %{key: "overdue", label: labels.overdue, kind: :overdue},
      %{key: "blocked", label: labels.blocked, kind: {:icon, :lock_closed}},
      %{key: "restricted", label: labels.restricted, kind: {:icon, :exclamation_triangle}},
      if(a.today_marker, do: %{key: "today", label: labels.today, kind: :today})
    ]

    # the colors of the progress column
    statuses =
      if Enum.any?(a.columns, &(&1.field == :progress and is_nil(&1.inner_block))) do
        [%{key: "group-status", label: labels.status, kind: :group}] ++
          for status <- [:completed, :in_progress, :not_started, :overdue] do
            %{
              key: "status-#{String.replace(to_string(status), "_", "-")}",
              label: Map.fetch!(labels, status),
              kind: {:status, status}
            }
          end
      else
        []
      end

    custom =
      a.legend_items
      |> Enum.map(&Map.new/1)
      |> Enum.with_index()
      |> Enum.flat_map_reduce(nil, fn {item, index}, group ->
        color =
          case Task.cast_color(Map.get(item, :color)) do
            {:ok, color} -> color
            :error -> nil
          end

        kind =
          case Map.get(item, :icon) do
            nil -> {:shape, Map.get(item, :shape, :bar)}
            icon -> {:icon, icon}
          end

        entry = %{
          key: "item-#{index}",
          label: to_string(Map.get(item, :label, "")),
          kind: kind,
          color: color
        }

        # a title before the first entry of each group
        case Map.get(item, :group) do
          same when same in [nil, group] ->
            {[entry], group}

          title ->
            {[%{key: "group-#{index}", label: to_string(title), kind: :group}, entry], title}
        end
      end)
      |> elem(0)

    Enum.reject(builtin, &is_nil/1) ++ statuses ++ custom
  end

  # Deadlines are inclusive days: a task due on the 10th may end on the 10th.
  defp deadline(%Task{deadline: %NaiveDateTime{} = date} = task, bar, a) do
    due = TaskForm.parse_end(date, a.duration_unit)
    x = Timeline.x(a.timeline, due)
    # the end of the bar, joined to the flag so the deadline reads as part of the task
    finish = bar.x + bar.width

    %{
      x: x,
      y: bar.y,
      height: bar.height,
      date: date,
      overdue: NaiveDateTime.compare(task.end_date, due) == :gt,
      gap: %{x: min(x, finish), width: abs(x - finish)}
    }
  end

  defp deadline(_task, _bar, _a), do: nil

  defp slack_width(task, %{show_slack: true, analysis: %{tasks: tasks}} = a) do
    case tasks[task.id] do
      %{free_slack: slack} when slack > 0 ->
        finish = Store.add_duration(a.store, task, task.end_date, slack)
        Timeline.x(a.timeline, finish) - Timeline.x(a.timeline, task.end_date)

      _ ->
        nil
    end
  end

  defp slack_width(_task, _a), do: nil

  # Position of the constraint date relative to the bar, to draw a tick.
  defp constraint_x(
         %Task{constraint_type: type, constraint_date: %NaiveDateTime{} = date},
         bar,
         a
       )
       when type in [:snet, :snlt, :fnet, :fnlt, :mso, :mfo] do
    Timeline.x(a.timeline, date) - bar.x
  end

  defp constraint_x(_task, _bar, _a), do: nil

  defp scale_rows(timeline, a, today) do
    minor = List.last(timeline.scales)

    for scale <- timeline.scales do
      timeline
      |> Timeline.cells(scale, a.format)
      |> Enum.map(fn cell ->
        classes = [
          scale == minor and scale.unit in [:hour, :day] and non_working?(a, cell.start) and
            "gx-scale-cell--weekend",
          scale.unit in [:hour, :day, :week, :month] and
            NaiveDateTime.compare(cell.start, today) != :gt and
            NaiveDateTime.compare(today, cell.end) == :lt and "gx-scale-cell--today",
          scale.class && scale.class.(cell.start)
        ]

        Map.put(cell, :class, classes |> Enum.filter(&is_binary/1) |> Enum.join(" "))
      end)
    end
  end

  defp marker_items(a, timeline, today) do
    today_marker =
      if a.today_marker,
        do: [%Marker{id: :today, date: today, text: a.labels.today, class: "gx-marker--today"}],
        else: []

    for marker <- today_marker ++ Enum.map(a.markers, &Marker.new!/1),
        NaiveDateTime.compare(marker.date, timeline.start_date) != :lt,
        NaiveDateTime.compare(marker.date, timeline.end_date) == :lt do
      %{marker: marker, key: to_string(marker.id), x: Timeline.x(timeline, marker.date)}
    end
  end

  # Weekends, or the non-working days of the global calendar with working time.
  defp non_working?(%{store: %Store{work_time: true, calendar: calendar}}, date),
    do: not GanttEx.Calendar.working_day?(calendar, date)

  defp non_working?(a, date), do: Date.day_of_week(date) in a.weekend

  defp highlights(timeline, a) do
    minor = List.last(timeline.scales)

    if minor.unit in [:minute, :hour, :day] and (a.weekend != [] or a.store.work_time) do
      timeline.start_date
      |> Dates.floor(:day)
      |> Stream.iterate(&Dates.add(&1, 1, :day))
      |> Stream.take_while(&(NaiveDateTime.compare(&1, timeline.end_date) == :lt))
      |> Enum.filter(&non_working?(a, &1))
      |> Enum.map(fn day ->
        x = Timeline.x(timeline, Dates.max(day, timeline.start_date))
        %{x: x, width: Timeline.x(timeline, Dates.add(day, 1, :day)) - x}
      end)
    else
      []
    end
  end

  defp snap_px(timeline, unit) do
    case Timeline.unit_width(timeline, unit) do
      nil -> ""
      width -> :erlang.float_to_binary(width / 1, [:compact, decimals: 3])
    end
  end

  defp grid_width(a, columns) do
    a.column_state.grid_width || a.grid_width || Columns.total_width(columns)
  end

  defp available_columns(a, state \\ nil) do
    Columns.available(a.column, a.labels, layout: state || a.column_state, readonly: a.readonly)
  end

  defp root_style(a, columns, grid_width, bar_height, level, timeline) do
    column_vars =
      columns
      |> Enum.with_index()
      |> Enum.map_join(fn {col, index} -> "--gx-col-#{index}: #{col.width}px; " end)

    "--gx-row-height: #{a.row_height}px; --gx-bar-height: #{bar_height}px; " <>
      "--gx-scale-row-height: #{a.scale_height}px; --gx-height: #{safe_css(a.height, "640px")}; " <>
      "--gx-grid-width: #{if a.show_grid, do: grid_width, else: 0}px; " <>
      "--gx-column-width: #{timeline.column_width}px; " <>
      "--gx-header-height: #{length(level.scales) * a.scale_height}px; " <> column_vars
  end

  defp safe_css(value, default) do
    value = to_string(value)
    if Regex.match?(~r/^[\w\s.%()+\-*\/,]{1,40}$/, value), do: value, else: default
  end

  defp all_parents(socket) do
    store = socket.assigns.store

    store
    |> Store.tasks()
    |> Enum.filter(&Store.has_children?(store, &1.id))
    |> MapSet.new(& &1.id)
  end

  # -- rendering ---------------------------------------------------------------

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :hook, @hook)

    ~H"""
    <div
      id={@id}
      class={[
        "gx-root",
        @summary_bars == :bracket && "gx-root--bracket",
        @filtering.lookahead && "gx-root--windowed",
        @plan_view && "gx-root--plans",
        @class
      ]}
      style={@root_style}
      data-gx-theme={@theme}
      data-gx-snap={@snap_px}
      data-gx-readonly={to_string(@readonly)}
      data-gx-drag-create={to_string(@drag_create and not @readonly)}
      data-gx-reorder={to_string(@reorderable)}
      data-gx-window={@window}
      phx-hook={@hook}
      phx-target={@myself}
    >
      <.toolbar
        :if={@toolbar}
        ctx={@ctx}
        zoom={@zoom_name}
        levels={@zoom_levels}
        export_formats={@export_formats}
        can_add={not @readonly}
        can_undo={@undo and not @readonly and History.can_undo?(@history)}
        can_redo={@undo and not @readonly and History.can_redo?(@history)}
        show_history={@undo and not @readonly}
        show_critical={@show_critical}
        filters={@filtering.definitions != [] && Map.put(@filtering, :queries, @filter_queries)}
        columns={@column_choices}
        popover={@popover}
      >
        {render_slot(@toolbar_actions)}
      </.toolbar>

      <.filter_status
        :if={@toolbar and @filtering.active}
        ctx={@ctx}
        filters={@filtering}
        matched={@filtering.matched}
        total={@filtering.total}
      />

      <div
        id={"#{@id}-viewport"}
        class="gx-viewport"
        tabindex="0"
        aria-label={@labels.chart}
        phx-keydown="key"
        phx-target={@myself}
        data-gx-viewport
      >
        <div class="gx-canvas" style={"width: #{@canvas_width}px"}>
          <div class="gx-header">
            <.grid_header
              :if={@show_grid}
              ctx={@ctx}
              columns={@columns}
              sort={@sort}
              grid_width={@grid_width_value}
            />
            <.scale
              rows={@scale_rows}
              width={@chart_width}
              bands={if(@plan_view, do: Enum.filter(@plan_view.periods, & &1.band), else: [])}
            />
          </div>
          <div class="gx-body">
            <div
              :if={@show_grid}
              id={"#{@id}-grid"}
              class="gx-grid"
              role="treegrid"
              aria-label={@labels.task_list}
              aria-readonly={to_string(@readonly)}
              data-gx-grid
            >
              <div :if={@spacer_top > 0} class="gx-spacer" style={"height: #{@spacer_top}px"}></div>
              <.grid_row
                :for={row <- @window_rows}
                :key={row.uid}
                ctx={@ctx}
                row={row}
                columns={@columns}
                editing={editing_field(@editing, row.key)}
              />
              <div :if={@spacer_bottom > 0} class="gx-spacer" style={"height: #{@spacer_bottom}px"}>
              </div>
              <div :if={@rows == [] and not @filtering.active} class="gx-empty">
                {@labels.no_tasks}
              </div>
              <div :if={@rows == [] and @filtering.active} class="gx-empty">
                <p>{@labels.no_matches}</p>
                <button
                  id={"#{@id}-empty-clear-filters"}
                  type="button"
                  class="gx-btn"
                  phx-click="filters_clear"
                  phx-target={@myself}
                >
                  {@labels.clear_filters}
                </button>
              </div>
              <div
                id={"#{@id}-drop-marker"}
                class="gx-drop-marker"
                phx-update="ignore"
                data-gx-drop-marker
              >
              </div>
            </div>
            <div
              id={"#{@id}-chart"}
              class="gx-chart"
              style={"width: #{@chart_width}px; min-height: #{@chart_height}px"}
              aria-label={@labels.timeline}
              data-gx-chart
            >
              <.highlights highlights={@highlights} />
              <.plan_band
                :for={period <- (@plan_view && @plan_view.periods) || []}
                :if={period.band}
                ctx={@ctx}
                period={period}
              />
              <.markers ctx={@ctx} markers={@marker_items} />
              <.row_marks ctx={@ctx} bars={@window_bars} />
              <.rollups ctx={@ctx} rollups={@window_rollups} />
              <.links ctx={@ctx} links={@window_links} width={@chart_width} height={@chart_height} />
              <.task_bar
                :for={bar <- @window_bars}
                :key={bar.uid}
                ctx={@ctx}
                bar={bar}
                task_text={@task_text}
                tooltip={@tooltip}
              />
              <svg id={"#{@id}-draft"} class="gx-draft" phx-update="ignore" data-gx-draft></svg>
              <.quick_info
                :if={@quick_info_bar}
                ctx={@ctx}
                bar={@quick_info_bar}
                offset={@quick_info_offset}
                editable={not @readonly and not @quick_info_bar.task.readonly}
              />
            </div>
          </div>
          <.resource_panel
            :if={@resource_rows}
            ctx={@ctx}
            rows={@resource_rows}
            width={@chart_width}
            show_grid={@show_grid}
          />
        </div>
      </div>

      <.legend :if={@legend_entries} ctx={@ctx} entries={@legend_entries} />

      <div :if={@notice} class="gx-notice" role="status">
        <span>{@notice}</span>
        <button
          type="button"
          class="gx-btn gx-btn--icon"
          aria-label={@labels.close}
          phx-click="dismiss_notice"
          phx-target={@myself}
        >
          <GanttEx.Live.Icons.icon name={:x_mark} />
        </button>
      </div>

      <.lightbox
        :if={@lightbox_state}
        ctx={@ctx}
        lightbox={@lightbox_state}
        sections={lightbox_sections(@lightbox_sections, @auto_scheduling)}
      >
        <:extra :let={form}>{render_slot(@lightbox_fields, form)}</:extra>
      </.lightbox>
      <.link_editor :if={@link_editor} ctx={@ctx} editor={@link_editor} />
      <.confirm :if={@confirm} ctx={@ctx} confirm={@confirm} />
    </div>
    """
  end

  defp lightbox_sections(sections, true) do
    if :constraint in sections, do: sections, else: sections ++ [:constraint]
  end

  defp lightbox_sections(sections, _auto_scheduling), do: sections

  defp editing_field({key, field}, key), do: field
  defp editing_field(_editing, _key), do: nil

  # -- events: selection and navigation ----------------------------------------

  @impl true
  def handle_event("select", %{"key" => key} = params, socket) do
    from_bar? = params["source"] == "bar"

    socket =
      socket
      |> select_task(key, from_bar?)
      |> assign(quick_info_offset: if(from_bar?, do: Interaction.number(params["offset"])))
      |> prepare()

    # a row of the grid takes the chart to its bar (a clicked bar is already in view)
    {:noreply, if(from_bar?, do: socket, else: locate_bar(socket, key))}
  end

  def handle_event("toggle", %{"key" => key}, socket) do
    socket =
      case Enum.find(socket.assigns.rows, &(&1.key == key and &1.has_children)) do
        nil -> socket
        row -> socket |> open_or_toggle(row) |> assign(quick_info_key: nil)
      end

    {:noreply, prepare(socket)}
  end

  def handle_event("expand_all", _params, socket),
    do: {:noreply, socket |> handle_action(:expand_all) |> prepare()}

  def handle_event("collapse_all", _params, socket),
    do:
      {:noreply,
       socket |> handle_action(:collapse_all) |> assign(quick_info_key: nil) |> prepare()}

  def handle_event("sort", %{"field" => field}, socket) do
    case Enum.find(socket.assigns.columns, &(to_string(&1.field) == field and &1.sortable)) do
      nil ->
        {:noreply, socket}

      %{field: field} ->
        sort =
          case socket.assigns.sort do
            {^field, :asc} -> {field, :desc}
            {^field, :desc} -> nil
            _ -> {field, :asc}
          end

        {:noreply, socket |> assign(sort: sort, quick_info_key: nil) |> prepare()}
    end
  end

  def handle_event("zoom", %{"level" => level}, socket) do
    case Enum.find(socket.assigns.zoom_levels, &(to_string(&1.name) == level)) do
      nil ->
        {:noreply, socket}

      level ->
        {:noreply, socket |> assign(zoom_name: level.name, quick_info_key: nil) |> prepare()}
    end
  end

  def handle_event("zoom_in", _params, socket), do: {:noreply, zoom_step(socket, :in)}
  def handle_event("zoom_out", _params, socket), do: {:noreply, zoom_step(socket, :out)}

  def handle_event("today", _params, socket) do
    x = Timeline.x(socket.assigns.timeline, today(socket.assigns))
    {:noreply, push_event(socket, "gantt_ex:scroll", %{id: socket.assigns.id, x: x})}
  end

  def handle_event("lookahead", %{"weeks" => weeks}, socket) do
    previous = socket.assigns.filter_state

    state =
      if weeks in ["", nil],
        do: Map.delete(previous, :lookahead),
        else: Map.put(previous, :lookahead, weeks)

    {:noreply, put_filters(socket, state)}
  end

  # The width of the viewport only matters to a lookahead (see fit_lookahead/4)
  def handle_event("gx:width", %{"width" => width}, socket) do
    case Interaction.number(width) do
      width when is_number(width) and width > 0 ->
        socket = assign(socket, :viewport_width, min(round(width), 20_000))

        if socket.assigns.filtering.lookahead,
          do: {:noreply, prepare(socket)},
          else: {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("key", %{"key" => key}, socket) do
    a = socket.assigns

    if a.lightbox_state || a.link_editor || a.confirm || a.editing do
      {:noreply, socket}
    else
      {:noreply, handle_key(key, socket)}
    end
  end

  def handle_event("toggle_critical", _params, socket) do
    {:noreply, socket |> assign(show_critical: not socket.assigns.show_critical) |> prepare()}
  end

  def handle_event("undo", _params, socket), do: {:noreply, history_step(socket, :undo)}
  def handle_event("redo", _params, socket), do: {:noreply, history_step(socket, :redo)}

  def handle_event("close_quick_info", _params, socket),
    do: {:noreply, socket |> assign(quick_info_key: nil) |> prepare()}

  def handle_event("dismiss_notice", _params, socket), do: {:noreply, assign(socket, notice: nil)}

  # -- events: filters ---------------------------------------------------------

  def handle_event("filter_search", %{"search" => search}, socket) do
    {:noreply, put_filters(socket, Map.put(socket.assigns.filter_state, :search, search))}
  end

  def handle_event("filters_change", params, socket) do
    a = socket.assigns
    definitions = filter_definitions(a, true)
    # the search and the lookahead have their own controls
    panel =
      params
      |> Map.get("filters", %{})
      |> Map.put("search", a.filter_state[:search])
      |> Map.put("lookahead", a.filter_state[:lookahead])

    queries =
      for definition <- definitions,
          definition.searchable,
          query = params["queries"][to_string(definition.id)],
          is_binary(query),
          into: a.filter_queries,
          do: {definition.id, String.slice(query, 0, 100)}

    {:noreply, socket |> assign(filter_queries: queries) |> put_filters(panel)}
  end

  def handle_event("filter_remove", %{"filter" => id, "value" => key}, socket) do
    state = socket.assigns.filter_state

    state =
      case find_filter(socket.assigns, id) do
        %{id: id} -> Map.update(state, id, [], fn values -> remove_option(values, key) end)
        nil -> state
      end

    {:noreply, put_filters(socket, state)}
  end

  def handle_event("filter_clear", %{"filter" => id}, socket) do
    a = socket.assigns

    case find_filter(a, id) do
      nil ->
        {:noreply, socket}

      %{id: id} ->
        socket
        |> assign(filter_queries: Map.delete(a.filter_queries, id))
        |> put_filters(Map.delete(a.filter_state, id))
        |> then(&{:noreply, &1})
    end
  end

  # The panel clears its own filters: the search and the lookahead have their
  # own controls (and stay). The bar and the empty list clear them all.
  def handle_event("filters_clear", %{"scope" => "panel"}, socket) do
    kept = Map.take(socket.assigns.filter_state, [:search, :lookahead])
    {:noreply, socket |> assign(filter_queries: %{}) |> put_filters(kept)}
  end

  def handle_event("filters_clear", _params, socket) do
    {:noreply, socket |> assign(filter_queries: %{}) |> put_filters(%{})}
  end

  # Popovers do not change the rows: no need to lay out the chart again.
  def handle_event("toggle_popover", %{"popover" => popover}, socket) do
    popover = Enum.find([:filters, :columns], &(Atom.to_string(&1) == popover))
    open = if socket.assigns.popover == popover, do: nil, else: popover
    {:noreply, socket |> assign(popover: open, quick_info_key: nil) |> apply_window()}
  end

  def handle_event("close_popover", _params, socket) do
    {:noreply, assign(socket, popover: nil)}
  end

  # -- events: row actions -----------------------------------------------------

  def handle_event("row_action", %{"action" => action, "key" => key}, socket) do
    task = Store.task_by_key(socket.assigns.store, key)

    case find_action(socket.assigns.columns, action) do
      %{} = action when task != nil ->
        if Columns.action_allowed?(action, task),
          do: {:noreply, row_action(socket, action, key)},
          else: {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  # The arrow keys move the row of a focused drag handle among its siblings.
  def handle_event("row_key", %{"key" => key, "row" => row_key}, socket)
      when key in ["ArrowUp", "ArrowDown"] do
    a = socket.assigns

    socket =
      with_editable_task(socket, row_key, fn task ->
        siblings = Store.child_ids(a.store, task.parent)
        index = Enum.find_index(siblings, &(&1 == task.id))
        target = if key == "ArrowUp", do: index - 1, else: index + 1

        if a.reorderable and target >= 0 and target < length(siblings) do
          socket
          |> apply_result(Store.move_task(a.store, task.id, task.parent, target))
          |> push_event("gantt_ex:focus", %{
            id: a.id,
            selector: "[data-gx-row='#{row_key}'] [data-gx-drag-handle]"
          })
        else
          socket
        end
      end)

    {:noreply, prepare(socket)}
  end

  def handle_event("row_key", _params, socket), do: {:noreply, socket}

  # -- events: columns ---------------------------------------------------------

  def handle_event("columns_visibility", params, socket) do
    a = socket.assigns
    shown = MapSet.new(List.wrap(params["visible"]))
    available = available_columns(a)

    hidden =
      for column <- available,
          not column.tree,
          not MapSet.member?(shown, column.key),
          do: column.key

    # the grid grows or shrinks by the columns shown or hidden, when its width was set
    delta =
      Enum.reduce(available, 0, fn column, delta ->
        cond do
          column.tree -> delta
          column.visible and column.key in hidden -> delta - column.width
          not column.visible and column.key not in hidden -> delta + column.width
          true -> delta
        end
      end)

    state = %{
      a.column_state
      | order: Enum.map(available, & &1.key),
        hidden: hidden,
        grid_width: resized_grid(a, delta)
    }

    {:noreply, socket |> put_columns(state) |> prepare()}
  end

  # Keyboard alternative to dragging in the column chooser.
  def handle_event("column_move", %{"field" => field, "direction" => direction}, socket) do
    choices = available_columns(socket.assigns)
    index = Enum.find_index(choices, &(&1.key == field))
    neighbour = index && Enum.at(choices, if(direction == "up", do: index - 1, else: index + 1))

    socket =
      if index && neighbour && (direction == "down" or index > 0) do
        position = if direction == "up", do: "before", else: "after"
        moved_to = if direction == "up", do: index - 1, else: index + 1
        # at the ends of the list the button gets disabled: focus the other one
        direction =
          cond do
            moved_to == 0 -> "down"
            moved_to == length(choices) - 1 -> "up"
            true -> direction
          end

        socket
        |> move_column(field, neighbour.key, position)
        |> push_event("gantt_ex:focus", %{
          id: socket.assigns.id,
          selector: "[data-gx-column-item='#{field}'] [data-gx-move='#{direction}']"
        })
      else
        socket
      end

    {:noreply, prepare(socket)}
  end

  def handle_event("columns_reset", _params, socket) do
    {:noreply, socket |> put_columns(Columns.normalize_layout(nil)) |> prepare()}
  end

  # -- events: lightbox --------------------------------------------------------

  def handle_event("add", %{"parent" => parent_key}, socket) do
    a = socket.assigns
    parent = if parent_key != "", do: Store.task_by_key(a.store, parent_key)

    if a.readonly or (parent && parent.readonly) do
      {:noreply, socket}
    else
      start = (parent && parent.start_date) || Dates.floor(today(a), :day)

      draft = %{
        text: a.labels.new_task,
        start_date: start,
        duration: 1,
        parent: parent && parent.id
      }

      socket =
        if parent,
          do: assign(socket, collapsed: MapSet.delete(a.collapsed, parent.id)),
          else: socket

      {:noreply, socket |> create_task(draft) |> prepare()}
    end
  end

  def handle_event("open_lightbox", %{"key" => key}, socket) do
    {:noreply, socket |> open_lightbox(key) |> prepare()}
  end

  def handle_event("lightbox_change", %{"task" => params}, socket) do
    case socket.assigns.lightbox_state do
      nil ->
        {:noreply, socket}

      state ->
        errors =
          case TaskForm.cast(params, socket.assigns.duration_unit, socket.assigns.store) do
            {:ok, _attrs} -> []
            {:error, errors} -> errors
          end

        {:noreply,
         assign(socket, lightbox_state: %{state | form: task_form(params, errors, socket)})}
    end
  end

  def handle_event("lightbox_save", %{"task" => params}, socket) do
    a = socket.assigns

    with %{} = state <- a.lightbox_state,
         {:ok, attrs} <- TaskForm.cast(params, a.duration_unit, a.store) do
      meta =
        if state.mode == :new, do: state.draft.meta, else: Store.get_task(a.store, state.id).meta

      attrs =
        params
        |> Interaction.extra_params(meta)
        |> Map.merge(attrs)
        |> Map.merge(Interaction.resource_attrs(params, a.ctx.resources, current_task(a, state)))

      result =
        case state.mode do
          :new -> Store.add_task(a.store, Map.merge(new_task_base(state.draft, attrs), attrs))
          :edit -> Store.update_task(a.store, state.id, attrs)
        end

      case result do
        {:ok, _store, _changes} = ok ->
          key = Store.key(if state.mode == :new, do: state.draft.id, else: state.id)

          socket =
            socket
            |> apply_result(ok)
            |> assign(lightbox_state: nil, selected: key)

          socket =
            case attrs do
              %{parent: parent} when not is_nil(parent) ->
                assign(socket, collapsed: MapSet.delete(socket.assigns.collapsed, parent))

              _ ->
                socket
            end

          {:noreply, prepare(socket)}

        {:error, reason} ->
          {:noreply, socket |> assign(notice: error_message(reason, a.labels)) |> prepare()}
      end
    else
      nil ->
        {:noreply, socket}

      {:error, errors} ->
        state = a.lightbox_state

        {:noreply,
         assign(socket, lightbox_state: %{state | form: task_form(params, errors, socket)})}
    end
  end

  def handle_event("lightbox_cancel", _params, socket) do
    {:noreply, socket |> assign(lightbox_state: nil) |> prepare()}
  end

  # -- events: deletion --------------------------------------------------------

  def handle_event("request_delete", %{"key" => key}, socket) do
    a = socket.assigns
    selection = normalize_selection(a)

    if MapSet.size(selection) > 1 and MapSet.member?(selection, key) and not a.readonly do
      count = length(selected_tasks(a))

      confirm = %{
        kind: :tasks,
        keys: MapSet.to_list(selection),
        message: I18n.confirm_delete_tasks(count, a.labels_locale),
        detail: a.labels.confirm_delete_subtasks
      }

      {:noreply,
       socket |> assign(lightbox_state: nil, quick_info_key: nil, confirm: confirm) |> prepare()}
    else
      request_delete_one(socket, key)
    end
  end

  def handle_event("request_delete_link", %{"key" => key}, socket) do
    socket =
      if not socket.assigns.readonly and Store.link_by_key(socket.assigns.store, key) do
        assign(socket,
          link_editor: nil,
          confirm: %{kind: :link, key: key, message: socket.assigns.labels.confirm_delete_link}
        )
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("confirm_yes", _params, socket) do
    a = socket.assigns

    socket =
      case a.confirm do
        %{kind: :tasks} ->
          ids =
            a
            |> Map.put(:selection, MapSet.new(a.confirm.keys))
            |> selected_tasks()
            |> Enum.map(& &1.id)

          socket
          |> apply_result(batch(a.store, ids, &Store.delete_task/2))
          |> assign(selected: nil, selection: MapSet.new(), quick_info_key: nil)

        %{kind: :task, key: key} ->
          with_editable_task(socket, key, fn task ->
            socket
            |> apply_result(Store.delete_task(a.store, task.id))
            |> assign(selected: nil, quick_info_key: nil)
          end)

        %{kind: :link, key: key} ->
          case Store.link_by_key(a.store, key) do
            nil ->
              socket

            link ->
              socket
              |> apply_result(Store.delete_link(a.store, link.id))
              |> assign(selected_link: nil)
          end

        nil ->
          socket
      end

    {:noreply, socket |> assign(confirm: nil) |> prepare()}
  end

  def handle_event("confirm_no", _params, socket), do: {:noreply, assign(socket, confirm: nil)}

  # -- events: inline editing --------------------------------------------------

  def handle_event("cell_click", %{"key" => key, "field" => field}, socket) do
    a = socket.assigns
    column = Columns.find(a.columns, field)
    row = Enum.find(a.rows, &(&1.key == key))

    socket =
      cond do
        is_nil(row) or is_nil(column) ->
          socket

        a.selected == key and editable_column?(column, row, a) ->
          assign(socket, editing: {key, column.field}, quick_info_key: nil)

        true ->
          socket |> select_task(key, false) |> locate_bar(key)
      end

    {:noreply, prepare(socket)}
  end

  def handle_event("cell_save", %{"key" => key, "field" => field} = params, socket) do
    a = socket.assigns

    socket =
      case {a.editing, Columns.find(a.columns, field)} do
        {{^key, column_field}, %{field: column_field} = column} ->
          task = Store.task_by_key(a.store, key)

          case task && Interaction.cell_attrs(column, params["value"], task, a.duration_unit) do
            attrs when is_map(attrs) ->
              apply_result(socket, Store.update_task(a.store, task.id, attrs))

            _ ->
              socket
          end
          |> assign(editing: nil)

        _ ->
          socket
      end

    {:noreply, prepare(socket)}
  end

  def handle_event("cell_cancel", _params, socket),
    do: {:noreply, socket |> assign(editing: nil) |> prepare()}

  # -- events: links -----------------------------------------------------------

  def handle_event("select_link", %{"key" => key}, socket) do
    a = socket.assigns

    socket =
      case Store.link_by_key(a.store, key) do
        nil ->
          socket

        link ->
          editor =
            if not a.readonly and a.links_editable do
              %{
                key: key,
                form: to_form(LinkForm.params(link), as: :link),
                source: Store.get_task(a.store, link.source),
                target: Store.get_task(a.store, link.target)
              }
            end

          assign(socket, selected_link: key, link_editor: editor, quick_info_key: nil)
      end

    {:noreply, prepare(socket)}
  end

  def handle_event("link_save", %{"link" => params}, socket) do
    a = socket.assigns

    with %{key: key} = editor <- a.link_editor,
         %Link{} = link <- Store.link_by_key(a.store, key) do
      case LinkForm.cast(params) do
        {:ok, attrs} ->
          socket =
            case Store.update_link(a.store, link.id, attrs) do
              {:ok, _store, _changes} = ok ->
                socket |> apply_result(ok) |> assign(link_editor: nil, selected_link: nil)

              {:error, reason} ->
                assign(socket, notice: error_message(reason, a.labels))
            end

          {:noreply, prepare(socket)}

        {:error, errors} ->
          form = to_form(params, as: :link, errors: translate_errors(errors, a.labels))
          {:noreply, assign(socket, link_editor: %{editor | form: form})}
      end
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("link_close", _params, socket) do
    {:noreply, socket |> assign(link_editor: nil, selected_link: nil) |> prepare()}
  end

  # -- events: export ----------------------------------------------------------

  def handle_event("export", %{"format" => format}, socket) do
    a = socket.assigns

    case Enum.find(a.export_formats, &(to_string(&1) == format)) do
      nil ->
        {:noreply, socket}

      format ->
        opts = [
          filename: a.export_filename,
          headers: csv_headers(a.labels),
          # images show what is on screen: current rows, zoom and language
          rows: a.rows,
          timeline: a.timeline,
          locale: a.labels_locale,
          row_height: a.row_height
        ]

        payload =
          case format do
            :png ->
              {filename, _mime, svg} = Export.export(a.store, :svg, opts)

              %{
                filename: Path.rootname(filename) <> ".png",
                mime: "image/png",
                content: svg,
                convert: "png"
              }

            format ->
              {filename, mime, content} = Export.export(a.store, format, opts)
              %{filename: filename, mime: mime, content: content}
          end

        {:noreply, push_event(socket, "gantt_ex:download", Map.put(payload, :id, a.id))}
    end
  end

  # -- events: hook (drag & drop) ----------------------------------------------

  def handle_event("gx:drag", %{"key" => key, "mode" => mode} = params, socket) do
    a = socket.assigns

    socket =
      with_editable_task(socket, key, fn task ->
        case Interaction.drag_attrs(task, mode, params, interaction_ctx(a)) do
          nil ->
            socket

          %{start_date: start} = attrs when mode == "move" ->
            if MapSet.size(a.selection) > 1 and MapSet.member?(a.selection, key) do
              apply_result(socket, move_selection(a, NaiveDateTime.diff(start, task.start_date)))
            else
              apply_result(socket, Store.update_task(a.store, task.id, attrs))
            end

          attrs ->
            apply_result(socket, Store.update_task(a.store, task.id, attrs))
        end
      end)

    {:reply, %{ok: true}, prepare(socket)}
  end

  def handle_event("gx:link", %{"source" => source, "target" => target} = params, socket) do
    a = socket.assigns

    with false <- a.readonly or not a.links_editable,
         %Task{} = from <- Store.task_by_key(a.store, source),
         %Task{} = to <- Store.task_by_key(a.store, target),
         {:ok, from_side} <- Interaction.side(params["from"]),
         {:ok, to_side} <- Interaction.side(params["to"]) do
      attrs = %{
        id: temp_id(),
        source: from.id,
        target: to.id,
        type: Link.type_for(from_side, to_side)
      }

      socket =
        case Store.add_link(a.store, attrs) do
          {:ok, _store, _changes} = ok -> apply_result(socket, ok)
          {:error, _reason} -> assign(socket, notice: a.labels.link_rejected)
        end

      {:reply, %{ok: true}, prepare(socket)}
    else
      _ -> {:reply, %{ok: false}, socket}
    end
  end

  def handle_event(
        "gx:reorder",
        %{"key" => key, "target" => target_key, "position" => position},
        socket
      ) do
    a = socket.assigns

    socket =
      with_editable_task(socket, key, fn task ->
        with true <- a.reorderable,
             %Task{} = target <- Store.task_by_key(a.store, target_key),
             true <- target.id != task.id,
             {parent, index} <- Interaction.drop_position(a.store, task, target, position) do
          socket
          |> apply_result(Store.move_task(a.store, task.id, parent, index))
          |> assign(
            collapsed: if(parent, do: MapSet.delete(a.collapsed, parent), else: a.collapsed)
          )
        else
          _ -> socket
        end
      end)

    {:reply, %{ok: true}, prepare(socket)}
  end

  def handle_event("gx:create", %{"x" => x, "width" => width}, socket) do
    a = socket.assigns

    with false <- a.readonly,
         x when is_number(x) <- Interaction.number(x),
         width when is_number(width) <- Interaction.number(width) do
      {start, finish} = Interaction.span_at(interaction_ctx(a), x, width)
      draft = %{text: a.labels.new_task, start_date: start, end_date: finish, parent: nil}
      {:reply, %{ok: true}, socket |> create_task(draft) |> prepare()}
    else
      _ -> {:reply, %{ok: false}, socket}
    end
  end

  # `delta` is how much the column grew on the screen: the tree column may be
  # wider than its width (it takes the free width of the grid)
  def handle_event("gx:resize", %{"column" => column, "width" => width} = params, socket) do
    a = socket.assigns

    socket =
      case {column, Interaction.number(width)} do
        {_, nil} ->
          socket

        {"__grid", width} ->
          put_columns(socket, %{
            a.column_state
            | grid_width: width |> round() |> max(120) |> min(2000)
          })

        {field, width} ->
          case Enum.find(a.columns, &(&1.key == field)) do
            nil ->
              socket

            col ->
              width = width |> round() |> max(if(col.tree, do: 120, else: 32)) |> min(800)
              delta = Interaction.number(params["delta"]) || width - col.width

              socket
              |> put_columns(%{
                a.column_state
                | widths: Map.put(a.column_state.widths, field, width),
                  grid_width: resized_grid(a, round(delta))
              })
          end
      end

    {:reply, %{ok: true}, prepare(socket)}
  end

  def handle_event(
        "gx:column_move",
        %{"field" => field, "target" => target, "position" => position},
        socket
      )
      when position in ["before", "after"] do
    {:reply, %{ok: true}, socket |> move_column(field, target, position) |> prepare()}
  end

  def handle_event("gx:select", %{"key" => key, "mode" => mode}, socket) do
    {:noreply, socket |> extend_selection(key, mode) |> prepare()}
  end

  def handle_event("gx:viewport", %{"top" => top, "height" => height}, socket) do
    case {Interaction.number(top), Interaction.number(height)} do
      {top, height} when is_number(top) and is_number(height) and top >= 0 and height > 0 ->
        {:noreply,
         socket |> assign(viewport: %{top: top, height: min(height, 10_000)}) |> apply_window()}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("gx:dblclick", %{"key" => key}, socket) do
    {:noreply, socket |> open_lightbox(key) |> prepare()}
  end

  # -- helpers: columns --------------------------------------------------------

  # Applies a new column layout and reports it when it changed.
  defp put_columns(socket, state) do
    a = socket.assigns

    old =
      Columns.layout(
        Columns.available(a.column, a.labels, layout: a.column_state),
        a.column_state
      )

    new = Columns.layout(Columns.available(a.column, a.labels, layout: state), state)

    if new != old,
      do: notify(socket, %Event{gantt_id: a.id, type: :columns_changed, columns: new})

    shown =
      for column <- available_columns(a, state),
          column.visible,
          into: MapSet.new(),
          do: column.field

    # sorting or editing a column that is no longer shown would be confusing
    sort = with {field, _direction} <- a.sort, true <- MapSet.member?(shown, field), do: a.sort
    editing = with {_key, field} <- a.editing, true <- MapSet.member?(shown, field), do: a.editing

    assign(socket,
      column_state: state,
      sort: if(sort in [nil, false], do: nil, else: sort),
      editing: if(editing in [nil, false], do: nil, else: editing)
    )
  end

  defp move_column(socket, field, target, position) do
    available = available_columns(socket.assigns)
    order = Enum.map(available, & &1.key)

    if field != target and field in order and target in order do
      order = List.delete(order, field)
      index = Enum.find_index(order, &(&1 == target)) + if(position == "after", do: 1, else: 0)

      # the layout now lists every column: keep the hidden ones hidden
      put_columns(socket, %{
        socket.assigns.column_state
        | order: List.insert_at(order, index, field),
          hidden: for(column <- available, not column.visible, do: column.key)
      })
    else
      socket
    end
  end

  # A grid with a set width (by the user or the `:grid_width` attribute) is
  # resized with its columns; otherwise it keeps fitting them.
  defp resized_grid(a, delta) do
    if a.column_state.grid_width || a.grid_width,
      do: max(a.grid_width_value + delta, 120),
      else: nil
  end

  # -- helpers: row actions ----------------------------------------------------

  defp find_action(columns, id) do
    columns
    |> Enum.filter(&(&1.field == :actions))
    |> Enum.flat_map(& &1.actions)
    |> Enum.find(&(to_string(&1.id) == id and not (&1.builtin and &1.id == :drag)))
  end

  defp row_action(socket, %{builtin: true, id: :rename}, key) do
    with_editable_task(socket, key, fn _task ->
      a = socket.assigns
      text = Enum.find(a.columns, &(&1.field == :text and &1.editor))

      if text do
        socket
        |> select_task(key, false)
        |> assign(editing: {key, :text})
        |> prepare()
      else
        socket |> open_lightbox(key) |> prepare()
      end
    end)
  end

  defp row_action(socket, %{builtin: true, id: :edit}, key),
    do: socket |> open_lightbox(key) |> prepare()

  defp row_action(socket, %{builtin: true, id: :block}, key) do
    with_editable_task(socket, key, fn task ->
      socket
      |> apply_result(
        Store.update_task(socket.assigns.store, task.id, %{blocked: not task.blocked})
      )
      |> prepare()
    end)
  end

  defp row_action(socket, %{builtin: true, id: :delete}, key) do
    {:noreply, socket} = request_delete_one(socket, key)
    socket
  end

  # Actions handled by the host, such as opening a side panel
  defp row_action(socket, %{editing: editing, id: id}, key) do
    run = fn task ->
      notify(socket, %Event{
        gantt_id: socket.assigns.id,
        type: :task_action,
        action: id,
        task: task
      })

      socket
    end

    if editing, do: with_editable_task(socket, key, run), else: with_task(socket, key, run)
  end

  # -- helpers: filters --------------------------------------------------------

  # Applies new filter values and tells the parent, which may persist them.
  # The results start at the top of the chart.
  defp put_filters(socket, values) do
    a = socket.assigns
    values = Filter.normalize(values, filter_definitions(a, true))

    # typing in the search of a filter only changes the panel
    if values == a.filter_state do
      socket
    else
      notify(socket, %Event{gantt_id: a.id, type: :filters_changed, filters: values})

      socket
      |> lookahead_zoom(a.filter_state, values)
      |> assign(
        filter_state: values,
        quick_info_key: nil,
        editing: nil,
        viewport: %{a.viewport | top: 0}
      )
      |> push_event("gantt_ex:scroll", %{id: a.id, y: 0, height: 0})
      |> prepare()
    end
  end

  defp find_filter(a, id),
    do: a |> filter_definitions(true) |> Enum.find(&(to_string(&1.id) == id))

  # A lookahead is read day by day: coarser scales switch to the :day level
  # when it starts (chosen in the menu or restored from the filter values),
  # and go back when it ends, however it is removed (the menu, its chip,
  # clearing the filters), unless the zoom was changed meanwhile.
  defp lookahead_zoom(socket, previous, state) do
    case {Map.has_key?(previous, :lookahead), Map.has_key?(state, :lookahead)} do
      {false, true} -> start_lookahead_zoom(socket)
      {true, false} -> end_lookahead_zoom(socket)
      _ -> socket
    end
  end

  defp start_lookahead_zoom(socket) do
    a = socket.assigns
    minor = List.last(Zoom.find(a.zoom_levels, a.zoom_name).scales)

    day_level =
      Enum.find(a.zoom_levels, &(&1.name == :day)) ||
        Enum.find(a.zoom_levels, &(List.last(&1.scales).unit == :day))

    if minor.unit not in [:minute, :hour, :day] and day_level != nil,
      do:
        assign(socket, zoom_name: day_level.name, lookahead_zoom: {a.zoom_name, day_level.name}),
      else: socket
  end

  defp end_lookahead_zoom(socket) do
    case socket.assigns.lookahead_zoom do
      {before, day} when day == socket.assigns.zoom_name ->
        assign(socket, zoom_name: before, lookahead_zoom: nil)

      _ ->
        assign(socket, lookahead_zoom: nil)
    end
  end

  defp remove_option(values, key),
    do: Enum.reject(List.wrap(values), &(Filter.option_key(&1) == key))

  # -- helpers: tasks ----------------------------------------------------------

  defp select_task(socket, key, from_bar?) do
    a = socket.assigns

    case Store.task_by_key(a.store, key) do
      nil ->
        socket

      task ->
        if a.selected != key or MapSet.size(a.selection) > 1,
          do: notify_selection(socket, task, [task.id])

        assign(socket,
          selected: key,
          selection: MapSet.new([key]),
          selected_link: nil,
          quick_info_key: if(from_bar? and a.quick_info, do: key),
          editing: nil,
          notice: nil
        )
    end
  end

  defp notify_selection(socket, task, ids) do
    notify(socket, %Event{
      gantt_id: socket.assigns.id,
      type: :task_selected,
      task: task,
      selection: ids
    })
  end

  defp request_delete_one(socket, key) do
    socket =
      with_editable_task(socket, key, fn task ->
        labels = socket.assigns.labels

        assign(socket,
          lightbox_state: nil,
          quick_info_key: nil,
          confirm: %{
            kind: :task,
            key: key,
            message: labels.confirm_delete_task,
            detail:
              if(Store.has_children?(socket.assigns.store, task.id),
                do: labels.confirm_delete_subtasks
              )
          }
        )
      end)

    {:noreply, prepare(socket)}
  end

  # Moves every movable selected task by the same amount of time.
  defp move_selection(a, seconds) do
    tasks =
      a
      |> selected_tasks()
      |> Enum.reject(&(&1.type == :project and Store.has_children?(a.store, &1.id)))

    batch(a.store, tasks, fn store, task ->
      Store.update_task(store, task.id, %{
        start_date: NaiveDateTime.add(task.start_date, seconds, :second)
      })
    end)
  end

  # Ctrl/Cmd+click toggles a task, Shift+click selects the rows in between.
  defp extend_selection(socket, key, mode) do
    a = socket.assigns

    case Store.task_by_key(a.store, key) do
      nil ->
        socket

      task ->
        selection =
          case mode do
            "range" ->
              keys = Enum.map(a.rows, & &1.key)

              from =
                Enum.find_index(keys, &(&1 == a.selected)) || Enum.find_index(keys, &(&1 == key))

              to = Enum.find_index(keys, &(&1 == key))

              if from && to,
                do: keys |> Enum.slice(min(from, to)..max(from, to)) |> MapSet.new(),
                else: MapSet.new([key])

            _toggle ->
              current = normalize_selection(a)

              if MapSet.member?(current, key),
                do: MapSet.delete(current, key),
                else: MapSet.put(current, key)
          end

        primary =
          if MapSet.member?(selection, key),
            do: key,
            else: selection |> MapSet.to_list() |> List.first()

        ids = selection |> MapSet.to_list() |> Enum.map(&Store.task_by_key(a.store, &1).id)
        notify_selection(socket, (primary && Store.task_by_key(a.store, primary)) || task, ids)

        assign(socket, selected: primary, selection: selection, quick_info_key: nil, editing: nil)
    end
  end

  # Applies `fun` to several items as a single change (one undo step).
  defp batch(store, items, fun) do
    Enum.reduce(items, {:ok, store, []}, fn item, {:ok, store, acc} ->
      case fun.(store, item) do
        {:ok, store, changes} -> {:ok, store, acc ++ changes}
        {:error, _reason} -> {:ok, store, acc}
      end
    end)
  end

  defp selected_tasks(a) do
    a.selection
    |> Enum.map(&Store.task_by_key(a.store, &1))
    |> Enum.reject(&(is_nil(&1) or &1.readonly))
  end

  defp with_task(socket, key, fun) do
    case Store.task_by_key(socket.assigns.store, key) do
      nil -> socket
      task -> fun.(task)
    end
  end

  defp with_editable_task(socket, key, fun) do
    with_task(socket, key, fn task ->
      if socket.assigns.readonly or task.readonly, do: socket, else: fun.(task)
    end)
  end

  # Opens the lightbox for a new task, or creates it right away when the
  # lightbox is disabled.
  defp create_task(socket, draft) do
    a = socket.assigns

    {:ok, task} =
      draft |> Map.put(:id, temp_id()) |> Task.new!() |> Store.schedule(a.duration_unit)

    if a.lightbox do
      assign(socket,
        lightbox_state: %{
          mode: :new,
          id: task.id,
          key: Store.key(task.id),
          draft: Map.from_struct(task),
          form: task_form(lightbox_params(task, a.duration_unit), [], socket),
          parent_options: parent_options(a.store, nil)
        },
        quick_info_key: nil
      )
    else
      socket
      |> apply_result(Store.add_task(a.store, task))
      |> assign(selected: Store.key(task.id))
    end
  end

  defp open_lightbox(socket, key) do
    a = socket.assigns

    with_editable_task(socket, key, fn task ->
      if a.lightbox do
        assign(socket,
          lightbox_state: %{
            mode: :edit,
            id: task.id,
            key: key,
            draft: nil,
            form: task_form(lightbox_params(task, a.duration_unit), [], socket),
            parent_options: parent_options(a.store, task.id)
          },
          selected: key,
          quick_info_key: nil,
          editing: nil
        )
      else
        socket
      end
    end)
  end

  defp current_task(_a, %{mode: :new, draft: draft}), do: draft
  defp current_task(a, %{id: id}), do: Store.get_task(a.store, id)

  # Scalar meta fields are included so `:lightbox_fields` inputs get their values.
  defp lightbox_params(task, unit) do
    task.meta
    |> Enum.filter(fn {key, value} ->
      (is_atom(key) or is_binary(key)) and
        (is_binary(value) or is_number(value) or is_boolean(value))
    end)
    |> Map.new(fn {key, value} -> {to_string(key), to_string(value)} end)
    |> Map.merge(TaskForm.params(task, unit))
    |> Map.put("resources", Enum.map(task.resources || [], &Store.key(&1.id)))
  end

  # The draft end date is stale once the form sets a new start or duration.
  defp new_task_base(draft, attrs) do
    if Map.has_key?(attrs, :start_date) or Map.has_key?(attrs, :duration),
      do: Map.delete(draft, :end_date),
      else: draft
  end

  defp task_form(params, errors, socket) do
    to_form(params, as: :task, errors: translate_errors(errors, socket.assigns.labels))
  end

  defp translate_errors(errors, labels) do
    Enum.map(errors, fn {field, reason} -> {field, {Map.fetch!(labels, reason), []}} end)
  end

  # Every task but the edited one and its descendants can be its parent.
  defp parent_options(store, id) do
    excluded = if id, do: MapSet.new([id | Store.descendant_ids(store, id)]), else: MapSet.new()

    for row <- Store.rows(store), not MapSet.member?(excluded, row.task.id) do
      {String.duplicate("  ", row.level) <> row.task.text, row.key}
    end
  end

  defp editable_column?(column, row, a) do
    a.inline_edit and not a.readonly and not row.task.readonly and not is_nil(column.editor) and
      not (column.field in [:start_date, :end_date, :duration] and row.has_children and
             row.task.type == :project)
  end

  defp interaction_ctx(a) do
    %{store: a.store, timeline: a.timeline, unit: a.duration_unit, week_start: a.week_start}
  end

  # -- helpers: keyboard -------------------------------------------------------

  defp handle_key(key, socket) do
    a = socket.assigns
    index = Enum.find_index(a.rows, &(&1.key == a.selected))
    row = index && Enum.at(a.rows, index)

    case key do
      "ArrowDown" ->
        select_row(socket, if(index, do: index + 1, else: 0))

      "ArrowUp" ->
        select_row(socket, if(index, do: index - 1, else: 0))

      "Home" ->
        select_row(socket, 0)

      "End" ->
        select_row(socket, length(a.rows) - 1)

      "ArrowRight" when not is_nil(row) ->
        expand_or_descend(socket, row, index)

      "ArrowLeft" when not is_nil(row) ->
        collapse_or_ascend(socket, row)

      " " when not is_nil(row) and row.has_children ->
        prepare(toggle_row(socket, row))

      "Enter" when not is_nil(row) ->
        socket |> open_lightbox(row.key) |> prepare()

      key when key in ["Delete", "Backspace"] ->
        request_delete_selected(socket, row)

      "Escape" when not is_nil(a.popover) ->
        assign(socket, popover: nil)

      "Escape" ->
        socket
        |> assign(selected: nil, selection: MapSet.new(), selected_link: nil, quick_info_key: nil)
        |> prepare()

      key when key in ["+", "="] ->
        zoom_step(socket, :in)

      "-" ->
        zoom_step(socket, :out)

      _ ->
        socket
    end
  end

  defp select_row(socket, index) do
    rows = socket.assigns.rows
    index = skip_groups(rows, index |> max(0) |> min(length(rows) - 1), socket.assigns.selected)

    case rows != [] && Enum.at(rows, index |> max(0) |> min(length(rows) - 1)) do
      false ->
        socket

      row ->
        socket
        |> select_task(row.key, false)
        |> push_event(
          "gantt_ex:scroll",
          Map.merge(bar_span(socket.assigns, row.key), %{
            id: socket.assigns.id,
            y: row.index * socket.assigns.row_height,
            height: socket.assigns.row_height
          })
        )
        |> prepare()
    end
  end

  # Scrolls the chart to the bar of a task, when it has one in the timeline, and
  # makes it pulse so the eye finds it.
  defp locate_bar(socket, key) do
    case bar_span(socket.assigns, key) do
      span when span == %{} ->
        socket

      span ->
        push_event(socket, "gantt_ex:scroll", Map.merge(span, %{id: socket.assigns.id, key: key}))
    end
  end

  # The horizontal extent of the bar (and its segments) of a task, within the chart.
  defp bar_span(a, key) do
    spans = for bar <- a.bars, bar.key == key, do: {bar.x, bar.x + bar.width}

    with [_ | _] <- spans,
         from = spans |> Enum.map(&elem(&1, 0)) |> Enum.min() |> max(0),
         to = spans |> Enum.map(&elem(&1, 1)) |> Enum.max() |> min(a.chart_width),
         true <- to >= from do
      %{x: from, width: to - from}
    else
      _ -> %{}
    end
  end

  # Group rows cannot be selected: move to the next task row in the same direction.
  defp skip_groups(rows, index, selected) do
    current = Enum.find_index(rows, &(&1.key == selected)) || -1
    step = if index < current, do: -1, else: 1

    index
    |> Stream.iterate(&(&1 + step))
    |> Stream.take_while(&(&1 >= 0 and &1 < length(rows)))
    |> Enum.find(index, &(not Enum.at(rows, &1)[:group]))
  end

  # Branches whose children are not loaded yet are requested from the parent.
  defp open_or_toggle(socket, row) do
    a = socket.assigns

    if row.task.has_children and Store.child_ids(a.store, row.task.id) == [] do
      if not MapSet.member?(a.loading, row.key),
        do: notify(socket, %Event{gantt_id: a.id, type: :branch_requested, task: row.task})

      assign(socket,
        loading: MapSet.put(a.loading, row.key),
        collapsed: MapSet.delete(a.collapsed, row.task.id)
      )
    else
      toggle_row(socket, row)
    end
  end

  defp expand_or_descend(socket, row, index) do
    cond do
      row.has_children and not row.open -> prepare(open_or_toggle(socket, row))
      row.has_children -> select_row(socket, index + 1)
      true -> socket
    end
  end

  defp collapse_or_ascend(socket, row) do
    cond do
      row.open ->
        prepare(toggle_row(socket, row))

      row.parent_key ->
        parent = Enum.find_index(socket.assigns.rows, &(&1.key == row.parent_key))
        select_row(socket, parent)

      true ->
        socket
    end
  end

  defp toggle_row(socket, row) do
    collapsed = socket.assigns.collapsed

    collapsed =
      if row.open,
        do: MapSet.put(collapsed, row.task.id),
        else: MapSet.delete(collapsed, row.task.id)

    assign(socket, collapsed: collapsed)
  end

  defp request_delete_selected(socket, row) do
    cond do
      socket.assigns.selected_link ->
        {:noreply, socket} =
          handle_event("request_delete_link", %{"key" => socket.assigns.selected_link}, socket)

        socket

      row ->
        {:noreply, socket} = handle_event("request_delete", %{"key" => row.key}, socket)
        socket

      true ->
        socket
    end
  end

  defp zoom_step(socket, direction) do
    a = socket.assigns

    name =
      case direction do
        :in -> Zoom.zoom_in(a.zoom_levels, a.zoom_name)
        :out -> Zoom.zoom_out(a.zoom_levels, a.zoom_name)
      end

    socket |> assign(zoom_name: name, quick_info_key: nil) |> prepare()
  end

  # -- helpers: results and notifications --------------------------------------

  defp apply_result(socket, {:ok, store, changes}) do
    {store, changes} = auto_schedule(socket.assigns, store, changes)

    history =
      if changes != [] and socket.assigns.undo,
        do: History.record(socket.assigns.history, socket.assigns.store),
        else: socket.assigns.history

    socket = assign(socket, store: store, history: history, notice: nil)
    notify_changes(socket, changes)
  end

  defp apply_result(socket, {:error, reason}) do
    assign(socket, notice: error_message(reason, socket.assigns.labels))
  end

  # With auto-scheduling, every change is followed by a scheduling pass whose
  # moves belong to the same undo step.
  defp auto_schedule(%{auto_scheduling: true} = a, store, [_ | _] = changes) do
    {:ok, store, scheduled} = Scheduler.schedule(store, strict: a.auto_scheduling_strict)
    {store, Scheduler.compact(changes ++ scheduled)}
  end

  defp auto_schedule(_a, store, changes), do: {store, changes}

  defp notify_changes(%{assigns: %{batch_events: true, id: id}} = socket, [_ | _] = changes) do
    events = Enum.map(changes, &Event.from_change(id, &1))
    notify(socket, %Event{gantt_id: id, type: :batch, events: events})
    socket
  end

  defp notify_changes(socket, changes) do
    Enum.each(changes, &notify(socket, Event.from_change(socket.assigns.id, &1)))
    socket
  end

  defp notify(socket, event), do: Event.notify(socket.assigns.notify || self(), event)

  # Undo / redo replace the store with a snapshot and report the differences.
  defp history_step(%{assigns: a} = socket, direction) do
    result =
      if a.undo and not a.readonly,
        do: apply(History, direction, [a.history, a.store]),
        else: :empty

    case result do
      {:ok, history, store, changes} ->
        socket
        |> sync_ui_state(a.store, store)
        |> assign(store: store, history: history, notice: nil, lightbox_state: nil, confirm: nil)
        |> notify_changes(changes)
        |> prepare()

      :empty ->
        socket
    end
  end

  defp error_message(reason, labels)
       when reason in [:self_link, :duplicate_link, :cycle, :missing_task],
       do: labels.link_rejected

  defp error_message({:invalid, :end_date}, labels), do: labels.end_before_start
  defp error_message(_reason, labels), do: labels.invalid_date

  defp csv_headers(labels) do
    [
      "ID",
      labels.task_name,
      labels.type,
      labels.start_time,
      labels.end_time,
      labels.duration,
      labels.progress <> " (%)",
      labels.parent,
      labels.link
    ]
  end

  defp temp_id, do: "gx-" <> Base.url_encode64(:crypto.strong_rand_bytes(9), padding: false)
end
