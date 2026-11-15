# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :live_svelte, ssr: false

config :phoenix_vite, PhoenixVite.Npm,
  assets: [args: [], cd: Path.expand("..", __DIR__)],
  vite: [
    args: ~w(exec -- vite),
    cd: Path.expand("../assets", __DIR__),
    env: %{"MIX_BUILD_PATH" => Mix.Project.build_path()}
  ]

config :easel,
  ecto_repos: [Easel.Repo],
  generators: [timestamp_type: :utc_datetime]

config :easel, :board_server, save_after: 500, idle_after: :timer.minutes(5)

# Configures the endpoint
config :easel, EaselWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: EaselWeb.ErrorHTML, json: EaselWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Easel.PubSub,
  live_view: [signing_salt: "4ykNRhNd"]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
