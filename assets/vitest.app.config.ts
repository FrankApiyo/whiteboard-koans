import path from "node:path"
import { defineConfig } from "vitest/config"
import { svelte } from "@sveltejs/vite-plugin-svelte"
import { svelteTesting } from "@testing-library/svelte/vite"

const repo = path.resolve(import.meta.dirname, "..")
const tree = path.relative(
  repo,
  path.resolve(repo, path.dirname(process.env.KOANS_LIB ?? "lib"), "assets"),
)

export default defineConfig({
  root: repo,
  plugins: [svelte({ configFile: path.join(repo, "assets/svelte.config.js") }), svelteTesting()],
  test: {
    environment: "jsdom",
    include: [`${tree}/test/**/*.test.ts`],
    setupFiles: [
      // >>> course
      path.join(repo, "assets/koans_support/blanks.ts"),
      // <<< course
      path.join(repo, tree, "test/support/setup.ts"),
    ],
  },
})
