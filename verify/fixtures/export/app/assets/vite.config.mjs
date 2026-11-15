import { defineConfig } from "vite"
import liveSveltePlugin from "live_svelte/vitePlugin"
// >>> course
import path from "node:path"

const repo = path.resolve(import.meta.dirname, "..")
// <<< course

export default defineConfig({
  resolve: {
    alias: {
      "@": ".",
      // >>> course
      "@koans": path.join(repo, "assets/koans_support"),
      // <<< course
    },
  },
  plugins: [
    liveSveltePlugin({
      entrypoint: "./js/server.js",
      // >>> course
      components: [path.join(repo, "assets/svelte/**/*.svelte")],
      // <<< course
    }),
  ],
})
