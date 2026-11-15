import { defineConfig } from 'vite'
import { svelte } from "@sveltejs/vite-plugin-svelte"
import liveSveltePlugin from "live_svelte/vitePlugin"
import tailwindcss from "@tailwindcss/vite";
// >>> course
import path from "node:path"

const repo = path.resolve(import.meta.dirname, "..")
const tree = path.relative(
  import.meta.dirname,
  path.resolve(repo, path.dirname(process.env.KOANS_LIB ?? "lib"), "assets"),
)
// <<< course

export default defineConfig({
  server: {
    port: 5173,
    strictPort: true,
    cors: { origin: "http://localhost:4000" },
  },
  optimizeDeps: {
    // https://vitejs.dev/guide/dep-pre-bundling#monorepos-and-linked-dependencies
    include: ["live_svelte", "phoenix", "phoenix_html", "phoenix_live_view"],
  },
  ssr: { noExternal: process.env.NODE_ENV === "production" ? true : undefined },
    build: {
    manifest: true,
    rollupOptions: {
      input: ["js/app.js", "css/app.css"],
    },
    outDir: "../priv/static",
    emptyOutDir: true,
  },
  // LV Colocated JS and Hooks
  // https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.ColocatedJS.html#module-internals
  resolve: {
    alias: {
      "@": ".",
      "phoenix-colocated": `${process.env.MIX_BUILD_PATH}/phoenix-colocated`,
      // >>> course
      "@koans": path.join(repo, "assets/koans_support"),
      // <<< course
    },
  },
  plugins: [
    tailwindcss(),
    svelte({ compilerOptions: { css: "injected" } }),
    liveSveltePlugin({
      entrypoint: "./js/server.js",
      // >>> course
      components: [path.join(tree, "svelte/**/*.svelte")],
      // <<< course
    })
  ]
});
