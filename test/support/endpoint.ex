defmodule GanttEx.Test.Endpoint do
  @moduledoc false
  use Phoenix.Endpoint, otp_app: :gantt_ex

  socket "/live", Phoenix.LiveView.Socket
end
