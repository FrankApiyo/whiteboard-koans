# Easel

<!-- Add a screenshot: draw a few shapes with two windows side by side, save it as
docs/screenshot.png, put ![Easel](docs/screenshot.png) on the line below the title,
and delete this comment. -->

A shared whiteboard built with Phoenix 1.8, LiveView, Svelte 5 and TypeScript. Several people
open the same board link, draw rectangles, ellipses, lines and freehand strokes on one canvas,
and see each other's shapes, cursors and names as they work.

Built while working through a hands-on course on Svelte, TypeScript and real-time Phoenix.

## Features

- Pick a display name once and the server gives you a colour from a fixed palette. Both live
  in the session; there are no accounts.
- Create a board with a title. It gets an unguessable link, `/b/<slug>`, and anyone with the
  link and a name can join. The home page lists the last ten boards you created.
- A toolbar with select, rectangle, ellipse, line and pen, a colour choice, and a delete
  button for the selected shape. Select a shape and drag it to move it.
- Shapes appear for everyone when the pointer is released, and so do moves and deletes.
- A cursor for every other viewer, labelled with their name and colour, and a list of who is
  on the board.
- A reload or a late joiner sees the whole board, and a board nobody has touched for a while
  is saved and comes back from the database.

## Run it

```sh
mix setup
mix phx.server
```

`mix setup` installs the Hex and npm dependencies, creates and migrates the SQLite database
and builds the assets. Node is needed only to build the assets and run the TypeScript tests.

Open [localhost:4000](http://localhost:4000), pick a name and create a board. Then open the
same board link in a second window that has its own session (a private window or another
browser), give it another name, and put the two windows side by side. What you draw in one
appears in the other, with the other person's cursor and name.

The checks CI runs:

```sh
mix compile --warnings-as-errors
mix format --check-formatted
mix test
npm test
npm run check
npm run e2e
```

## How it is built

**One process per board.** `Easel.Boards.BoardServer` is a GenServer with
`restart: :transient`, registered in `Easel.Boards.Registry` under the board's slug and started
on demand under `Easel.Boards.BoardSupervisor`, a DynamicSupervisor. On start it loads the
board's shapes into a map and broadcasts `:board_restarted`. It applies operations one at a
time, gives each new shape the next z-order, and broadcasts every applied operation on the
PubSub topic `"board:<slug>"`. It saves within 500 ms of the first unsaved change and stops
itself after five idle minutes. It traps exits, so `terminate/2` saves on an idle stop and on
shutdown too. A board can stop between finding it and calling it, so the public functions
start it again and retry once.

**LiveView and the Svelte component.** `EaselWeb.BoardLive` renders one Svelte component,
`Board`, through live_svelte, with server-side rendering off: a canvas has nothing to show
before the browser runs, and Node stays out of the server. The board process starts only on
the connected mount. There the LiveView starts the board, subscribes to its topic, tracks the
tab in Presence and only then takes the snapshot, so no operation falls between subscribing
and the snapshot. The component's props are that snapshot, `sync_id`, the viewer's own name
and colour, and the people on the board.

**Client to server.** Geometry, hit testing, the pointer-tool state machine and canvas drawing
are plain TypeScript modules with no DOM, so Vitest tests them directly; drawing is tested
against a recording fake of the canvas 2D context, and the Svelte components stay thin. A
finished shape is drawn at once with an id from `crypto.randomUUID()` and sent as `shape:add`
through `live.pushEvent`; moves and deletes send `shape:move` and `shape:delete`. The server
casts every payload through an Ecto embedded-schema changeset per kind: a UUID id, coordinates
inside the 1600 by 1000 board, a palette colour, at most 2000 points in a pen stroke. It
replies `%{ok: true}`, or `%{ok: false, shape: ...}` with its own copy of the shape (or `nil`),
and the reply callback restores that copy or removes the local one.

**Server to client.** Each LiveView turns every broadcast into `push_event`. The component
listens with `live.handleEvent`, checks each payload with a type guard (they arrive as
`unknown`), applies it by id and removes its listeners when it is destroyed.

**Presence and cursors.** Presence is keyed per browser tab, with the name and colour as
metadata, and the list reaches the component as props. Cursors never go into Presence: the
client sends its position at most 20 times a second, and the LiveView relays it with
`broadcast_from`, past the board process and back to everyone but the sender. A cursor carries
its tab id, so it disappears with that tab's Presence entry.

**Rendering.** One `<canvas>` with a fixed logical size of 1600 by 1000, scaled to fit with CSS
and sized for `devicePixelRatio`. The shape map is `$state.raw` and replaced whole on each
change rather than wrapped in a deep proxy, since a pen stroke alone can hold 2000 points. An
`$effect` reads the state and redraws in `requestAnimationFrame`.

## Design decisions

- **A process per board.** One GenServer owns a board's shapes, so a board's operations are
  applied in one order without locks, and the database gets one batched write per save window
  instead of one per pointer-up. The cost: a crash that skips `terminate/2` loses at most one
  save window, and the restarted process sends `:board_restarted` so every viewer resyncs.
- **Whole-value operations, idempotent by id.** `add` sends the whole shape, `move` the shape's
  new position (never a delta), `delete` the id. Adding a known id overwrites it and keeps its
  z-order; moving or deleting an unknown id does nothing, so a late move never brings back a
  deleted shape. A retried or duplicated message changes nothing. Every client, the sender
  included, applies the server's broadcasts, so all of them end up in the server's order.
- **Props for state, events for operations.** Props carry state that changes rarely: the
  snapshot, `sync_id`, the viewer and the people list. Shapes in props change only on a resync.
  Operations and cursors travel as events, so a move sends one shape's position rather than
  every shape on the board.
- **Reconnects resync through `sync_id`.** A reconnect runs mount again in a new LiveView
  process, but the Svelte component survives the DOM patch and only receives new props. Each
  connected mount makes a fresh `sync_id`, and the component replaces its whole shape map when
  `sync_id` changes. `:board_restarted` takes the same path: a new snapshot and a new `sync_id`.
- **Last write wins.** There is no merging of concurrent edits (no CRDT or OT). When two
  people move the same shape, the move the board process applies last is what everyone sees.
  A client ignores incoming operations for the shape it is dragging, and its pointer-up sends
  the final position. That is cheap and predictable for shapes, which one person usually
  handles at a time; it would not do for shared text.
- **The server trusts nothing from the browser.** It never stores a shape it has not cast and
  validated. A hostile payload gets `ok: false` and leaves the LiveView and the board process
  running.
- **SQLite for zero setup.** One file and no database server, so `mix setup` is the whole
  install. Each save replaces a board's shape rows in one transaction, with the kind-specific
  fields in a JSON `data` column.
- **The link is the access control.** There are no accounts. A board's slug is 16 random
  bytes, URL-safe, so a board can only be found by someone given its link.

### On Postgres

Swap `ecto_sqlite3` for `postgrex` and the `data` column, a `:map`, becomes `jsonb` with no
code change. The database tests could then run `async: true` under the SQL sandbox, which
SQLite's single writer rules out. Nothing else in the app depends on SQLite.

### In a cluster

PubSub and Presence work across nodes as they are, so viewers on two nodes see each other's
operations, cursors and names. The board process does not: `Easel.Boards.Registry` is local to
a node, so two nodes would each start a process for the same board and save over each other.
A cluster needs one owner per board, through a cluster-wide registry (`:global`, or a library
such as Horde) or by routing every viewer of a board to the same node. Several nodes also
cannot share one SQLite file, which is the point to move to Postgres.

## End-to-end tests

`npm run e2e` runs a Playwright suite in Chromium. It opens one board in two separate browser
sessions, as two people, and checks that each kind of shape, a drag, a delete, a named cursor
and the people list reach the other person, that a reload keeps the board, and that a board
left idle stops and comes back from the database. It starts its own server with `MIX_ENV=e2e`
on port 4100 with its own database under `tmp/e2e/`, so it never meets the dev server. Run
`npx playwright install chromium` once before the first run. CI runs it as a separate job.

## Known limits

- Shapes are selected and moved with a pointer only; there is no keyboard selection or
  movement yet.
- No resizing, text, undo, zoom or pan, and the board has a fixed size.
- A board's operations go through one process on one node (see "In a cluster").

## Working on it

Keep developing through branches and pull requests, so CI checks each change.
