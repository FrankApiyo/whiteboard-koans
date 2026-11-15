/*
Files this chapter touches
  - assets/js/resync.ts: applyProps
  - lib/easel_web/live/board_live.ex (this chapter's Elixir koans)

Every browser ends up with the server's board. From the Phoenix course (chapter 10, LiveView
basics): a dropped socket reconnects by itself and the server mounts again, in a new process.
The page stays, and so does live_svelte's hook element, so LiveView calls the hook's updated()
with the new props, never mounted(): Board and its BoardState survive the reconnect.

So each connected mount sends a fresh sync_id with its snapshot, and Board's effect hands both
to applyProps(state, props). A sync_id other than the state's means "this is the whole board
now": replace every shape and keep the new id. The same sync_id changes nothing. Other, not
greater: sync ids are unique integers, not a count, and start over when the server restarts. A
playlist that reloads on a new version does the same:

    if (next.version !== list.version) list.load(next.tracks, next.version)

Between resyncs the browser runs ahead. A drawn shape shows at once and goes out as shape:add;
its echo, shape:added with the z the server gave it, replaces it by id. Moves carry whole
positions, so the server's order decides: the last move it applies wins, in every browser,
the sender's too. A move it applied earlier is lost, with no merge and no warning.

    Write:          assets/js/resync.ts:9  (13: replace everything when sync_id changes)
    Exercised by:   assets/koans/13_reconnects_and_consistency.test.ts:70

API you'll use
  - state.syncId, state.replaceAll(shapes, syncId): chapter 04's BoardState
  - SvelteHook.updated.call(hook): what LiveView runs when the hook's element changes; it reads
    data-props again, and with data-use-diff "true" sets only the keys sent, keeping the rest
  - getHooks, SvelteHook.mounted.call(hook), hook._instance: chapter 06
  - drag, pointer, placeCanvas: chapter 05; a drag with the Rectangle tool from 100, 100 to
    300, 250 draws "rectangle 200 by 150 at 100, 100"
  - rect(), ellipse(): "rectangle 200 by 100 at 100, 100" and "ellipse 200 by 100 at 400, 300";
    rect() moved to 200, 200 reads "rectangle 200 by 100 at 200, 200", to 900, 600
    "rectangle 200 by 100 at 900, 600"
  - flushSync: runs pending effects now (chapter 03); createFakeLive: given

Picture: lessons/svg/13_resync.svg
*/
import { expect } from "vitest"
import { test } from "@koans/runtime"
import { flushSync, unmount } from "svelte"
import { fireEvent, render, screen } from "@testing-library/svelte"
import { getHooks } from "@koans/live_svelte_hooks"
import Board from "../svelte/Board.svelte"
import { BoardState } from "../js/board_state.svelte"
import { applyProps } from "../js/resync"
import type { Person, Shape } from "../js/types"
import { createFakeLive, type FakeLive } from "../test/support/fake_live"
import { drag, placeCanvas } from "../test/support/canvas"
import { ellipse, ID_A, ID_B, line, rect } from "../test/support/fixtures"

const ada: Person = { tab: "tab-ada", name: "Ada", color: "#e03131" }
const lin: Person = { tab: "tab-lin", name: "Lin", color: "#1971c2" }

type MountedHook = FakeLive & { el: HTMLElement; _instance?: { state: Record<string, unknown> } }

const described = (canvas: HTMLCanvasElement) =>
  [...canvas.querySelectorAll("li")].map((item) => item.textContent)

function mountBoard(live: FakeLive, shapes: Shape[]) {
  const view = render(Board, { shapes, sync_id: 1, me: ada, people: [ada], live })
  const canvas = screen.getByRole("group", { name: "Whiteboard" }).querySelector("canvas")
  if (!canvas) throw new Error("The Whiteboard group holds no canvas element")
  placeCanvas(canvas)
  return { ...view, canvas }
}

test("Implement applyProps, Board's resync. 1. When the props bring a sync_id other than the state's, replace every shape with the props' shapes and take that sync_id. 2. The same sync_id leaves the state alone, with whatever moved since.", () => {
  const state = new BoardState([rect({ x: 9, y: 9 }), line({ id: "local-only" })], 7)
  applyProps(state, { sync_id: 7, shapes: [rect()] })
  expect(state.shapes.get(ID_A)).toMatchObject({ x: 9, y: 9 })
  expect(state.shapes.size).toBe(2)

  applyProps(state, { sync_id: 3, shapes: [ellipse()] })
  expect([...state.shapes.keys()]).toEqual([ID_B])
  expect(state.syncId).toBe(3)
}, { exercises: "13: replace everything when sync_id changes" })

test("A reconnect keeps the Board the hook mounted: LiveView calls updated, not mounted, so the same component takes the fresh mount's props and swaps in its shapes, while a later update that sends only people keeps a pushed shape.", () => {
  const el = document.createElement("div")
  el.dataset.name = "Board"
  el.dataset.props = JSON.stringify({ shapes: [rect()], sync_id: 7, me: ada, people: [ada] })
  el.innerHTML = "<div data-svelte-target></div>"
  document.body.append(el)
  const hook: MountedHook = { el, ...createFakeLive() }
  const { SvelteHook } = getHooks({ default: [{ default: Board }], filenames: ["../svelte/Board.svelte"] })
  try {
    SvelteHook.mounted.call(hook)
    const mounted = hook._instance
    const canvas = el.querySelector("canvas")
    if (!canvas) throw new Error("The hook mounted no canvas")

    el.dataset.useDiff = "true"
    el.dataset.props = JSON.stringify({ shapes: [ellipse()], sync_id: 8, me: ada, people: [ada] })
    SvelteHook.updated.call(hook)
    flushSync()
    expect(hook._instance).toBe(mounted)
    expect(described(canvas)).toEqual(__)

    hook.emit("shape:added", rect())
    el.dataset.props = JSON.stringify({ people: [ada, lin] })
    SvelteHook.updated.call(hook)
    flushSync()
    expect(described(canvas)).toEqual(__)
  } finally {
    if (hook._instance) unmount(hook._instance)
    el.remove()
  }
}, { exercises: "13: replace everything when sync_id changes" })

test("A shape you draw shows before the server has answered, and its echo, shape:added with the server's z, replaces it by id instead of adding a second.", async () => {
  const live = createFakeLive()
  const { canvas, unmount } = mountBoard(live, [])
  try {
    await fireEvent.click(screen.getByRole("button", { name: "Rectangle" }))
    await drag(canvas, [100, 100], [300, 250])
    const [add] = live.pushed.filter((p) => p.event === "shape:add")
    expect(add.onReply).toBeTypeOf("function")
    expect(described(canvas)).toEqual(__)

    live.emit("shape:added", { ...add.payload, z: 0 })
    flushSync()
    expect(described(canvas).length).toBe(__)
  } finally {
    unmount()
  }
}, { exercises: "13: replace everything when sync_id changes" })

test("The last move the server applies wins everywhere: you drag the rect and the server says ok, but Lin's move, applied after yours, reaches you last and takes the rect from where you left it.", async () => {
  const live = createFakeLive()
  const { canvas, unmount } = mountBoard(live, [rect()])
  try {
    await drag(canvas, [150, 130], [250, 230])
    const [move] = live.pushed.filter((p) => p.event === "shape:move")
    move.onReply?.({ ok: true })
    live.emit("shape:moved", { id: ID_A, x: 200, y: 200 })
    flushSync()
    expect(described(canvas)).toEqual(["rectangle 200 by 100 at 200, 200"])

    live.emit("shape:moved", { id: ID_A, x: 900, y: 600 })
    flushSync()
    expect(described(canvas)).toEqual(__)
  } finally {
    unmount()
  }
}, { exercises: "13: replace everything when sync_id changes" })
