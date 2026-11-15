/*
Files this chapter touches
  - assets/js/cursors.ts: upsertCursor, pruneCursors, listenCursors
  - assets/svelte/CursorLayer.svelte: the cursor markup
  - lib/easel_web/live/board_live.ex (this chapter's Elixir koans)

Cursors follow the people here. From the Phoenix course (chapter 14, PubSub and Presence):
Presence tracks who is on a topic. BoardLive tracks one presence per tab, and the people prop
lists them as { tab, name, color }. A cursor:moved push, a CursorPayload, carries the same tab
with x and y, so when a tab's presence goes, so does its cursor.

Board holds the cursors in $state.raw as a ReadonlyMap from tab to payload, and a move makes a
new map rather than changing the old (chapter 04). new Map(old) copies a map, .set(key, value)
answers the map it changed, [...map] is its [key, value] pairs and new Map(pairs) builds one:

    const goals: ReadonlyMap<string, number> = new Map([["kim", 3]])
    const after = new Map(goals).set("kim", 4)

listenCursors(live, set) takes an updater setter: set(update) hands update the current map and
keeps what it returns, so the listener never holds a map from mount time. It returns a cleanup.

CursorLayer lays cursors over the canvas as elements. A keyed each block keeps one element per
tab, so a move changes only its style. The given visible holds the cursors of tabs still among
the people, and percent(400, 1600) is "25%" of the board. Markup the blank uses: per cursor a
div with class "cursor", data-tab={its tab}, style:left, style:top and
style:--cursor-color={its colour}, holding a span with the name; the given CSS draws the rest.

    Write:          assets/js/cursors.ts:9  (12: a new map with this tab's cursor set)
    Exercised by:   assets/koans/12_presence_and_cursors.test.ts:68

API you'll use
  - new Map, .set, .get: new Map(goals).set("lee", 1) is a copy with lee added; .get("lee") is 1
  - new Set, .has: new Set(["a"]).has("a") is true
  - [...map], .filter, .map: [...new Map([["a", 1]])] is [["a", 1]]; [1, 2].filter((n) => n > 1)
    is [2]; a callback can destructure a pair, ([key, value]) => ...
  - live.handleEvent, live.removeHandleEvent, isCursorPayload: chapter 10
  - each blocks, keyed: chapter 03's {#each people as person (person.tab)}
  - style:left={value}, style:--name={value}: set a style property or a CSS variable on one
    element; data-tab={tab} sets an attribute the koans read as element.dataset.tab
  - percent, visible, BOARD_WIDTH, BOARD_HEIGHT: given in CursorLayer.svelte
  - render, rerender: render(Component, props) mounts it; await rerender(props) swaps its props
  - createFakeLive: given; live.emit("cursor:moved", payload) plays a push
  - placeCanvas, pointer: chapter 05's helpers

Picture: lessons/svg/12_presence.svg
*/
import { expect } from "vitest"
import { test } from "@koans/runtime"
import { flushSync } from "svelte"
import { render, screen } from "@testing-library/svelte"
import Board from "../svelte/Board.svelte"
import CursorLayer from "../svelte/CursorLayer.svelte"
import { listenCursors, pruneCursors, upsertCursor, type Cursors } from "../js/cursors"
import type { BoardProps, CursorPayload, Person } from "../js/types"
import { createFakeLive, type FakeLive } from "../test/support/fake_live"
import { placeCanvas, pointer } from "../test/support/canvas"

const ada: Person = { tab: "tab-ada", name: "Ada", color: "#e03131" }
const lin: Person = { tab: "tab-lin", name: "Lin", color: "#1971c2" }
const kim: Person = { tab: "tab-kim", name: "Kim", color: "#2f9e44" }

const at = (person: Person, x: number, y: number): CursorPayload => ({ ...person, x, y })
const cursorsOf = (...payloads: CursorPayload[]): Cursors =>
  new Map(payloads.map((payload) => [payload.tab, payload]))
const cursorOf = (container: HTMLElement, tab: string) =>
  container.querySelector<HTMLElement>(`[data-tab="${tab}"]`)

test("Implement upsertCursor, which answers a new map with this payload under its tab, adding a tab or replacing its last position, and leaves the old map as it was.", () => {
  const empty: Cursors = new Map()
  const one = upsertCursor(empty, at(lin, 1, 2))
  const moved = upsertCursor(one, at(lin, 50, 60))
  const two = upsertCursor(moved, at(kim, 3, 4))

  expect(empty.size).toBe(0)
  expect(one.get("tab-lin")).toEqual({ tab: "tab-lin", name: "Lin", color: "#1971c2", x: 1, y: 2 })
  expect(moved.get("tab-lin")).toEqual({ tab: "tab-lin", name: "Lin", color: "#1971c2", x: 50, y: 60 })
  expect([...two.keys()]).toEqual(["tab-lin", "tab-kim"])
  expect(moved.size).toBe(1)
})

test("Implement pruneCursors, which keeps, in a new map, only the cursors whose tab is still among the people, so a tab that leaves takes its cursor with it.", () => {
  const cursors = cursorsOf(at(lin, 1, 1), at(kim, 2, 2))
  const linAgain: Person = { ...lin, tab: "tab-lin-2" }

  expect([...pruneCursors(cursors, [ada, kim]).keys()]).toEqual(["tab-kim"])
  expect([...pruneCursors(cursors, [linAgain]).keys()]).toEqual([])
  expect([...pruneCursors(cursors, [kim, lin]).keys()].sort()).toEqual(["tab-kim", "tab-lin"])
  expect(cursors.size).toBe(2)
})

test("Implement listenCursors. 1. live.handleEvent cursor:moved with a callback that, for a payload isCursorPayload accepts, calls set with an update that upserts it. 2. Return a function that removes the listener.", () => {
  const live = createFakeLive()
  let cursors: Cursors = new Map()
  const stop = listenCursors(live, (update) => (cursors = update(cursors)))
  expect(live.listenerCount("cursor:moved")).toBe(1)

  live.emit("cursor:moved", at(lin, 4, 5))
  live.emit("cursor:moved", { tab: "tab-kim", x: 1 })
  live.emit("cursor:moved", at(lin, 6, 7))
  expect([...cursors.values()]).toEqual([{ tab: "tab-lin", name: "Lin", color: "#1971c2", x: 6, y: 7 }])

  stop()
  expect(live.listenerCount("cursor:moved")).toBe(0)
  live.emit("cursor:moved", at(kim, 1, 1))
  expect(cursors.size).toBe(1)
}, { exercises: "12: listen for cursor:moved, and stop" })

test("Fill CursorLayer's markup: an element per cursor, keyed by tab, with the tab in data-tab, placed at x and y as percentages of the board, coloured through --cursor-color and labelled with the name.", () => {
  const { container } = render(CursorLayer, { cursors: cursorsOf(at(lin, 400, 500)), people: [lin] })
  const cursor = cursorOf(container, "tab-lin")

  expect(cursor?.classList.contains("cursor")).toBe(true)
  expect(cursor?.style.left).toBe("25%")
  expect(cursor?.style.top).toBe("50%")
  expect(cursor?.style.getPropertyValue("--cursor-color")).toBe("#1971c2")
  expect(cursor?.textContent?.trim()).toBe("Lin")
  expect(screen.getByText("Lin").tagName).toBe("SPAN")
}, { exercises: "12: a labelled cursor per tab" })

test("A cursor shows only while its tab is among the people, and a move keeps the same element, since the each block is keyed by tab.", async () => {
  const { container, rerender } = render(CursorLayer, {
    cursors: cursorsOf(at(lin, 0, 0), at(kim, 0, 0)),
    people: [lin, kim],
  })
  const before = cursorOf(container, "tab-kim")
  expect(before).not.toBeNull()

  await rerender({ cursors: cursorsOf(at(lin, 0, 0), at(kim, 160, 100)), people: [kim] })
  expect(cursorOf(container, "tab-lin")).toBeNull()
  expect(cursorOf(container, "tab-kim")).toBe(before)
  expect(cursorOf(container, "tab-kim")?.style.left).toBe("10%")
}, { exercises: "12: a labelled cursor per tab" })

test("On the Board, Lin's pushed cursor shows over the canvas and goes when she leaves the people, and moving my own pointer pushes cursor:move.", async () => {
  const live = createFakeLive()
  const props: BoardProps = { shapes: [], sync_id: 1, me: ada, people: [ada, lin], live }
  const { container, rerender, unmount } = render(Board, props)
  const canvas = screen.getByRole("group", { name: "Whiteboard" }).querySelector("canvas")
  if (!canvas) throw new Error("The Whiteboard group holds no canvas element")
  placeCanvas(canvas)
  try {
    live.emit("cursor:moved", at(lin, 400, 500))
    flushSync()
    expect(cursorOf(container, "tab-lin")?.textContent?.trim()).toBe("Lin")

    await pointer(canvas, "pointerMove", 800, 250)
    expect(cursorMoves(live)).toEqual([{ x: 800, y: 250 }])

    await rerender({ ...props, people: [ada] })
    expect(cursorOf(container, "tab-lin")).toBeNull()
  } finally {
    unmount()
  }
}, { exercises: ["12: listen for cursor:moved, and stop", "12: a labelled cursor per tab"] })

function cursorMoves(live: FakeLive) {
  return live.pushed.filter((p) => p.event === "cursor:move").map((p) => p.payload)
}
