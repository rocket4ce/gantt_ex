defmodule LiveGanttWeb.PageController do
  use LiveGanttWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
