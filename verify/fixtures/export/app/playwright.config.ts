import { defineConfig } from "@playwright/test"

export default defineConfig({
  testDir: "e2e",
  webServer: {
    command: "mix phx.server",
    env: {
      MIX_ENV: "e2e",
      // >>> course
      // The learner's lib/ holds blanks, so the suite runs the solved app.
      KOANS_LIB: "solutions/lib",
      // <<< course
    },
  },
})
