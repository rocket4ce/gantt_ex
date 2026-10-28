defmodule LiveGanttWeb.GanttLive do
  @moduledoc """
  Demo of `GanttEx.Live.Gantt` backed by Postgres.

  The chart applies user changes right away and reports them as
  `{GanttEx, %GanttEx.Event{}}` messages; this LiveView persists each one with
  `LiveGantt.Planning.apply_event/1` and re-renders the chart with fresh data.
  """
  use LiveGanttWeb, :live_view

  alias GanttEx.Event
  alias LiveGantt.Planning

  @locales [
    {"English", "en"},
    {"Español", "es"},
    {"Français", "fr"},
    {"Italiano", "it"},
    {"Deutsch", "de"},
    {"Português", "pt"},
    {"Português (Brasil)", "pt_BR"},
    {"日本語", "ja"}
  ]

  # The chart translates itself; these are the labels of the demo's own column.
  @owner_labels %{
    "en" => "Owner",
    "es" => "Responsable",
    "fr" => "Responsable",
    "it" => "Responsabile",
    "de" => "Verantwortlich",
    "pt" => "Responsável",
    "pt_BR" => "Responsável",
    "ja" => "担当者"
  }

  # Advanced features the demo can switch on and off.
  @toggles [
    {"work_time", "Working days"},
    {"auto_scheduling", "Auto-schedule"},
    {"baselines", "Baselines"},
    {"group", "Group by owner"},
    {"workload", "Workload"},
    {"readonly", "Read only"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    params = %{"locale" => "en", "baselines" => "true"}

    {:ok,
     socket
     |> assign(page_title: "Gantt", locales: @locales, toggles: @toggles, activity_count: 0)
     # What the user chose in the chart; a real app would store them as preferences.
     |> assign(filter_values: nil, column_layout: nil)
     |> assign(calendar_dates())
     |> apply_settings(params)
     |> stream(:activity, [])
     |> load_data()}
  end

  # The sample project starts last week (see priv/repo/seeds.exs).
  defp calendar_dates do
    today = Date.utc_today()
    monday = Date.add(today, 1 - Date.day_of_week(today) - 7)

    %{
      holiday: Date.add(monday, 16),
      markers: [
        %{id: "freeze", date: Date.add(monday, 29), text: "Release freeze", color: "#8b5cf6"}
      ]
    }
  end

  defp apply_settings(socket, params) do
    locale =
      if params["locale"] in Enum.map(@locales, &elem(&1, 1)), do: params["locale"], else: "en"

    enabled =
      Map.new(@toggles, fn {key, _label} ->
        {String.to_existing_atom(key), params[key] == "true"}
      end)

    assign(socket,
      locale: locale,
      options: enabled,
      settings: to_form(params, as: :settings)
    )
  end

  @impl true
  def handle_event("settings", %{"settings" => params}, socket) do
    {:noreply, apply_settings(socket, params)}
  end

  @impl true
  def handle_info({GanttEx, %Event{type: :task_selected}}, socket), do: {:noreply, socket}

  def handle_info({GanttEx, %Event{type: :filters_changed, filters: filters}}, socket),
    do: {:noreply, assign(socket, filter_values: filters)}

  def handle_info({GanttEx, %Event{type: :columns_changed, columns: layout}}, socket),
    do: {:noreply, assign(socket, column_layout: layout)}

  def handle_info({GanttEx, %Event{type: :task_action, action: :detail, task: task}}, socket) do
    {:noreply, socket |> log_activity(%Event{type: :task_action, task: task})}
  end

  def handle_info({GanttEx, %Event{} = event}, socket) do
    case Planning.apply_event(event) do
      :ok ->
        {:noreply, socket |> load_data() |> log_activity(event)}

      {:error, _reason} ->
        # The data did not change, so ask the chart to drop its local change.
        GanttEx.Live.Gantt.reload("project-gantt")
        {:noreply, socket |> load_data() |> put_flash(:error, "The change could not be saved.")}
    end
  end

  # Owners double as resources, to show the workload panel and grouping.
  defp load_data(socket) do
    records = Planning.list_tasks()
    tasks = Enum.map(records, &Map.put(Map.from_struct(&1), :resources, List.wrap(&1.owner)))

    resources =
      records
      |> Enum.map(& &1.owner)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.map(&%{id: &1, text: &1, capacity: 8})

    assign(socket,
      tasks: tasks,
      links: Planning.list_links(),
      resources: resources,
      stats: stats(records)
    )
  end

  # The owners as a filter of the chart, with an option for unassigned tasks.
  defp owner_filter(resources, label) do
    %{
      id: :owner,
      label: label,
      options: [{"—", nil} | Enum.map(resources, &{&1.text, &1.id})]
    }
  end

  defp stats(tasks) do
    work = Enum.filter(tasks, &(&1.type == :task))
    total = work |> Enum.map(& &1.duration) |> Enum.sum()
    done = work |> Enum.map(&(&1.duration * &1.progress)) |> Enum.sum()

    %{
      tasks: length(work),
      milestones: Enum.count(tasks, &(&1.type == :milestone)),
      projects: Enum.count(tasks, &(&1.type == :project)),
      progress: if(total > 0, do: round(done / total * 100), else: 0)
    }
  end

  defp log_activity(socket, event) do
    count = socket.assigns.activity_count + 1

    entry = %{
      id: "activity-#{count}",
      type: event.type,
      subject: subject(event),
      fields: event.changes && event.changes |> Map.keys() |> Enum.map_join(", ", &to_string/1),
      at: Time.utc_now() |> Time.truncate(:second)
    }

    socket
    |> assign(activity_count: count)
    |> stream_insert(:activity, entry, at: 0, limit: 8)
  end

  defp subject(%Event{task: %GanttEx.Task{text: text}}), do: text

  defp subject(%Event{link: %GanttEx.Link{} = link}) do
    "#{link.type |> to_string() |> String.replace("_", " ")} · lag #{link.lag}"
  end

  defp activity_icon(:task_action), do: "hero-arrow-top-right-on-square-micro"
  defp activity_icon(type) when type in [:task_created, :link_created], do: "hero-plus-micro"
  defp activity_icon(type) when type in [:task_deleted, :link_deleted], do: "hero-trash-micro"
  defp activity_icon(:task_moved), do: "hero-arrows-up-down-micro"
  defp activity_icon(_type), do: "hero-pencil-micro"

  defp activity_tone(type) when type in [:task_created, :link_created],
    do: "bg-emerald-500/10 text-emerald-600 dark:text-emerald-400"

  defp activity_tone(type) when type in [:task_deleted, :link_deleted],
    do: "bg-rose-500/10 text-rose-600 dark:text-rose-400"

  defp activity_tone(_type), do: "bg-indigo-500/10 text-indigo-600 dark:text-indigo-400"

  defp initials(nil), do: "?"

  defp initials(name) do
    name
    |> String.split()
    |> Enum.map_join(&String.first/1)
    |> String.slice(0, 2)
    |> String.upcase()
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :owner_label, Map.fetch!(@owner_labels, assigns.locale))

    ~H"""
    <Layouts.app flash={@flash}>
      <section class="flex flex-wrap items-end justify-between gap-6">
        <div class="space-y-1.5">
          <p class="text-xs font-semibold uppercase tracking-[0.18em] text-indigo-500">
            Phoenix LiveView · GanttEx
          </p>
          <h1 class="text-2xl font-semibold tracking-tight sm:text-3xl">Website relaunch</h1>
          <p class="max-w-xl text-sm text-base-content/60">
            Drag bars to reschedule, pull the edges to resize, draw dependencies from the
            round handles and double-click a task to edit it. Every change is saved to Postgres.
          </p>
        </div>

        <.form
          for={@settings}
          id="settings-form"
          phx-change="settings"
          class="flex max-w-3xl flex-wrap items-end justify-end gap-3 [&_.fieldset]:mb-0"
        >
          <div class="w-48">
            <.input field={@settings[:locale]} type="select" label="Language" options={@locales} />
          </div>
          <div class="flex w-full flex-wrap items-center justify-end gap-x-4 gap-y-1">
            <div :for={{key, label} <- @toggles} id={"toggle-#{key}"}>
              <.input field={@settings[key]} type="checkbox" label={label} />
            </div>
          </div>
        </.form>
      </section>

      <section id="stats" class="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <.stat id="stat-progress" label="Overall progress" value={"#{@stats.progress}%"}>
          <div class="mt-3 h-1.5 overflow-hidden rounded-full bg-base-300">
            <div
              class="h-full rounded-full bg-gradient-to-r from-indigo-500 to-violet-500 transition-[width] duration-500"
              style={"width: #{@stats.progress}%"}
            />
          </div>
        </.stat>
        <.stat id="stat-tasks" label="Tasks" value={@stats.tasks} icon="hero-squares-2x2-micro" />
        <.stat
          id="stat-milestones"
          label="Milestones"
          value={@stats.milestones}
          icon="hero-flag-micro"
        />
        <.stat id="stat-links" label="Dependencies" value={length(@links)} icon="hero-link-micro" />
      </section>

      <.live_component
        module={GanttEx.Live.Gantt}
        id="project-gantt"
        tasks={@tasks}
        links={@links}
        locale={@locale}
        readonly={@options.readonly}
        filters={[:search, :status, owner_filter(@resources, @owner_label), :type, :dates]}
        filter_values={@filter_values}
        column_layout={@column_layout}
        work_time={@options.work_time}
        calendar={[holidays: [@holiday]]}
        auto_scheduling={@options.auto_scheduling}
        baselines={@options.baselines}
        group_by={@options.group && :owner}
        resources={@resources}
        resource_panel={@options.workload}
        today_marker
        markers={@markers}
        lightbox_sections={[:text, :type, :parent, :time, :progress, :deadline]}
        drag_create
        height="64vh"
        export_filename="website-relaunch"
        class="shadow-sm"
      >
        <:column field={:actions} actions={[:drag, :rename, :block, :detail, :delete]} />
        <:column field={:wbs} width={56} hidden />
        <:column field={:text} tree width={240} />
        <:column :let={task} field={:owner} label={@owner_label} width={132} editor={:text}>
          <span :if={task.meta[:owner]} class="flex min-w-0 items-center gap-2">
            <span class="grid size-5 shrink-0 place-items-center rounded-full bg-indigo-500/15 text-[9px] font-bold text-indigo-600 dark:text-indigo-300">
              {initials(task.meta[:owner])}
            </span>
            <span class="truncate">{task.meta[:owner]}</span>
          </span>
        </:column>
        <:column field={:start_date} width={100} />
        <:column field={:end_date} width={100} hidden />
        <:column field={:duration} width={74} />
        <:column field={:progress} width={80} hidden />
        <:column field={:add} width={44} />
        <:lightbox_fields :let={form}>
          <div class="gx-field">
            <label for={form[:owner].id}>{@owner_label}</label>
            <input
              id={form[:owner].id}
              name={form[:owner].name}
              value={form[:owner].value}
              class="gx-input"
              autocomplete="off"
            />
          </div>
        </:lightbox_fields>
      </.live_component>

      <section class="grid gap-6 lg:grid-cols-3">
        <div class="rounded-2xl border border-base-300 bg-base-100 p-5 lg:col-span-2">
          <div class="mb-4 flex items-center justify-between">
            <h2 class="text-sm font-semibold">Activity</h2>
            <span class="text-xs text-base-content/50">Events received from the chart</span>
          </div>
          <ol id="activity" phx-update="stream" class="space-y-1">
            <li
              id="activity-empty"
              class="hidden py-6 text-center text-sm text-base-content/50 only:block"
            >
              Changes you make in the chart will show up here.
            </li>
            <li
              :for={{id, entry} <- @streams.activity}
              id={id}
              class="flex items-center gap-3 rounded-lg px-2 py-1.5 text-sm transition-colors hover:bg-base-200/60"
            >
              <span class={[
                "grid size-7 shrink-0 place-items-center rounded-lg",
                activity_tone(entry.type)
              ]}>
                <.icon name={activity_icon(entry.type)} class="size-3.5" />
              </span>
              <code class="shrink-0 rounded bg-base-200 px-1.5 py-0.5 text-xs">{entry.type}</code>
              <span class="truncate font-medium">{entry.subject}</span>
              <span :if={entry.fields} class="truncate text-xs text-base-content/50">
                {entry.fields}
              </span>
              <time class="ml-auto shrink-0 text-xs tabular-nums text-base-content/40">{entry.at}</time>
            </li>
          </ol>
        </div>

        <div class="rounded-2xl border border-base-300 bg-base-100 p-5">
          <h2 class="mb-3 text-sm font-semibold">Keyboard</h2>
          <dl class="grid grid-cols-[auto_1fr] items-center gap-x-4 gap-y-2 text-sm">
            <.shortcut keys={["↑", "↓"]}>Select task</.shortcut>
            <.shortcut keys={["←", "→"]}>Collapse / expand</.shortcut>
            <.shortcut keys={["Enter"]}>Edit task</.shortcut>
            <.shortcut keys={["Del"]}>Delete task</.shortcut>
            <.shortcut keys={["+", "−"]}>Zoom in / out</.shortcut>
            <.shortcut keys={["⌘/Ctrl", "Z"]}>Undo (add Shift to redo)</.shortcut>
            <.shortcut keys={["⌘/Ctrl", "click"]}>Select several tasks</.shortcut>
            <.shortcut keys={["Shift", "drag"]}>Pan the timeline</.shortcut>
          </dl>
        </div>
      </section>
    </Layouts.app>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :icon, :string, default: nil
  slot :inner_block

  defp stat(assigns) do
    ~H"""
    <div
      id={@id}
      class="rounded-2xl border border-base-300 bg-base-100 p-4 transition-shadow hover:shadow-md hover:shadow-base-300/40"
    >
      <div class="flex items-center justify-between text-xs font-medium text-base-content/60">
        {@label}
        <.icon :if={@icon} name={@icon} class="size-4 text-base-content/30" />
      </div>
      <p class="mt-1 text-2xl font-semibold tabular-nums tracking-tight">{@value}</p>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :keys, :list, required: true
  slot :inner_block, required: true

  defp shortcut(assigns) do
    ~H"""
    <dt class="flex gap-1">
      <kbd
        :for={key <- @keys}
        class="min-w-6 rounded-md border border-base-300 bg-base-200 px-1.5 py-0.5 text-center text-xs font-medium"
      >
        {key}
      </kbd>
    </dt>
    <dd class="text-base-content/70">{render_slot(@inner_block)}</dd>
    """
  end
end
