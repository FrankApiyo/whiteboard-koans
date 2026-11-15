import { defineConfig, devices } from "@playwright/test"

// Port and database live in config/e2e.exs; the LiveView socket's origin check
// compares hosts, so the browser uses "localhost" as that file's url does.
const port = 4100

const serverSteps = [
  "mix compile",
  "mix assets.build",
  "mix ecto.create --quiet",
  "mix ecto.migrate --quiet",
  "mix phx.server",
]

export default defineConfig({
  testDir: "e2e",
  workers: 1,
  retries: 0,
  fullyParallel: false,
  forbidOnly: true,
  reporter: [["list"], ["html", { open: "never" }]],
  use: {
    baseURL: `http://localhost:${port}`,
    trace: "retain-on-failure",
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"], viewport: { width: 1280, height: 900 } },
    },
  ],
  webServer: {
    command: serverSteps.join(" && "),
    env: {
      MIX_ENV: "e2e",
      // >>> course
      // The learner's lib/ holds blanks, so the suite runs the solved app.
      KOANS_LIB: "solutions/lib",
      // <<< course
    },
    url: `http://127.0.0.1:${port}/name`,
    reuseExistingServer: false,
    timeout: 300_000,
    stdout: "ignore",
    stderr: "pipe",
  },
})
