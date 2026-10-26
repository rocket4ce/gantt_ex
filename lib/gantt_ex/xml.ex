defmodule GanttEx.XML do
  @moduledoc false
  # A tiny, safe XML reader for imports, built on the OTP SAX parser:
  #
  #   * element and attribute names stay strings (xmerl's DOM mode creates
  #     atoms, which untrusted documents could use to exhaust the atom table)
  #   * ENTITY declarations and external DTDs are rejected
  #
  # Elements are maps: %{name: "task", attrs: %{"id" => "1"}, children: [...], text: "..."}

  @type element :: %{
          name: String.t(),
          attrs: %{String.t() => String.t()},
          children: [element()],
          text: String.t()
        }

  @spec parse(String.t()) :: {:ok, element()} | {:error, :invalid_xml}
  def parse(xml) when is_binary(xml) do
    opts = [
      :disallow_entities,
      :skip_external_dtd,
      external_entities: :none,
      event_fun: &event/3,
      event_state: []
    ]

    case :xmerl_sax_parser.stream(xml, opts) do
      {:ok, [root], _rest} -> {:ok, root}
      _error -> {:error, :invalid_xml}
    end
  catch
    _kind, _reason -> {:error, :invalid_xml}
  end

  # The state is a stack of open elements; the finished root is left alone on it.
  defp event({:startElement, _uri, local, _qname, attrs}, _location, stack) do
    attrs =
      Map.new(attrs, fn {_uri, _prefix, name, value} -> {to_string(name), to_string(value)} end)

    [%{name: to_string(local), attrs: attrs, children: [], text: []} | stack]
  end

  defp event({:characters, chars}, _location, [element | stack]) do
    [%{element | text: [element.text, to_string(chars)]} | stack]
  end

  defp event({:endElement, _uri, _local, _qname}, _location, [element | stack]) do
    element = %{
      element
      | children: Enum.reverse(element.children),
        text: IO.iodata_to_binary(element.text)
    }

    case stack do
      [parent | rest] -> [%{parent | children: [element | parent.children]} | rest]
      [] -> [element]
    end
  end

  defp event(_event, _location, stack), do: stack

  @doc "Returns the children named `name`."
  @spec children(element(), String.t()) :: [element()]
  def children(%{children: children}, name), do: Enum.filter(children, &(&1.name == name))

  @doc "Returns the trimmed text of the first child named `name`, or `nil`."
  @spec child_text(element(), String.t()) :: String.t() | nil
  def child_text(element, name) do
    case children(element, name) do
      [child | _] -> String.trim(child.text)
      [] -> nil
    end
  end
end
