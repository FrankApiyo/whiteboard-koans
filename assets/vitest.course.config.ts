import path from "node:path"
import { defineConfig } from "vitest/config"

const repo = path.resolve(import.meta.dirname, "..")

export default defineConfig({
  root: repo,
  resolve: { alias: { "@koans": path.join(repo, "assets/koans_support") } },
  test: {
    environment: "node",
    include: ["assets/koans_support/test/**/*.test.ts"],
    fileParallelism: false,
  },
})
