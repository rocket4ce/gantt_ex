defmodule GanttEx.TaskForm do
  @moduledoc """
  Converts tasks to lightbox form params and validates submitted params.

  The lightbox uses plain HTML inputs, so dates travel as `"YYYY-MM-DD"`
  (or `"YYYY-MM-DDTHH:MM"` when the duration unit is smaller than a day) and
  progress as a percentage.

      iex> task = GanttEx.Task.new!(id: 1, text: "Design", start_date: ~D[2025-01-06], duration: 3, progress: 0.4)
      iex> GanttEx.TaskForm.params(task, :day)
      %{"text" => "Design", "type" => "task", "start_date" => "2025-01-06", "duration" => "3", "progress" => "40", "parent" => "", "constraint_type" => "", "constraint_date" => ""}

      iex> GanttEx.TaskForm.cast(%{"text" => " Build ", "type" => "task", "start_date" => "2025-01-08", "duration" => "2", "progress" => "25"}, :day)
      {:ok, %{text: "Build", type: :task, start_date: ~N[2025-01-08 00:00:00], duration: 2, progress: 0.25}}

      iex> GanttEx.TaskForm.cast(%{"text" => "", "start_date" => "nope", "duration" => "-1"}, :day)
      {:error, [text: :required, start_date: :invalid_date, duration: :invalid_number]}
  """

  alias GanttEx.{Dates, Store, Task}

  @doc """
  Returns the HTML input type used for dates with the given duration unit.

      iex> GanttEx.TaskForm.date_input_type(:day)
      "date"

      iex> GanttEx.TaskForm.date_input_type(:hour)
      "datetime-local"
  """
  @spec date_input_type(Dates.unit()) :: String.t()
  def date_input_type(unit) when unit in [:minute, :hour], do: "datetime-local"
  def date_input_type(_unit), do: "date"

  @doc """
  Formats a datetime for a date input.

      iex> GanttEx.TaskForm.input_date(~N[2025-01-06 09:30:00], :hour)
      "2025-01-06T09:30"
  """
  @spec input_date(NaiveDateTime.t() | nil, Dates.unit()) :: String.t()
  def input_date(nil, _unit), do: ""

  def input_date(%NaiveDateTime{} = datetime, unit) do
    case date_input_type(unit) do
      "date" -> datetime |> NaiveDateTime.to_date() |> Date.to_iso8601()
      _ -> Calendar.strftime(datetime, "%Y-%m-%dT%H:%M")
    end
  end

  @doc """
  Returns the end date to *display*.

  End dates are exclusive internally (a one-day task on January 6th ends on
  January 7th at midnight), but people expect to read the last day of work.
  For day-based units, an end date at midnight is shown as the previous day.

      iex> task = GanttEx.Task.new!(id: 1, start_date: ~D[2025-01-06], end_date: ~D[2025-01-07])
      iex> GanttEx.TaskForm.display_end(task, :day)
      ~N[2025-01-06 00:00:00]

      iex> task = GanttEx.Task.new!(id: 1, start_date: ~N[2025-01-06 09:00:00], end_date: ~N[2025-01-06 17:00:00])
      iex> GanttEx.TaskForm.display_end(task, :hour)
      ~N[2025-01-06 17:00:00]
  """
  @spec display_end(Task.t(), Dates.unit()) :: NaiveDateTime.t() | nil
  def display_end(%Task{end_date: nil}, _unit), do: nil
  def display_end(%Task{type: :milestone, start_date: start}, _unit), do: start

  def display_end(%Task{start_date: start, end_date: finish}, unit) do
    if date_input_type(unit) == "date" and Dates.floor(finish, :day) == finish and
         NaiveDateTime.compare(finish, start) == :gt do
      Dates.add(finish, -1, :day)
    else
      finish
    end
  end

  @doc """
  Converts a displayed (inclusive) end date back to the exclusive end date.
  The inverse of `display_end/2`.

      iex> GanttEx.TaskForm.parse_end(~N[2025-01-06 00:00:00], :day)
      ~N[2025-01-07 00:00:00]

      iex> GanttEx.TaskForm.parse_end(~N[2025-01-06 17:00:00], :hour)
      ~N[2025-01-06 17:00:00]
  """
  @spec parse_end(NaiveDateTime.t(), Dates.unit()) :: NaiveDateTime.t()
  def parse_end(%NaiveDateTime{} = date, unit) do
    if date_input_type(unit) == "date",
      do: Dates.add(Dates.floor(date, :day), 1, :day),
      else: date
  end

  @doc """
  Returns the form params for a task.
  """
  @spec params(Task.t(), Dates.unit()) :: %{String.t() => String.t()}
  def params(%Task{} = task, unit) do
    %{
      "text" => task.text,
      "type" => Atom.to_string(task.type),
      "start_date" => input_date(task.start_date, unit),
      "duration" => to_string(task.duration || 0),
      "progress" => task.progress |> Kernel.*(100) |> round() |> Integer.to_string(),
      "parent" => if(task.parent, do: Store.key(task.parent), else: ""),
      "constraint_type" =>
        if(task.constraint_type, do: Atom.to_string(task.constraint_type), else: ""),
      "constraint_date" => input_date(task.constraint_date, unit)
    }
  end

  @doc """
  Validates submitted params.

  Returns `{:ok, attrs}` with the attributes to apply to the task, or
  `{:error, errors}` where errors is a keyword list of `field: reason`. Reasons
  are keys of `GanttEx.I18n.labels/1` (`:required`, `:invalid_date`,
  `:invalid_number`, `:invalid_progress`).

  A `"parent"` param is resolved to a task id when a `store` is given (an empty
  value means "top level").
  """
  @spec cast(map(), Dates.unit(), Store.t() | nil) :: {:ok, map()} | {:error, keyword(atom())}
  def cast(params, unit, store \\ nil) do
    {attrs, errors} =
      [
        :text,
        :type,
        :start_date,
        :duration,
        :progress,
        :parent,
        :constraint_type,
        :constraint_date
      ]
      |> Enum.reduce({%{}, []}, fn field, acc ->
        cast_param(acc, field, Map.fetch(params, Atom.to_string(field)), unit, store)
      end)

    attrs =
      if attrs[:type] == :milestone, do: Map.put(attrs, :duration, 0), else: attrs

    {attrs, errors} = check_constraint(attrs, errors)

    case errors do
      [] -> {:ok, attrs}
      errors -> {:error, Enum.reverse(errors)}
    end
  end

  defp cast_param({attrs, errors}, _field, :error, _unit, _store), do: {attrs, errors}

  defp cast_param({attrs, errors}, :constraint_type, {:ok, value}, _unit, _store) do
    case Task.cast_constraint(value) do
      {:ok, type} -> {Map.put(attrs, :constraint_type, type), errors}
      :error -> {attrs, [{:constraint_type, :required} | errors]}
    end
  end

  defp cast_param({attrs, errors}, :constraint_date, {:ok, value}, _unit, _store) do
    case Dates.cast(value) do
      {:ok, date} -> {Map.put(attrs, :constraint_date, date), errors}
      :error -> {attrs, [{:constraint_date, :invalid_date} | errors]}
    end
  end

  defp cast_param({attrs, errors}, :text, {:ok, text}, _unit, _store) do
    case String.trim(text || "") do
      "" -> {attrs, [{:text, :required} | errors]}
      text -> {Map.put(attrs, :text, text), errors}
    end
  end

  defp cast_param({attrs, errors}, :type, {:ok, type}, _unit, _store) do
    case Task.cast_type(type) do
      {:ok, type} -> {Map.put(attrs, :type, type), errors}
      :error -> {attrs, [{:type, :required} | errors]}
    end
  end

  defp cast_param({attrs, errors}, :start_date, {:ok, value}, _unit, _store) do
    case Dates.cast(value) do
      {:ok, %NaiveDateTime{} = date} -> {Map.put(attrs, :start_date, date), errors}
      _ -> {attrs, [{:start_date, :invalid_date} | errors]}
    end
  end

  defp cast_param({attrs, errors}, :duration, {:ok, value}, _unit, _store) do
    case Integer.parse(String.trim(to_string(value))) do
      {duration, ""} when duration >= 0 -> {Map.put(attrs, :duration, duration), errors}
      _ -> {attrs, [{:duration, :invalid_number} | errors]}
    end
  end

  defp cast_param({attrs, errors}, :progress, {:ok, value}, _unit, _store) do
    case Integer.parse(String.trim(to_string(value))) do
      {percent, ""} when percent in 0..100 -> {Map.put(attrs, :progress, percent / 100), errors}
      _ -> {attrs, [{:progress, :invalid_progress} | errors]}
    end
  end

  defp cast_param(acc, :parent, {:ok, _key}, _unit, nil), do: acc

  defp cast_param({attrs, errors}, :parent, {:ok, key}, _unit, store) do
    case key do
      blank when blank in [nil, ""] ->
        {Map.put(attrs, :parent, nil), errors}

      key ->
        case Store.task_by_key(store, key) do
          nil -> {attrs, errors}
          task -> {Map.put(attrs, :parent, task.id), errors}
        end
    end
  end

  # Dated constraints need a date; the others ignore it.
  defp check_constraint(%{constraint_type: type} = attrs, errors)
       when type in [:snet, :snlt, :fnet, :fnlt, :mso, :mfo] do
    if attrs[:constraint_date] || Keyword.has_key?(errors, :constraint_date),
      do: {attrs, errors},
      else: {attrs, [{:constraint_date, :required} | errors]}
  end

  defp check_constraint(%{constraint_type: _} = attrs, errors),
    do: {Map.put(attrs, :constraint_date, nil), errors}

  defp check_constraint(attrs, errors), do: {attrs, errors}
end
