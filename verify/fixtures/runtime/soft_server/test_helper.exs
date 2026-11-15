Code.require_file("../../../support/failure_formatter.exs", __DIR__)
Koans.Hits.start()

ExUnit.start(
  seed: 0,
  timeout: 5_000,
  capture_log: true,
  max_cases: 1,
  formatters: [VerifyFailureFormatter, Koans.Formatter]
)
