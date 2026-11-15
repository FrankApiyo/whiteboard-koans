Koans.Hits.start()
Ecto.Adapters.SQL.Sandbox.mode(Easel.Repo, :manual)

ExUnit.start(
  seed: 0,
  timeout: 5_000,
  # A fresh VM's first channel reply can take over the 100ms default on a busy machine.
  assert_receive_timeout: 1_000,
  capture_log: true,
  max_cases: 1,
  formatters: [Koans.Formatter]
)
