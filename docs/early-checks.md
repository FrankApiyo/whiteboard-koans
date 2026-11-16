# Early checks

Spike record from 2026-11-15; the versions are the ones used then. Requirements are in the README.

Outcome: **live_svelte 0.18 with Vite (`phoenix_vite`) works. No fallback to 0.17.**

Versions: Elixir 1.19.5 / OTP 28, Node 25.9.0, Phoenix 1.8.16, LiveView 1.1.33,
live_svelte 0.18.0, phoenix_vite 0.6.1, igniter 0.8.5, Vite 8.3.8, Svelte 5.57.3,
@sveltejs/vite-plugin-svelte 7.3.1, Tailwind 4.3.5, Vitest 5.1.0,
@testing-library/svelte 5.4.2, jsdom 31.0.1, svelte-check 4.7.8, TypeScript 6.0.3.

## Commands

```
mix phx.new whiteboard-koans --app easel --module Easel --database sqlite3 --no-mailer --install
# mix.exs: {:igniter, "~> 0.6", only: [:dev, :test]}
mix deps.get
mix igniter.install live_svelte --yes
# config/config.exs: config :live_svelte, ssr: false
# config/dev.exs, config/prod.exs: dropped the installer's ssr_module lines
# lib/easel/application.ex: reverted the installer's NodeJS.Supervisor child
# mix.exs: dropped the SSR build from assets.build
npm install -D vitest@^5.1.0 @testing-library/svelte@^5.4.2 jsdom@^31.0.1 svelte-check@^4.7.8 typescript@^6
mix assets.build
mix ecto.create && mix phx.server
mix test spike/probe_live_test.exs
node_modules/.bin/vitest run --config assets/vitest.config.ts
npx svelte-check --tsconfig assets/tsconfig.json --fail-on-warnings
KOANS_LIB=spike/tree/lib node_modules/.bin/vitest run --config assets/vitest.config.ts
npx svelte-check --tsconfig spike/tree/assets/tsconfig.json --fail-on-warnings
```

## Layout the installer chose (differs from the plan's file map)

- `package.json`, `package-lock.json` and `node_modules/` are at the **repo root**, not in
  `assets/` (phoenix_vite's convention: `"live_svelte": "file:./deps/live_svelte"`, and
  `config :phoenix_vite, PhoenixVite.Npm, assets: [cd: <repo root>]`). `.gitignore` ignores
  `node_modules/` anywhere.
- `assets/vite.config.mjs` (not `.ts`), `assets/svelte.config.js`, `assets/js/server.js`
  (SSR entry; unused with SSR off but named by the Vite plugin).
- Static files moved from `priv/static` to `assets/public`; Vite writes all of `priv/static`
  (`/priv/static/*` is ignored).
- The installer removed esbuild and tailwind (Hex) and `assets/vendor/topbar.js` (now npm).
- Kept: root layout. It makes vim-test work from the repo root and makes the plan's
  `node_modules` symlinks in `solutions/assets` and `_verify/assets` unnecessary (check 8).

## Checks

| # | Result | What was run and seen |
| - | ------ | --------------------- |
| 1 | pass | `mix assets.build` exit 0 (Vite 8, `@tailwindcss/vite`). `mix phx.server`: `GET /` 200, `/svelte_demo` 200 (demo route removed after the spike), Vite dev server serves `/css/app.css` and `/js/app.js` 200. Built CSS has `.tracking-tighter`, `.text-balance`, `.leading-10`, `text-[2rem]`, all used only in `home.html.heex`. |
| 2 | pass | `spike/probe_live_test.exs` (`live_isolated` on a probe LiveView rendering `<.svelte name="Probe" props={%{start: @n}}>`): `get_svelte(view)` gives name `"Probe"`, props `%{"start" => 0}`, `ssr: false`; `NodeJS.Supervisor` not running; no port whose name contains `node`. The Vite build registers `Probe` in the client component map. |
| 3 | pass | Same test: `render_hook(view, "inc", %{})` returns the render, `assert_reply(view, %{n: 1})` and `assert_push_event(view, "bumped", %{n: 1})` pass, props become `%{"start" => 1}`. Renaming the pushed event made it fail (no matching message after 100ms). |
| 4 | pass | `Probe.svelte.test.ts`: `render`, `button.click()`, `flushSync()`, sees `count: 2`; `$state`/`$derived` work inside the `.svelte.test.ts` file. Without `svelteTesting()` it fails: `` `mount(...)` is not available on the server ``. `svelteTesting()` from `@testing-library/svelte/vite` fixes it (it also adds auto-cleanup); `resolve.conditions: ['browser']` alone also works. jsdom `getContext('2d')` returns `null` and prints "Not implemented: HTMLCanvasElement's getContext()". Mutating the component made the click test fail (`Expected "count: 2"`, `Received "count: 1"`). |
| 5 | finding | live_svelte ships `assets/js/live_svelte/types.d.ts` with `type Live`, but the package's `exports["."]` resolves `import` to `index.ts` (source), which does not re-export `Live`, and importing anything from `"live_svelte"` pulls its `.ts` sources into the program: 3 strict errors (`composables.ts:65` twice, `index.ts:4`). So: **none; given declaration in `assets/js/live.ts`**. Never import from `"live_svelte"` in type-checked files. |
| 6 | pass | `globals.d.ts` with `declare const __: any` and `declare function __blank(tag: string): never` plus `<T>(tag: string, fallback: T): T`. `function f(): number { __blank("x") }` passes (with `noImplicitReturns`): the never overload ends control flow, so no `__blankOr` is needed. `{__blank("x", "")}` in markup passes `svelte-check --fail-on-warnings`. A type error in a `.ts` file nothing imports is reported, and so is a missing return. A `.svelte` file is only type-checked if it has `<script lang="ts">`: `{notDeclared}` in a script-less component was not reported. |
| 7 | finding | A probe reporter's `onTestCaseResult(testCase)` gets `testCase.result().errors[0].stacks[0]` = `.../fail.test.ts:9:15`, the failing `expect` line. `testCase.location` is `undefined` unless `includeTaskLocation: true` is set. |
| 8 | pass | Probe test and components copied to `spike/tree/assets/{js,svelte,koans}`, `node_modules` symlink, `tsconfig.json` extending `assets/tsconfig.json`. `KOANS_LIB=spike/tree/lib` Vitest ran `spike/tree/assets/koans/Probe.svelte.test.ts` (3 passed), svelte-check passed and reported an error planted in the tree. The extending tsconfig must restate `include` (an extended `include` resolves against the base file) and add `../../../assets/koans_support/**/*` for the globals. Without the `node_modules` symlink both still pass: the root `node_modules` is found by walking up. |
| 9 | finding | vim-test's vitest runner works from cwd: it needs `package.json` listing vitest (or an `import ... vitest` line) and runs `node_modules/.bin/vitest run [-t '<name>'] <file>`. Vitest then looks for its config in cwd, so the repo root needs a `vitest.config.ts`; without it the run failed on `.svelte` imports. A root `vitest.config.ts` re-exporting `assets/vitest.config.ts` made file and `-t` runs pass. vim-test's nearest patterns match only lines starting with `it`/`test`/`describe.each` (namespace `describe`/`suite`/`context`/`module`); `koan(` lines are not seen, so "nearest" on a koan falls back to the enclosing `describe` or the whole file. The regex needs no word boundary, so a wrapper whose name starts with `test` or `it` would be seen. vim-test needs no `exrc`. |
| 10 | finding | After install: `deps` 110M, `_build` 127M, `node_modules` 354M (root), `priv/static` 252K. `df -h ~`: 39 GiB free (40 GiB before). |

## Other findings

- `mix test` needs the built Vite manifest: with `priv/static/.vite/manifest.json` missing,
  the generated `PageControllerTest` fails with `File.Error` (root layout reads the manifest).
  Run `mix assets.build` before tests on a fresh checkout or make the layout tolerate it.
- The installer changed the generated home page tagline, breaking `PageControllerTest`;
  the tagline was restored.
- The client bundle pulls in `svelte/src/internal/server/render-context.js` (Vite warns
  that `node:async_hooks` was externalised); harmless.
- The first `mix test` logged one `Exqlite ... database is locked` at startup (ecto.create
  and the migrator); later runs did not.
- vite-plugin-svelte warns on `state_referenced_locally` inside `.svelte.test.ts` files;
  svelte-check does not report it there.
- `svelte-check` 4.7.8 needs TypeScript `^5 || ^6`; TypeScript 7 is `latest` on npm, so
  pin `typescript@^6`.

## Two-window check (automated)

The manual two-window check is replaced by a Playwright suite that drives two separate
browser sessions (Ada and Lin, each with its own session cookie) on one board in Chromium.

```
npm run e2e
```

Playwright starts the app itself with `MIX_ENV=e2e` (`config/e2e.exs`): assets built with
`mix assets.build`, no Vite dev server, port 4100 and its own database in `tmp/e2e/`, so it
never meets the dev server on port 4000 or the dev database. Its boards save 200 ms after a
change and stop after 2 s without one, so a test can watch a board come back from SQLite. A first run compiles the `e2e`
build (`_build/e2e`); Chromium is installed once with `npx playwright install chromium`.

Result (2026-11-15): **7 passed** (about 16 s after the build; 21/21 with `--repeat-each=3`).

| Check | What the test does |
| ----- | ------------------ |
| Shapes appear in both | Ada draws a rectangle, an ellipse, a line and a pen stroke; after each, Lin's shape list (the canvas's `describe()` text) equals Ada's. |
| Moves appear in both | Lin drags Ada's rectangle with Select; Ada's description changes to Lin's new position. |
| Deletes appear in both | Ada selects the ellipse and presses Delete; only the rectangle is left for Lin. |
| Cursors carry names | Ada's pointer over the board shows Lin a cursor labelled "Ada" in Ada's colour; Ada sees no cursor of her own. |
| People list is right | Each list shows both names with "(you)" on one's own; closing Lin's browser removes Lin and Lin's cursor from Ada's page. |
| Board survives a reload | Ada waits past the save window, reloads, and every shape description is unchanged. |
| Board survives its server stopping | Ada and Lin close their browsers; after the idle stop a new visitor opens the board and sees every shape, now loaded from SQLite. |

Each check was shown to fail when its wire was cut (BoardLive not pushing `shape:added`,
`shape:moved`, `shape:deleted` or `cursor:moved`; "(you)" on the wrong person; leavers kept
in the people list; cursors never pruned; the join ignoring the board's snapshot; `save_shapes` writing nothing).
