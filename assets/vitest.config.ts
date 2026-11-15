import path from "node:path"
import { defineConfig } from "vitest/config"
import { svelte } from "@sveltejs/vite-plugin-svelte"
import { svelteTesting } from "@testing-library/svelte/vite"
import { KoanReporter } from "./koans_support/reporter.ts"
import { PathSequencer } from "./koans_support/sequencer.ts"

const repo = path.resolve(import.meta.dirname, "..")
const support = path.join(repo, "assets/koans_support")
const tree = path.join(path.dirname(process.env.KOANS_LIB ?? "lib"), "assets")
const verifyDir = process.env.KOANS_VERIFY === "1" ? process.env.KOANS_TS_DIR : undefined
const koansDir = path.relative(repo, path.resolve(repo, verifyDir ?? path.join(tree, "koans")))

export default defineConfig({
  root: repo,
  plugins: [svelte({ configFile: path.join(repo, "assets/svelte.config.js") }), svelteTesting()],
  resolve: { alias: { "@koans": support } },
  test: {
    environment: "jsdom",
    include: [`${koansDir}/**/*.test.ts`],
    setupFiles: [path.join(support, "setup.ts")],
    sequence: { sequencer: PathSequencer },
    reporters: [
      new KoanReporter({
        root: repo,
        koansDir: path.join(repo, koansDir),
        tree: path.join(repo, path.dirname(koansDir)),
      }),
    ],
    fileParallelism: false,
    testTimeout: 5_000,
    retry: 0,
  },
})
