# Whiteboard koans

Koans for a real-time Phoenix app with a typed client, for someone who has done the Elixir and
Phoenix courses. The repo is a shared whiteboard called Easel: Phoenix 1.8 and LiveView on the
server, a Svelte 5 component in TypeScript on the client, joined by live_svelte. Its code has
blanks in both languages, and the koans in `assets/koans/` and `test/koans/` run that code.
Fill the blanks, run, read the next meditation. When the last koan passes you have written
Easel, and `mix easel.export` turns it into a clean repo of your own that you can show
employers.

There are TBD koans in 15 chapters, planned as six mornings of two hours: TypeScript for this
app, Svelte, the board on the server (live_svelte, the database, a GenServer per board),
talking to the browser, many people at once (PubSub, Presence, cursors), and finishing
(reconnects and the app's own tests).

## Setup

```sh
cd whiteboard-koans
mix setup
mix koans
nvim
```

`mix setup` fetches the Hex and npm dependencies, creates and migrates the SQLite database and
builds the assets. Run it before anything else: some koans render pages, and pages need the
built assets. It is the only step that needs the network. Node is needed for the build and the
TypeScript koans; `node_modules/` sits at the repo root, next to `package.json`.

Open nvim from this directory. vim-test runs `mix test` and Vitest in the directory nvim was
started in, and the REPLs below start there too.

Do not format the koan files. `mix format` skips `test/koans/` and `.prettierignore` lists
`assets/koans/`, but formatting one by hand or on save can rewrap a meditation or a template, so
turn format-on-save off for both directories.

## The loop

```sh
mix koans
```

`mix koans` runs the whole course in order. First `svelte-check` reads every `.ts` and
`.svelte` file, then the Elixir koans run, then the TypeScript koans, and one footer reports the
earliest koan you have not answered. Chapters count in order, and within a chapter that has
both kinds the TypeScript koans come first. On a fresh checkout the bottom of the output is:

```
Replace __blank() with the code the meditation describes.
------------------------------- The master says --------------------------------
Write:          assets/js/hello.ts:3  (00: greet)
Exercised by:   assets/koans/00_about_koans.test.ts:35
    Implement greet in assets/js/hello.ts so it returns Hello, the name and an exclamation mark. ...
0 of TBD koans answered.
```

`Write:` is the file and line to edit, with the blank's tag. `Exercised by:` is the koan that
ran it, and the line below is its meditation. An Elixir code blank names its function instead
of a tag: `Write:          lib/easel/hello.ex:9  (Easel.Hello.greet/1)`. When the blank is a
value in the koan itself, the footer points at the line to change:

```
Replace __ with the value that makes this true.
------------------------------- The master says --------------------------------
Meditate on test/koans/00_about_koans_test.exs:42
    A blank's tag starts with its chapter number, which is what :vimgrep /__("07\|__blank("07/ finds.
1 of TBD koans answered.
```

If your code gave a wrong answer, the diff appears above the footer: Elixir prints `left:`
(what your code gave) and `right:` (what the test expects), Vitest prints `expected:` and
`received:`. When the last koan passes the footer changes to `Enlightenment` and prints the
command to start again.

A typo stops the run before any koan, and no footer appears. In Elixir the compiler names a
`file:line`. In TypeScript the type check prints `Type check failed:` and up to five lines of
`path:line:col  message`. That is your typo, or a type your code does not match.

`mix koans` runs both languages. From a koan file, vim-test runs only that file's language:
`mix test` for the Elixir koans and Vitest for the TypeScript ones. Each prints its own footer
and counts only its own kind, as in `2 of 40 Elixir koans answered.`

| Keys         | Runs                                                 |
| ------------ | ---------------------------------------------------- |
| `<leader>ts` | every koan of the language you are in                |
| `<leader>tf` | the file you are in                                  |
| `<leader>tt` | the single koan under the cursor                     |
| `<leader>tl` | whatever you ran last                                |

The nearest-koan key finds the koan around the cursor, so put the cursor inside the koan, not
above it. With the cursor above every koan nothing runs, and the footer says `No koan at that
line`.

Commit your answers at the end of each morning, for example `git commit -am "morning 3"`. Then
a reset by mistake or an edit you regret never costs you more than one morning.

## The kinds of blank

**A value.** A plain `__` inside a koan stands for a value that makes the assertion true, in
either language.

```
Replace __ with the value that makes this true.
```

**Elixir code.** In `lib/` and `test/support/`, a blank sits between two marker lines that carry
the chapter number, and its tag names what it is for:

```elixir
def greet(name) do
  # >>> 00
  __("00: say hello")
  # <<< 00
end
```

Replace the `__("...")` line with code and keep both marker lines. Sometimes the blank stands for
whole clauses of a function, heads included, and appears as a one-line stub such as
`def handle_info(_msg, socket), do: __("NN: tag")`; replace the stub with every clause. In
HEEx the markers are comments and the blank is an expression in braces: `<%!-- >>> NN --%>`,
`{__("NN: tag")}`, `<%!-- <<< NN --%>`. While a file holds a blank, its imports and aliases end
in `warn: false`; the export removes it.

**TypeScript and Svelte code.** In `assets/js/`, `assets/svelte/` and `assets/test/`, a code
blank is a `__blank("NN: tag");` line between `// >>> NN` and `// <<< NN`:

```ts
export function greet(name: string): string {
  // >>> 00
  __blank("00: greet");
  // <<< 00
}
```

Replace the `__blank` line and keep the markers. Signatures and types are always given, so a
blank never asks you to invent a type. In Svelte markup the markers are HTML comments, and the
blank renders nothing until you replace it:

```svelte
<!-- >>> NN -->
{__blank("NN: tag", "")}
<!-- <<< NN -->
```

A koan that needs that markup fails because the element is missing, and its footer still names
the markup blank's `Write:` line. Until you fill a code blank, calling it fails with
`Replace __() with the code the meditation describes.` (Elixir) or
`Replace __blank() with the code the meditation describes.` (TypeScript), and the footer points
at the blank, not at the assertion.

**Defaulted code.** A few blanks take a default, as in `__("11: subscribe", :ok)` or
`return __blank("10: listen", () => {});`. Until you fill one it returns the default, so the app
keeps working on the code you have written: your shapes simply do not reach the other window
yet. A defaulted blank fails only the koans of its own chapter, with the same `Write:` footer.

Every tag starts with its chapter, in both languages, so one `:vimgrep` lists a chapter's
blanks everywhere; `:copen` shows them:

```
:vimgrep /__("07\|__blank("07/ lib/** test/support/** assets/**
```

Chapter 00 teaches all of this with two tiny functions, one per language.

## The six mornings

| Morning | Chapters (koans) | Koans |
| ------- | ---------------- | ----- |
| 1 | 00 about koans (3), 01 typescript basics (TBD), 02 modelling shapes (TBD) | TBD |
| 2 | 03 components and runes (TBD), 04 effects bindings and the toolbar (TBD), 05 drawing on a canvas (TBD) | TBD |
| 3 | 06 live svelte (TBD), 07 boards and shapes in the database (TBD), 08 the board server (TBD) | TBD |
| 4 | 09 client to server (TBD), 10 server to client (TBD) | TBD |
| 5 | 11 pubsub fan out (TBD), 12 presence and cursors (TBD) | TBD |
| 6 | 13 reconnects and consistency (TBD), 14 testing the whole thing (TBD) | TBD |

Value koans take about a minute. Code koans take five to fifteen. If a morning runs long, stop at
a chapter boundary. At most six of a morning's code blanks, counting both languages, are larger
than a few lines.

## Checkpoints

The app is the course, so it starts working as you fill it in. With chapters up to the number
below filled:

| After chapter | `mix phx.server` serves |
| ------------- | ----------------------- |
| 08 | a board you can create and open |
| 10 | what you draw, still there after a reload |
| 12 | two windows drawing together, each listing the other |

Before that, the name page works from the start, and the board pages show a blank's message on
Phoenix's debug page. That is the course talking, not a crash.

```sh
mix phx.server
```

Open [localhost:4000](http://localhost:4000). For a second person, open the board link in a
window with its own session (a private window or another browser). Stop the server with
`ctrl-c` twice.

## Pictures

`lessons/index.html` has the lesson of every chapter, its list of files, and a diagram where a
picture beats prose. In a chapter with both kinds, the TypeScript lesson comes first.
Regenerate it with `mix koans.lessons` and open it once in a browser beside Neovim:

```sh
open lessons/index.html
```

Each koan file opens with the same lesson and names its diagram. The diagrams are standalone
files under `lessons/svg/`; `open lessons/svg/<file>` shows one in Preview.

## Trying things before you commit to an answer

The point of a koan is to know why the answer is right. Evaluate the pieces first.

**Elixir.** Use iex in a neoterm split. Start nvim in the repo root, then send a line with
`:TREPLSendLine`, or select lines and run `:'<,'>TREPLSendSelection`. Your config makes neoterm
launch `iex -S mix` on the first send from an Elixir buffer, so do not start iex by hand first.
In the shell: `recompile()` after you change a file in `lib/`, `h GenServer.call/3` for docs,
`i value` to describe a value, and `v()` for the last result. Run `iex -S mix phx.server` for
the server and a shell together.

**TypeScript.** Node strips types itself, so a scratch file runs as it is: put a few lines in
`tmp/scratch.ts` (`tmp/` is ignored) and run `node tmp/scratch.ts`. Plain expressions also work
at a `node` prompt. For a type question, hover in Neovim, or run
`npx svelte-check --tsconfig assets/tsconfig.json` to see what the checker says.

## Starting over

```sh
mix koans.reset 07
mix koans.reset all
mix koans.cold 07
```

`mix koans.reset 07` puts chapter 07 back to its blanks, in both languages, and keeps your code
in every other chapter. It works even while a file has a compile or type error, which is when
you need it most. `mix koans.reset all` re-blanks everything. `cold 07` resets the chapter and
also strips the step-by-step parts of its meditations, so you write the code again from the
behaviour alone.

Before either command writes, it copies every file it is about to change into
`.koans/last-reset/`, replacing the copies the previous reset left there. If you reset the wrong
chapter, copy your code back from there.

Never edit `source/`. `solutions/` has every answer filled, for after a real attempt: read one,
close it, and write yours.

## Exporting your app

When every koan passes and no `__(` or `__blank(` is left:

```sh
mix easel.export ../easel
```

That writes a new git repo with one commit, made with your git config. It holds the app, its
config, migrations and assets with `package.json` and its lock, its Elixir and TypeScript tests,
the Playwright suite, a README describing Easel and a CI workflow that runs the tests, the type
check and the end-to-end suite. It leaves out the koans, the markers, the blank runtime,
`source/`, `solutions/` and `lessons/`, and it formats every Elixir file it writes. The task
prints the commands that check the result.

Take a screenshot of a board with a few shapes and two windows side by side, save it as
`docs/screenshot.png` in the exported repo, and add `![Easel](docs/screenshot.png)` under the
title. The exported README has a comment at that spot saying the same; delete it afterwards.

It refuses while any blank remains, naming the first three, and it refuses if the target exists,
so it never overwrites later work.

## Being stuck well

Read the lesson at the top of the file once, then the meditation before the assertion. For a
code koan, write the numbered steps of the meditation as lines of code, one at a time, and try
the pieces in iex or node. Most confusion on the server is one of these:

- Forgetting `{:noreply, socket}`. A `handle_event` or `handle_info` returns the tuple, not the
  socket, and a `handle_call` returns `{:reply, value, state}`.
- Reading params as atoms. Event payloads arrive with string keys: `%{"id" => id}`.
- Taking the snapshot before subscribing. Subscribe first, then read the board, or an operation
  can fall between the two.

And on the client:

- Narrowing lost across a callback. `if (state.selectedId)` narrows `state.selectedId` only up
  to the next function boundary: inside a callback TypeScript forgets it, because the property
  could change before the callback runs. Copy it into a `const` first and use that.
- Setting state in an `$effect`. A value computed from other state is a `$derived`; an effect
  that writes state to keep two values in step runs late and can loop. Keep effects for the
  world outside Svelte: the canvas, timers, listeners.
- A deep `$state` proxy over pen points. `$state` wraps every nested array in a proxy, and a pen
  stroke can hold 2000 points. The board keeps its shapes in `$state.raw` and replaces the map
  whole on each change.
- Reading state after an `await` inside an effect. An `$effect` tracks only what it reads
  synchronously; a read after `await`, or inside `requestAnimationFrame`, is not tracked, so the
  effect does not run again when it changes. Read everything first, then do the async part.
- Forgetting to remove a `handleEvent` listener. `live.handleEvent` returns a reference: pass it
  to `live.removeHandleEvent` in the cleanup that `onMount` returns. Without it a remounted
  component keeps the old handler, and every event is applied twice.

## For maintainers

`source/` is the single authored copy of `lib/`, `test/support/`, `test/koans/`, `assets/js/`,
`assets/svelte/`, `assets/test/` and `assets/koans/`. A value answer is written `_a(value)` in
both languages. An Elixir code answer is the run of lines between `# >>> answer NN: tag` and
`# <<<` (with `| stub: <head>` for clauses and `| default: <expr>` for defaulted blanks; HEEx
uses `<%!-- >>> answer NN: tag --%>`). A TypeScript answer sits between
`// >>> answer NN: tag` and `// <<<` (with `| default: <expr>` around a whole function body),
and Svelte markup uses `<!-- >>> answer NN: tag -->` and `<!-- <<< -->`. `mix koans.gen` writes
the learner's files and `solutions/` from it; `--only NN,NN` limits it to some chapters. Lines
between `# >>> course` and `# <<< course` (or `// >>> course`, `/* >>> course */`) exist only for
the course, and the export removes them.

```sh
KOANS_ONLY=07 MIX_TEST_PARTITION=verify mix test verify/course_test.exs
MIX_TEST_PARTITION=verify mix test verify/export_test.exs --include export_full
MIX_TEST_PARTITION=verify mix test verify/lessons_test.exs
KOANS_LIB=solutions/lib MIX_TEST_PARTITION=app mix test
KOANS_LIB=solutions/lib npm run test:app
npm run test:course
npm run e2e
```

`course_test.exs` proves, chapter by chapter and in both languages, that a chapter's koans fail
as its own blanks with the chapters below filled and pass with it filled. The export test
exports a fully filled tree and runs `mix compile --warnings-as-errors`,
`mix format --check-formatted`, the asset build, `mix test`, `npm test` and `svelte-check` on
it. `npm run e2e` drives the solved app in two Chromium sessions. The course's own Elixir code
lives in `course/` and its TypeScript runtime in `assets/koans_support/`; neither is exported.
