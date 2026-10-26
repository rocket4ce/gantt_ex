import Config

# This configuration is only used when working on GanttEx itself
# (tests and docs). It is not loaded when GanttEx is a dependency.
if config_env() == :test do
  config :phoenix, :json_library, JSON

  config :gantt_ex, GanttEx.Test.Endpoint,
    url: [host: "localhost"],
    secret_key_base: String.duplicate("gantt_ex_test_secret_", 4),
    live_view: [signing_salt: "gantt_ex_salt"],
    render_errors: [formats: [html: GanttEx.Test.ErrorHTML], layout: false],
    pubsub_server: GanttEx.Test.PubSub,
    server: false

  config :logger, level: :warning
end
