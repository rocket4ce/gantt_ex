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
    * tasks, projects (dates rolled up from children) and milestones
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
    * `:show_slack` - draw the free slack of each task after its bar.
      Defaults to `false`.
    * `:resources` - the resources tasks are assigned to (see `GanttEx.Resource`).
      Tasks list their assignments in `:resources`; the lightbox gets a
      `:resources` section and grids can show a `:resources` column.
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
      (their ancestors are shown too).
    * `:notify` - the pid that receives the events. Defaults to the parent LiveView.

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
    * `:task_class` - a function returning extra CSS classes for a task bar.
    * `:class` - extra classes for the root element.

  ## Slots

    * `:column` - grid columns. Attributes: `field` (required: `:text`,
      `:start_date`, `:end_date`, `:duration`, `:progress`, `:type`, `:add` or
      any key of the task `:meta`), `label`, `width`, `align`, `tree`
      (shows the tree in this column), `editor` (`:text`, `:date`, `:number`,
      `:progress`, `:type` or `nil`) and `sortable`. The inner block receives
      the task:

          <:column field={:owner} label="Owner" width={120} :let={task}>
            {task.meta[:owner]}
          </:column>

    * `:task_text` - content of the bars, receives the task.
    * `:tooltip` - content of the tooltips, receives the task.
    * `:lightbox_fields` - extra lightbox fields, receives the form. Values
      are stored in the task `:meta`.
    * `:toolbar_actions` - extra content for the toolbar.

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
    markers: [],
    today_marker: false,
    undo: true,
    auto_scheduling: false,
    auto_scheduling_strict: false,
    critical_path: false,
    show_slack: false,
    baselines: false,
    resources: [],
    resource_panel: false,
    group_by: nil,
    group_label: nil,
    export_filename: "gantt",
    theme: "auto",
    class: nil,
    task_class: nil,
    filter: nil,
    notify: nil,
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
       lightbox_state: nil,
       link_editor: nil,
       confirm: nil,
       editing: nil,
       sort: nil,
       notice: nil,
       zoom_name: nil,
       zoom_attr: nil,
       column_widths: %{},
       grid_width_override: nil,
       labels_locale: nil,
       timeline: nil,
       viewport: %{top: 0, height: 900},
       history: History.new(),
       show_critical: nil,
       analysis: nil
     )}
  end

  @impl true
  def update(%{action: action}, socket) do
    {:ok, socket |> handle_action(action) |> prepare()}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(Map.drop(assigns, [:tasks, :links, :zoom_levels]))
      |> assign_defaults(assigns)
      |> load_data(assigns)
      |> assign_i18n()
      |> assign_zoom()
      |> prepare()

    {:ok, socket}
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
      calendars: socket.assigns.calendars
    ]

    source = {tasks, links, store_opts}

    if source == socket.assigns.data_source do
      socket
    else
      store = Store.new!(tasks, links, store_opts)

      socket
      |> sync_ui_state(socket.assigns.store, store)
      |> assign(store: store, data_source: source)
    end
  end

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
      editing: nil
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

    a = Map.put(a, :ctx_resources, ctx_resources)
    selection = normalize_selection(a)
    show_critical = if is_nil(a.show_critical), do: a.critical_path, else: a.show_critical
    analysis = analysis(a, show_critical)
    a = Map.merge(a, %{selection: selection, analysis: analysis, show_critical: show_critical})

    rows =
      a.store
      |> Store.rows(
        collapsed: a.collapsed,
        filter: a.filter,
        sort: a.sort,
        group_by: group_spec(a)
      )
      |> Enum.map(&Map.put(&1, :selected, MapSet.member?(selection, &1.key)))
      |> Enum.map(&Map.put(&1, :slack, analysis && analysis.tasks[&1.task.id]))

    timeline = build_timeline(a, level, today)

    layout =
      Layout.build(a.store, rows, timeline,
        row_height: a.row_height,
        bar_height: bar_height,
        baselines: a.baselines
      )

    bars =
      Enum.map(layout.bars ++ layout.segments, &decorate_bar(&1, Map.put(a, :timeline, timeline)))

    columns = Columns.build(a.column, a.labels, widths: a.column_widths, readonly: a.readonly)
    grid_width = grid_width(a, columns)
    chart_height = max(layout.height, 0)

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
      analysis_cache: analysis && {a.store, analysis},
      level: level,
      rows: rows,
      bars: bars,
      rollups: layout.rollups,
      link_paths:
        Enum.map(layout.links, fn link ->
          Map.merge(link, %{
            selected: link.key == a.selected_link,
            critical:
              show_critical and analysis != nil and MapSet.member?(analysis.links, link.link.id)
          })
        end),
      columns: columns,
      grid_width_value: grid_width,
      chart_width: layout.width,
      chart_height: chart_height,
      canvas_width: layout.width + if(a.show_grid, do: grid_width, else: 0),
      snap_px: snap_px(timeline, a.duration_unit),
      resource_rows:
        a.resource_panel && a.resources != [] &&
          ResourceLoad.compute(a.store, a.resources, timeline),
      marker_items: marker_items(a, timeline, today),
      root_style: root_style(a, columns, grid_width, bar_height, level),
      ctx: %{
        id: a.id,
        myself: a.myself,
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
        resources: a.ctx_resources
      }
    )
    |> apply_window()
  end

  # Smart rendering: only the rows around the viewport (and the bars and links
  # crossing them) are rendered; spacers keep the scroll height.
  @window_buffer 25
  @auto_threshold 120

  defp apply_window(%{assigns: a} = socket) do
    count = length(a.rows)

    {first, last} =
      if smart_rendering?(a.smart_rendering, count) do
        %{top: top, height: height} = a.viewport
        first = max(div(trunc(top), a.row_height) - @window_buffer, 0)
        last = min(div(trunc(top + height), a.row_height) + @window_buffer, count - 1)
        {first, max(last, first)}
      else
        {0, count - 1}
      end

    visible? = fn row -> row >= first and row <= last end

    bars = Enum.filter(a.bars, &visible?.(&1.row))

    assign(socket,
      window: if(smart_rendering?(a.smart_rendering, count), do: "#{first}:#{last}:#{count}"),
      window_rows: Enum.slice(a.rows, first..last//1),
      window_bars: bars,
      window_rollups: Enum.filter(a.rollups, &visible?.(&1.row)),
      window_links:
        Enum.filter(a.link_paths, fn link ->
          min(link.source_row, link.target_row) <= last and
            max(link.source_row, link.target_row) >= first
        end),
      spacer_top: first * a.row_height,
      spacer_bottom: max(count - 1 - last, 0) * a.row_height,
      quick_info_bar: a.quick_info_key && Enum.find(bars, &(&1.key == a.quick_info_key))
    )
  end

  defp smart_rendering?(:auto, count), do: count > @auto_threshold
  defp smart_rendering?(enabled, count), do: enabled == true and count > 0

  defp group_spec(%{group_by: nil}), do: nil

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

  # CPM runs when something shows it, and only again when the store changes.
  defp analysis(a, show_critical) do
    needed =
      show_critical or a.show_slack or
        Enum.any?(a.column, &(Map.get(&1, :field) in [:total_slack, :free_slack]))

    cached = a[:analysis_cache]

    cond do
      not needed -> nil
      cached && elem(cached, 0) == a.store -> elem(cached, 1)
      true -> CriticalPath.analyze(a.store)
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

  defp build_timeline(a, level, today) do
    {start, finish} =
      case {Dates.cast!(a.start_date), Dates.cast!(a.end_date)} do
        {%NaiveDateTime{} = start, %NaiveDateTime{} = finish} ->
          {start, finish}

        _ ->
          Timeline.fit(Store.date_range(a.store), level.scales,
            week_start: a.week_start,
            today: today
          )
      end

    Timeline.new(
      scales: level.scales,
      start_date: start,
      end_date: finish,
      column_width: level.column_width,
      week_start: a.week_start
    )
  end

  defp decorate_bar(bar, a) do
    task = bar.task
    editable = not a.readonly and not task.readonly
    summary = task.type == :project and Store.has_children?(a.store, task.id)

    Map.merge(bar, %{
      selected: MapSet.member?(a.selection, bar.key),
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
      slack_width: slack_width(task, a)
    })
  end

  # Deadlines are inclusive days: a task due on the 10th may end on the 10th.
  defp deadline(%Task{deadline: %NaiveDateTime{} = date} = task, bar, a) do
    due = TaskForm.parse_end(date, a.duration_unit)

    %{
      x: Timeline.x(a.timeline, due),
      y: bar.y,
      height: bar.height,
      overdue: NaiveDateTime.compare(task.end_date, due) == :gt
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
    a.grid_width_override || a.grid_width || Columns.total_width(columns)
  end

  defp root_style(a, columns, grid_width, bar_height, level) do
    column_vars =
      columns
      |> Enum.with_index()
      |> Enum.reject(fn {col, _} -> col.tree end)
      |> Enum.map_join(fn {col, index} -> "--gx-col-#{index}: #{col.width}px; " end)

    "--gx-row-height: #{a.row_height}px; --gx-bar-height: #{bar_height}px; " <>
      "--gx-scale-row-height: #{a.scale_height}px; --gx-height: #{safe_css(a.height, "640px")}; " <>
      "--gx-grid-width: #{if a.show_grid, do: grid_width, else: 0}px; " <>
      "--gx-column-width: #{level.column_width}px; " <>
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
      class={["gx-root", @class]}
      style={@root_style}
      data-gx-theme={@theme}
      data-gx-snap={@snap_px}
      data-gx-readonly={to_string(@readonly)}
      data-gx-drag-create={to_string(@drag_create and not @readonly)}
      data-gx-reorder={
        to_string(
          @reorder and not @readonly and is_nil(@sort) and is_nil(@filter) and is_nil(@group_by)
        )
      }
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
      >
        {render_slot(@toolbar_actions)}
      </.toolbar>

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
            <.scale rows={@scale_rows} width={@chart_width} />
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
              <div :if={@rows == []} class="gx-empty">{@labels.no_tasks}</div>
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
    {:noreply, socket |> select_task(key, params["source"] == "bar") |> prepare()}
  end

  def handle_event("toggle", %{"key" => key}, socket) do
    socket =
      case Enum.find(socket.assigns.rows, &(&1.key == key and &1.has_children)) do
        nil -> socket
        row -> socket |> toggle_row(row) |> assign(quick_info_key: nil)
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
          select_task(socket, key, false)
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
        with true <- a.reorder and is_nil(a.sort) and is_nil(a.filter),
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

  def handle_event("gx:resize", %{"column" => column, "width" => width}, socket) do
    a = socket.assigns

    socket =
      case {column, Interaction.number(width)} do
        {_, nil} ->
          socket

        {"__grid", width} ->
          assign(socket, grid_width_override: width |> round() |> max(120) |> min(2000))

        {field, width} ->
          case Enum.find(a.columns, &(to_string(&1.field) == field and not &1.tree)) do
            nil ->
              socket

            col ->
              width = width |> round() |> max(32) |> min(800)

              assign(socket,
                column_widths: Map.put(a.column_widths, field, width),
                grid_width_override: a.grid_width_value + width - col.width
              )
          end
      end

    {:reply, %{ok: true}, prepare(socket)}
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
        |> push_event("gantt_ex:scroll", %{
          id: socket.assigns.id,
          y: row.index * socket.assigns.row_height,
          height: socket.assigns.row_height
        })
        |> prepare()
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

  defp expand_or_descend(socket, row, index) do
    cond do
      row.has_children and not row.open -> prepare(toggle_row(socket, row))
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
