defmodule GanttEx.DoctestTest do
  use ExUnit.Case, async: true

  doctest GanttEx
  doctest GanttEx.Dates
  doctest GanttEx.Calendar
  doctest GanttEx.Marker
  doctest GanttEx.History
  doctest GanttEx.Dependency
  doctest GanttEx.Scheduler
  doctest GanttEx.CriticalPath
  doctest GanttEx.Resource
  doctest GanttEx.ResourceLoad
  doctest GanttEx.Task
  doctest GanttEx.Link
  doctest GanttEx.Store
  doctest GanttEx.Scale
  doctest GanttEx.Zoom
  doctest GanttEx.Timeline
  doctest GanttEx.LinkPath
  doctest GanttEx.Layout
  doctest GanttEx.Event
  doctest GanttEx.TaskForm
  doctest GanttEx.LinkForm
  doctest GanttEx.Export
  doctest GanttEx.Import
  doctest GanttEx.I18n
  doctest GanttEx.Live.Components
  doctest GanttEx.Live.Columns
  doctest GanttEx.Live.Interaction
  doctest GanttEx.Live.Icons
end
