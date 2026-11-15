import path from "node:path"
import { defineConfig } from "vitest/config"
import { svelte } from "@sveltejs/vite-plugin-svelte"
import { svelteTesting } from "@testing-library/svelte/vite"

const repo = path.resolve(import.meta.dirname, "..")
const koansLib = process.env.KOANS_LIB ?? "lib"
const tree = path.join(path.dirname(koansLib), "assets")

export default defineConfig({
  root: repo,
  plugins: [svelte({ configFile: path.join(repo, "assets/svelte.config.js") }), svelteTesting()],
  test: {
    environment: "jsdom",
    include: [`${tree}/koans/**/*.test.ts`],
    fileParallelism: false,
    testTimeout: 5_000,
  },
})
