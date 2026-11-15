import path from "node:path"
import { defineConfig } from "vitest/config"
import { svelte } from "@sveltejs/vite-plugin-svelte"
import { svelteTesting } from "@testing-library/svelte/vite"

const repo = path.resolve(import.meta.dirname, "..")

export default defineConfig({
  root: repo,
  plugins: [svelte({ configFile: path.join(repo, "assets/svelte.config.js") }), svelteTesting()],
  test: {
    environment: "jsdom",
    include: ["assets/test/**/*.test.ts"],
    setupFiles: [path.join(repo, "assets/test/support/setup.ts")],
  },
})
