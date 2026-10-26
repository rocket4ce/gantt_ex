defmodule GanttEx.ColocatedCSS do
  @moduledoc """
  A global `Phoenix.LiveView.ColocatedCSS` implementation used to ship the
  GanttEx stylesheet (see `GanttEx.Live.Styles`).

  Styles are extracted as-is at compile time into
  `phoenix-colocated/gantt_ex/colocated.css`, which you import from your
  `app.css`:

      @import "phoenix-colocated/gantt_ex/colocated.css";
  """
  use Phoenix.LiveView.ColocatedCSS

  @impl true
  def transform("style", _attrs, css, _meta), do: {:ok, css, []}
end
