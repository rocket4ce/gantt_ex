defmodule GanttEx.MixProject do
  use Mix.Project

  @version "0.4.0"
  @source_url "https://github.com/rocket4ce/gantt_ex"

  def project do
    [
      app: :gantt_ex,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      name: "GanttEx",
      description:
        "Interactive Gantt charts for Phoenix LiveView: tasks, dependencies, " <>
          "drag & drop scheduling, zoomable scales and i18n, with minimal JavaScript.",
      package: package(),
      docs: docs(),
      source_url: @source_url,
      homepage_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger, :xmerl]
    ]
  end

  def cli do
    [preferred_envs: [precommit: :test]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix_live_view, "~> 1.2"},
      {:gettext, "~> 0.26 or ~> 1.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "https://hexdocs.pm/gantt_ex/changelog.html"
      },
      files: ~w(lib priv guides mix.exs README.md CHANGELOG.md LICENSE .formatter.exs)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "guides/getting_started.md",
        "guides/persistence.md",
        "guides/customization.md",
        "guides/i18n.md",
        "guides/pro_features.md",
        "CHANGELOG.md"
      ],
      groups_for_extras: [Guides: ~r/guides\//],
      groups_for_modules: [
        "LiveView integration": [
          GanttEx.Live.Gantt,
          GanttEx.Live.Components,
          GanttEx.Live.Columns,
          GanttEx.Live.Interaction,
          GanttEx.Live.Icons,
          GanttEx.Live.Hook,
          GanttEx.Live.Styles,
          GanttEx.ColocatedCSS
        ],
        "Data model": [
          GanttEx.Task,
          GanttEx.Link,
          GanttEx.Store,
          GanttEx.Filter,
          GanttEx.Event,
          GanttEx.History,
          GanttEx.Marker,
          GanttEx.Resource
        ],
        Scheduling: [
          GanttEx.Calendar,
          GanttEx.Dependency,
          GanttEx.Scheduler,
          GanttEx.CriticalPath,
          GanttEx.ResourceLoad
        ],
        "Time & layout": [
          GanttEx.Dates,
          GanttEx.Scale,
          GanttEx.Timeline,
          GanttEx.Zoom,
          GanttEx.Layout,
          GanttEx.LinkPath
        ],
        Forms: [GanttEx.TaskForm, GanttEx.LinkForm],
        "Import & export": [GanttEx.Export, GanttEx.Import],
        Internationalization: [GanttEx.I18n, GanttEx.Gettext]
      ]
    ]
  end
end
