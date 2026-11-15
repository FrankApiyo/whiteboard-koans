import Config

# A production-like server for the Playwright suite (`npm run e2e`): built assets,
# no code reloader, and its own port and database so it never meets the dev server.
config :easel, Easel.Repo,
  database: Path.expand("../tmp/e2e/easel_e2e.db", __DIR__),
  pool_size: 5

config :easel, EaselWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4100],
  url: [host: "localhost", port: 4100],
  secret_key_base: "/gy7I1UTddcHCGtnZt8kLsSWn97R/jF1sqctmjAWFRfhezMmXvDiVmvNH6JKAXaj",
  server: true

config :logger, level: :warning
