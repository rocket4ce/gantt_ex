defmodule GanttEx do
  @moduledoc """
  Interactive Gantt charts for Phoenix LiveView.

  GanttEx is inspired by [DHTMLX Gantt](https://github.com/DHTMLX/gantt) and
  brings its features to LiveView with server-side state and a single small
  JavaScript hook:

    * `GanttEx.Live.Gantt` - the LiveComponent to drop in your templates
    * `GanttEx.Event` - the messages your LiveView receives to persist changes
    * `GanttEx.Task` and `GanttEx.Link` - the data model
    * `GanttEx.Store` - an immutable tree of tasks with scheduling rules
    * `GanttEx.Filter` - search and filters
    * `GanttEx.Timeline`, `GanttEx.Scale`, `GanttEx.Zoom` and `GanttEx.Layout` - time to pixels
    * `GanttEx.Export` and `GanttEx.Import` - JSON, CSV, iCalendar and MS Project
    * `GanttEx.I18n` - translations for 8 languages

  The data model and the layout are plain Elixir: they can be used (and
  tested) without LiveView.

      iex> store = GanttEx.new!([%{id: 1, text: "Kickoff", start_date: ~D[2025-01-06], duration: 2}])
      iex> GanttEx.Store.get_task(store, 1).end_date
      ~N[2025-01-08 00:00:00]

  See the [Getting started](getting_started.html) guide.
  """

  @doc """
  Builds a `GanttEx.Store`. Shortcut for `GanttEx.Store.new/3`.
  """
  defdelegate new(tasks \\ [], links \\ [], opts \\ []), to: GanttEx.Store

  @doc """
  Builds a `GanttEx.Store` or raises. Shortcut for `GanttEx.Store.new!/3`.
  """
  defdelegate new!(tasks \\ [], links \\ [], opts \\ []), to: GanttEx.Store

  @doc """
  Returns the bundled locales. Shortcut for `GanttEx.I18n.locales/0`.

      iex> "ja" in GanttEx.locales()
      true
  """
  defdelegate locales, to: GanttEx.I18n
end
