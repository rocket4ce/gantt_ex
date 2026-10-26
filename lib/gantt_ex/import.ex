defmodule GanttEx.Import do
  @moduledoc """
  Reads project data from other tools.

  | Format                         | Function             |
  | ------------------------------ | -------------------- |
  | DHTMLX JSON                    | `from_json/1`        |
  | DHTMLX XML                     | `from_xml/1`         |
  | MS Project XML (MSPDI)         | `from_ms_project/1`  |

  Every function returns `{:ok, %{tasks: [map], links: [map]}}`, ready for
  `GanttEx.Store.new/3` or for the `tasks` and `links` attributes of
  `GanttEx.Live.Gantt`.

  XML is parsed with the OTP SAX parser without creating atoms, and
  documents declaring entities or external DTDs are rejected, so untrusted
  files can be imported safely.

      iex> json = ~s({"data": [{"id": 1, "text": "A", "start_date": "06-01-2025 00:00", "duration": 2, "parent": 0}], "links": [{"id": 1, "source": 1, "target": 1, "type": "0"}]})
      iex> {:ok, %{tasks: [task], links: [link]}} = GanttEx.Import.from_json(json)
      iex> {task["text"], link["type"]}
      {"A", "0"}
      iex> {:ok, store} = GanttEx.Store.new([task])
      iex> GanttEx.Store.get_task(store, 1).end_date
      ~N[2025-01-08 00:00:00]

      iex> GanttEx.Import.from_json("[1, 2]")
      {:error, :invalid_format}
  """

  alias GanttEx.XML

  @typedoc "Imported data."
  @type data :: %{tasks: [map()], links: [map()]}

  @doc """
  Parses DHTMLX JSON (a string or an already decoded map). Tasks may be under
  the `"data"` or `"tasks"` key.
  """
  @spec from_json(String.t() | map()) :: {:ok, data()} | {:error, :invalid_json | :invalid_format}
  def from_json(json) when is_binary(json) do
    case JSON.decode(json) do
      {:ok, decoded} -> from_json(decoded)
      {:error, _reason} -> {:error, :invalid_json}
    end
  end

  def from_json(%{} = decoded) do
    tasks = Map.get(decoded, "data") || Map.get(decoded, "tasks") || []
    links = Map.get(decoded, "links") || []

    if is_list(tasks) and is_list(links) and Enum.all?(tasks ++ links, &is_map/1),
      do: {:ok, %{tasks: tasks, links: links}},
      else: {:error, :invalid_format}
  end

  def from_json(_decoded), do: {:error, :invalid_format}

  @doc """
  Parses the DHTMLX Gantt XML format: `<task>` elements whose attributes are
  the task fields (the element text is the task name) and a
  `<coll_options for="links">` element with `<item>` links.

      iex> xml = \"""
      ...> <data>
      ...>   <task id="1" start_date="06-01-2025 00:00" duration="3" progress="0.5"><![CDATA[Design & UX]]></task>
      ...>   <task id="2" parent="1" start_date="09-01-2025 00:00" duration="2">Build</task>
      ...>   <coll_options for="links"><item id="1" source="1" target="2" type="0"/></coll_options>
      ...> </data>
      ...> \"""
      iex> {:ok, %{tasks: [design, build], links: [link]}} = GanttEx.Import.from_xml(xml)
      iex> {design["text"], build["parent"], link["target"]}
      {"Design & UX", "1", "2"}
      iex> GanttEx.Import.from_xml("<data><task>")
      {:error, :invalid_xml}
  """
  @spec from_xml(String.t()) :: {:ok, data()} | {:error, :invalid_xml}
  def from_xml(xml) do
    with {:ok, root} <- XML.parse(xml) do
      tasks =
        for task <- XML.children(root, "task") do
          Map.put_new(task.attrs, "text", String.trim(task.text))
        end

      links =
        for options <- XML.children(root, "coll_options"),
            options.attrs["for"] == "links",
            item <- XML.children(options, "item"),
            do: item.attrs

      {:ok, %{tasks: tasks, links: links}}
    end
  end

  @doc """
  Parses Microsoft Project XML (MSPDI), as written by MS Project,
  ProjectLibre, GanttProject or `GanttEx.Export.to_ms_project/2`.

  The tree is rebuilt from the outline levels, summary tasks become projects
  and lags are converted from MS Project units assuming 8-hour days.

      iex> store = GanttEx.Store.new!(
      ...>   [
      ...>     %{id: 1, text: "Phase", type: :project},
      ...>     %{id: 2, text: "Work", parent: 1, start_date: ~D[2025-01-06], duration: 2, progress: 0.5},
      ...>     %{id: 3, text: "Done", parent: 1, start_date: ~D[2025-01-08], type: :milestone}
      ...>   ],
      ...>   [%{id: 1, source: 2, target: 3, type: :start_to_start, lag: 1}]
      ...> )
      iex> {:ok, %{tasks: tasks, links: [link]}} = store |> GanttEx.Export.to_ms_project() |> GanttEx.Import.from_ms_project()
      iex> Enum.map(tasks, &{&1["text"], &1["type"], &1["parent"]})
      [{"Phase", "project", nil}, {"Work", "task", 1}, {"Done", "milestone", 1}]
      iex> {link["source"], link["target"], link["type"], link["lag"]}
      {2, 3, "start_to_start", 1}
  """
  @spec from_ms_project(String.t()) :: {:ok, data()} | {:error, :invalid_xml | :invalid_format}
  def from_ms_project(xml) do
    with {:ok, %{name: "Project"} = root} <- XML.parse(xml) do
      tasks =
        root
        |> XML.children("Tasks")
        |> Enum.flat_map(&XML.children(&1, "Task"))
        |> Enum.reject(
          &(XML.child_text(&1, "UID") in [nil, "0"] or XML.child_text(&1, "IsNull") == "1")
        )

      {tasks, _stack} = Enum.map_reduce(tasks, [], &ms_task/2)

      links =
        tasks
        |> Enum.flat_map(fn {task, element} ->
          for link <- XML.children(element, "PredecessorLink") do
            %{
              "source" => integer(XML.child_text(link, "PredecessorUID")),
              "target" => task["id"],
              "type" => ms_link_type(XML.child_text(link, "Type")),
              "lag" => round((integer(XML.child_text(link, "LinkLag")) || 0) / 4800)
            }
          end
        end)
        |> Enum.with_index(1)
        |> Enum.map(fn {link, id} -> Map.put(link, "id", id) end)

      {:ok, %{tasks: Enum.map(tasks, &elem(&1, 0)), links: links}}
    else
      {:ok, _other_root} -> {:error, :invalid_format}
      error -> error
    end
  end

  # Rebuilds the hierarchy from outline levels with a stack of {level, uid}.
  defp ms_task(element, stack) do
    uid = integer(XML.child_text(element, "UID"))
    level = integer(XML.child_text(element, "OutlineLevel")) || 1
    stack = Enum.drop_while(stack, fn {open_level, _uid} -> open_level >= level end)

    type =
      cond do
        XML.child_text(element, "Milestone") == "1" -> "milestone"
        XML.child_text(element, "Summary") == "1" -> "project"
        true -> "task"
      end

    task = %{
      "id" => uid,
      "text" => XML.child_text(element, "Name") || "",
      "type" => type,
      "start_date" => XML.child_text(element, "Start"),
      "end_date" => XML.child_text(element, "Finish"),
      "progress" => (integer(XML.child_text(element, "PercentComplete")) || 0) / 100,
      "parent" =>
        case stack do
          [{_level, parent} | _] -> parent
          [] -> nil
        end
    }

    {{task, element}, [{level, uid} | stack]}
  end

  # MSPDI link types: 0 = FF, 1 = FS, 2 = SF, 3 = SS
  defp ms_link_type("0"), do: "finish_to_finish"
  defp ms_link_type("2"), do: "start_to_finish"
  defp ms_link_type("3"), do: "start_to_start"
  defp ms_link_type(_type), do: "finish_to_start"

  defp integer(nil), do: nil

  defp integer(text) do
    case Integer.parse(text) do
      {integer, _rest} -> integer
      :error -> nil
    end
  end
end
