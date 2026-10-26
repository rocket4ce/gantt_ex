defmodule GanttEx.I18n do
  @moduledoc """
  Translations and localized date formatting.

  All user-facing strings of the chart (column titles, lightbox labels,
  toolbar tooltips, month and day names...) live in the `GanttEx.Gettext`
  backend. Date patterns are translatable too, so each language can choose
  its own order and separators.

  ## Supported locales

  #{Enum.map_join(~w(en es fr it de pt pt_BR ja), ", ", &"`#{&1}`")}

  Locale names are normalized, so `"pt-BR"`, `"es-CL"` or `:fr` work too.

  ## Date patterns

  Patterns use `Calendar.strftime/3` directives with localized month and day
  names, plus `%V` for the ISO week number. Named patterns (atoms) resolve to
  the translated pattern of the locale:

      iex> GanttEx.I18n.format(~N[2025-03-07 00:00:00], :month_year, "es")
      "marzo 2025"

      iex> GanttEx.I18n.format(~N[2025-03-07 00:00:00], :date, "de")
      "07.03.2025"

      iex> GanttEx.I18n.format(~N[2025-03-07 00:00:00], "%a %-d · W%V", "fr")
      "ven. 7 · W10"

      iex> GanttEx.I18n.format(~N[2025-03-07 00:00:00], :month_year, "ja")
      "2025年3月"
  """

  use Gettext, backend: GanttEx.Gettext

  @locales ~w(en es fr it de pt pt_BR ja)
  @default_locale "en"

  @typedoc "A locale name such as `\"es\"` or `\"pt_BR\"`."
  @type locale :: String.t()

  @typedoc "A date pattern: a named pattern, a strftime string or a function."
  @type pattern ::
          atom()
          | String.t()
          | (NaiveDateTime.t() -> String.t())
          | (NaiveDateTime.t(), locale() -> String.t())

  @doc """
  Returns the bundled locales.

      iex> GanttEx.I18n.locales()
      ["en", "es", "fr", "it", "de", "pt", "pt_BR", "ja"]
  """
  @spec locales() :: [locale()]
  def locales, do: @locales

  @doc """
  Normalizes a locale name, falling back to the language and then to `"en"`.

      iex> GanttEx.I18n.normalize_locale("pt-br")
      "pt_BR"

      iex> GanttEx.I18n.normalize_locale("es-CL")
      "es"

      iex> GanttEx.I18n.normalize_locale(:ja)
      "ja"

      iex> GanttEx.I18n.normalize_locale("xx")
      "en"
  """
  @spec normalize_locale(term()) :: locale()
  def normalize_locale(nil), do: @default_locale
  def normalize_locale(locale) when is_atom(locale), do: normalize_locale(Atom.to_string(locale))

  def normalize_locale(locale) when is_binary(locale) do
    case locale |> String.replace("-", "_") |> String.split("_", parts: 2) do
      [lang, region] ->
        full = String.downcase(lang) <> "_" <> String.upcase(region)
        if full in @locales, do: full, else: normalize_locale(lang)

      [lang] ->
        lang = String.downcase(lang)
        if lang in @locales, do: lang, else: @default_locale
    end
  end

  def normalize_locale(_locale), do: @default_locale

  @doc """
  Runs `fun` with the GanttEx backend set to `locale`.
  """
  @spec with_locale(locale(), (-> result)) :: result when result: var
  def with_locale(locale, fun),
    do: Gettext.with_locale(GanttEx.Gettext, normalize_locale(locale), fun)

  @doc """
  Returns every UI label of the chart, translated.

      iex> GanttEx.I18n.labels("es").save
      "Guardar"

      iex> GanttEx.I18n.labels("en").task_name
      "Task name"
  """
  @spec labels(locale()) :: %{atom() => String.t()}
  def labels(locale) do
    with_locale(locale, fn ->
      %{
        # grid
        task_name: gettext("Task name"),
        start_time: gettext("Start time"),
        end_time: gettext("End time"),
        duration: gettext("Duration"),
        progress: gettext("Progress"),
        type: gettext("Type"),
        wbs: gettext("WBS"),
        add_task: gettext("Add task"),
        add_subtask: gettext("Add subtask"),
        expand: gettext("Expand"),
        collapse: gettext("Collapse"),
        no_tasks: gettext("No tasks yet"),
        # lightbox
        new_task: gettext("New task"),
        edit_task: gettext("Edit task"),
        description: gettext("Description"),
        time_period: gettext("Time period"),
        start: gettext("Start"),
        end: gettext("End"),
        parent: gettext("Parent"),
        no_parent: gettext("None (top level)"),
        save: gettext("Save"),
        cancel: gettext("Cancel"),
        delete: gettext("Delete"),
        close: gettext("Close"),
        edit: gettext("Edit"),
        # task types
        task: gettext("Task"),
        project: gettext("Project"),
        milestone: gettext("Milestone"),
        # links
        link: gettext("Dependency"),
        lag: gettext("Lag"),
        finish_to_start: gettext("Finish to start"),
        start_to_start: gettext("Start to start"),
        finish_to_finish: gettext("Finish to finish"),
        start_to_finish: gettext("Start to finish"),
        link_rejected: gettext("This dependency is not allowed"),
        # confirmation
        confirm_delete_task: gettext("Are you sure you want to delete this task?"),
        confirm_delete_subtasks: gettext("Its subtasks will be deleted too."),
        confirm_delete_link: gettext("Are you sure you want to delete this dependency?"),
        yes: gettext("Yes"),
        no: gettext("No"),
        # toolbar
        undo: gettext("Undo"),
        redo: gettext("Redo"),
        zoom: gettext("Zoom"),
        zoom_in: gettext("Zoom in"),
        zoom_out: gettext("Zoom out"),
        today: gettext("Today"),
        expand_all: gettext("Expand all"),
        collapse_all: gettext("Collapse all"),
        fullscreen: gettext("Fullscreen"),
        export: gettext("Export"),
        print: gettext("Print"),
        # zoom levels
        hour: gettext("Hours"),
        day: gettext("Days"),
        week: gettext("Weeks"),
        month: gettext("Months"),
        quarter: gettext("Quarters"),
        year: gettext("Years"),
        # validation
        required: gettext("can't be blank"),
        invalid_date: gettext("is not a valid date"),
        invalid_number: gettext("must be a whole number"),
        invalid_progress: gettext("must be between 0 and 100"),
        end_before_start: gettext("must be after the start date"),
        # accessibility
        chart: gettext("Gantt chart"),
        task_list: gettext("Task list"),
        timeline: gettext("Timeline"),
        resize: gettext("Resize")
      }
    end)
  end

  @doc """
  Returns a translated duration such as `"3 days"`.

      iex> GanttEx.I18n.duration(3, :day, "es")
      "3 días"

      iex> GanttEx.I18n.duration(1, :hour, "en")
      "1 hour"
  """
  @spec duration(integer(), GanttEx.Dates.unit(), locale()) :: String.t()
  def duration(count, unit, locale) do
    with_locale(locale, fn -> unit_text(unit, count) end)
  end

  defp unit_text(:minute, n), do: ngettext("%{count} minute", "%{count} minutes", n)
  defp unit_text(:hour, n), do: ngettext("%{count} hour", "%{count} hours", n)
  defp unit_text(:day, n), do: ngettext("%{count} day", "%{count} days", n)
  defp unit_text(:week, n), do: ngettext("%{count} week", "%{count} weeks", n)
  defp unit_text(:month, n), do: ngettext("%{count} month", "%{count} months", n)
  defp unit_text(:quarter, n), do: ngettext("%{count} quarter", "%{count} quarters", n)
  defp unit_text(:year, n), do: ngettext("%{count} year", "%{count} years", n)

  @doc """
  Returns the translated pattern for a named date format.

  Available names: `:date`, `:datetime`, `:time`, `:day`, `:weekday_day`,
  `:day_month`, `:weekday_date`, `:month_year`, `:month`, `:year` and
  `:quarter`.

      iex> GanttEx.I18n.pattern(:date, "en")
      "%m/%d/%Y"

      iex> GanttEx.I18n.pattern(:quarter, "es")
      "T%q"
  """
  @spec pattern(atom(), locale()) :: String.t()
  def pattern(name, locale), do: with_locale(locale, fn -> pattern_text(name) end)

  defp pattern_text(:date), do: pgettext("date format", "%m/%d/%Y")
  defp pattern_text(:datetime), do: pgettext("date format", "%m/%d/%Y %H:%M")
  defp pattern_text(:time), do: pgettext("date format", "%H:%M")
  defp pattern_text(:day), do: pgettext("date format", "%-d")
  defp pattern_text(:weekday_day), do: pgettext("date format", "%a %-d")
  defp pattern_text(:day_month), do: pgettext("date format", "%b %-d")
  defp pattern_text(:weekday_date), do: pgettext("date format", "%A, %B %-d")
  defp pattern_text(:month_year), do: pgettext("date format", "%B %Y")
  defp pattern_text(:month), do: pgettext("date format", "%b")
  defp pattern_text(:year), do: pgettext("date format", "%Y")
  defp pattern_text(:quarter), do: pgettext("date format", "Q%q")

  defp pattern_text(name) do
    raise ArgumentError, "unknown date pattern #{inspect(name)}"
  end

  @doc """
  Returns localized month and weekday names as tuples.

      iex> GanttEx.I18n.calendar_names("it").months |> elem(0)
      "gennaio"

      iex> GanttEx.I18n.calendar_names("de").weekdays_short |> elem(6)
      "So"
  """
  @spec calendar_names(locale()) :: %{
          months: tuple(),
          months_short: tuple(),
          weekdays: tuple(),
          weekdays_short: tuple()
        }
  def calendar_names(locale) do
    with_locale(locale, fn ->
      %{
        months:
          {pgettext("month", "January"), pgettext("month", "February"),
           pgettext("month", "March"), pgettext("month", "April"), pgettext("month", "May"),
           pgettext("month", "June"), pgettext("month", "July"), pgettext("month", "August"),
           pgettext("month", "September"), pgettext("month", "October"),
           pgettext("month", "November"), pgettext("month", "December")},
        months_short:
          {pgettext("month short", "Jan"), pgettext("month short", "Feb"),
           pgettext("month short", "Mar"), pgettext("month short", "Apr"),
           pgettext("month short", "May"), pgettext("month short", "Jun"),
           pgettext("month short", "Jul"), pgettext("month short", "Aug"),
           pgettext("month short", "Sep"), pgettext("month short", "Oct"),
           pgettext("month short", "Nov"), pgettext("month short", "Dec")},
        weekdays:
          {pgettext("weekday", "Monday"), pgettext("weekday", "Tuesday"),
           pgettext("weekday", "Wednesday"), pgettext("weekday", "Thursday"),
           pgettext("weekday", "Friday"), pgettext("weekday", "Saturday"),
           pgettext("weekday", "Sunday")},
        weekdays_short:
          {pgettext("weekday short", "Mon"), pgettext("weekday short", "Tue"),
           pgettext("weekday short", "Wed"), pgettext("weekday short", "Thu"),
           pgettext("weekday short", "Fri"), pgettext("weekday short", "Sat"),
           pgettext("weekday short", "Sun")}
      }
    end)
  end

  @doc """
  Formats a datetime with a pattern (see the module docs).
  """
  @spec format(NaiveDateTime.t() | Date.t() | nil, pattern(), locale()) :: String.t()
  def format(datetime, pattern, locale), do: formatter(locale).(datetime, pattern)

  @doc """
  Returns a 2-arity formatting function bound to `locale`.

  Translations are looked up once, which makes it the efficient choice to
  format many dates (for example all the cells of a time scale).

      iex> format = GanttEx.I18n.formatter("pt_BR")
      iex> format.(~N[2025-12-01 00:00:00], :month_year)
      "dezembro 2025"
  """
  @spec formatter(locale()) :: (NaiveDateTime.t() | Date.t() | nil, pattern() -> String.t())
  def formatter(locale) do
    locale = normalize_locale(locale)
    names = calendar_names(locale)
    patterns = Map.new(pattern_names(), &{&1, pattern(&1, locale)})

    strftime_opts = [
      month_names: &elem(names.months, &1 - 1),
      abbreviated_month_names: &elem(names.months_short, &1 - 1),
      day_of_week_names: &elem(names.weekdays, &1 - 1),
      abbreviated_day_of_week_names: &elem(names.weekdays_short, &1 - 1)
    ]

    fn
      nil, _pattern ->
        ""

      datetime, fun when is_function(fun, 1) ->
        fun.(datetime)

      datetime, fun when is_function(fun, 2) ->
        fun.(datetime, locale)

      datetime, name when is_atom(name) ->
        pattern = Map.get_lazy(patterns, name, fn -> pattern(name, locale) end)
        Calendar.strftime(datetime, expand_week(pattern, datetime), strftime_opts)

      datetime, pattern when is_binary(pattern) ->
        Calendar.strftime(datetime, expand_week(pattern, datetime), strftime_opts)
    end
  end

  defp pattern_names,
    do:
      ~w(date datetime time day weekday_day day_month weekday_date month_year month year quarter)a

  defp expand_week(pattern, datetime) do
    if String.contains?(pattern, "V") do
      week = GanttEx.Dates.iso_week(datetime)

      pattern
      |> String.replace("%-V", Integer.to_string(week))
      |> String.replace("%V", week |> Integer.to_string() |> String.pad_leading(2, "0"))
    else
      pattern
    end
  end
end
