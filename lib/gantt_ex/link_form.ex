defmodule GanttEx.LinkForm do
  @moduledoc """
  Converts links to the params of the dependency editor and validates them.

      iex> link = GanttEx.Link.new!(id: 1, source: 1, target: 2, lag: 2)
      iex> GanttEx.LinkForm.params(link)
      %{"type" => "finish_to_start", "lag" => "2"}

      iex> GanttEx.LinkForm.cast(%{"type" => "start_to_start", "lag" => "-1"})
      {:ok, %{type: :start_to_start, lag: -1}}

      iex> GanttEx.LinkForm.cast(%{"type" => "start_to_start", "lag" => "soon"})
      {:error, [lag: :invalid_number]}
  """

  alias GanttEx.Link

  @doc "Returns the form params for a link."
  @spec params(Link.t()) :: %{String.t() => String.t()}
  def params(%Link{} = link) do
    %{"type" => Atom.to_string(link.type), "lag" => Integer.to_string(link.lag)}
  end

  @doc "Validates submitted params."
  @spec cast(map()) :: {:ok, map()} | {:error, keyword(atom())}
  def cast(params) do
    type = Link.cast_type(params["type"])
    lag = params |> Map.get("lag", "0") |> to_string() |> String.trim() |> Integer.parse()

    case {type, lag} do
      {{:ok, type}, {lag, ""}} -> {:ok, %{type: type, lag: lag}}
      {:error, _} -> {:error, [type: :required]}
      {_, _} -> {:error, [lag: :invalid_number]}
    end
  end
end
