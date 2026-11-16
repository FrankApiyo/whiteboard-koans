/*
Files this chapter touches
  - assets/js/payloads.ts: isMovePayload, isDeletePayload, isCursorPayload
  - assets/js/inbox.ts: applyIncoming, listen
  - lib/easel_web/live/board_live.ex (this chapter's Elixir koans)

Server to browser. From the Phoenix course: handle_info/2 takes
messages from other processes (chapter 14, PubSub and Presence). BoardLive's handle_info/2
turns each board op into push_event(socket, event, payload). In the browser LiveView fires it
on window as phx:<event>, and live.handleEvent(event, callback) listens there; handleEvent
returns a ref, and live.removeHandleEvent(ref) stops that one listener. LiveView drops a hook's
listeners when the hook goes, but a component can't know a hook mounted it (the koans mount
Board straight), so Board's onMount returns a cleanup that removes its own.
Easel's event names say the direction: the browser asks in the present (shape:add,
cursor:move); the server reports in the past (shape:added, cursor:moved).

Each push carries whole values: shape:added the full shape, shape:moved the id with the new x
and y, shape:deleted the id. Payloads arrive as unknown, so a guard checks each one first.
Applying is by id: a repeat is harmless and an unknown id does nothing. Every browser applies
every op, its own included, so all end in the server's order. The shape this browser is
dragging, its draggingId, ignores incoming ops: the drag's own pointer up has the last word.
Props and events split the work: props seed Board and replace everything on a resync (chapter
13), events change one shape at a time and never touch the props.

    function listenForBell(live: Live, ring: () => void): () => void {
      const ref = live.handleEvent("bell", () => ring())
      return () => live.removeHandleEvent(ref)
    }

    Write:          assets/js/payloads.ts:46  (10: a move payload)
    Exercised by:   assets/koans/10_server_to_client.test.ts:74

API you'll use
  - live.handleEvent: live.handleEvent("bell", (payload) => ring(payload)) is a ref
  - live.removeHandleEvent: live.removeHandleEvent(ref) removes that listener
  - .map, .forEach: ["a", "b"].map((s) => s.length) is [1, 1]; xs.forEach(f) calls f on each
  - switch on a string: case "bell": runs for that value only; return leaves the function
  - isRecord, isString, isColor, isFiniteNumber: chapter 01; isShape: chapter 09
  - hasNumbers: hasNumbers(value, ["w", "h"]) is true when each key holds a finite number
  - state.upsert, state.moveShape, state.remove, state.draggingId: chapter 04's BoardState
  - createFakeLive: given; live.emit(event, payload) plays a push, and
    live.listenerCount(event) is 1 while Board listens for that event and 0 once it is gone
  - drag, pointer: chapter 05's helpers; rect() is ID_A at x 100, y 100, 200 by 100

Picture: lessons/svg/10_push_and_listen.svg
*/
import { expect } from "vitest"
import { test } from "@koans/runtime"
import { flushSync } from "svelte"
import { render, screen } from "@testing-library/svelte"
import Board from "../svelte/Board.svelte"
import { BoardState } from "../js/board_state.svelte"
import { applyIncoming, listen } from "../js/inbox"
import { isCursorPayload, isDeletePayload, isMovePayload } from "../js/payloads"
import type { Person } from "../js/types"
import { createFakeLive, type FakeLive } from "../test/support/fake_live"
import { placeCanvas, pointer } from "../test/support/canvas"
import { ellipse, ID_A, ID_B, rect } from "../test/support/fixtures"

const ada: Person = { tab: "tab-ada", name: "Ada", color: "#e03131" }
const SHAPE_EVENTS = ["shape:added", "shape:moved", "shape:deleted"]

const listening = (live: FakeLive) => SHAPE_EVENTS.map((event) => live.listenerCount(event))

function mountBoard(live: FakeLive) {
  const view = render(Board, { shapes: [rect()], sync_id: 1, me: ada, people: [ada], live })
  const canvas = screen.getByRole("group", { name: "Whiteboard" }).querySelector("canvas")
  if (!canvas) throw new Error("The Whiteboard group holds no canvas element")
  placeCanvas(canvas)
  const described = () => [...canvas.querySelectorAll("li")].map((item) => item.textContent)
  return { ...view, canvas, described }
}

test("Implement isMovePayload and isDeletePayload, the guards for the shape:moved and shape:deleted pushes. 1. A move payload is a record with a string id and finite x and y. 2. A delete payload is a record with a string id.", () => {
  expect(isMovePayload({ id: ID_A, x: 1, y: 2 })).toBe(true)
  expect(isMovePayload({ id: 7, x: 1, y: 2 })).toBe(false)
  expect(isMovePayload({ id: ID_A, x: "1", y: 2 })).toBe(false)
  expect(isMovePayload({ id: ID_A, x: 1 })).toBe(false)
  expect(isMovePayload(null)).toBe(false)
  expect(isDeletePayload({ id: ID_A })).toBe(true)
  expect(isDeletePayload({ id: null })).toBe(false)
  expect(isDeletePayload(ID_A)).toBe(false)
})

test("Implement isCursorPayload, the guard for the cursor:moved push: a record with a string tab and name, a palette colour, and finite x and y.", () => {
  const cursor = { tab: "tab-lin", name: "Lin", color: "#1971c2", x: 4, y: 5 }
  expect(isCursorPayload(cursor)).toBe(true)
  expect(isCursorPayload({ ...cursor, tab: undefined })).toBe(false)
  expect(isCursorPayload({ ...cursor, name: 3 })).toBe(false)
  expect(isCursorPayload({ ...cursor, color: "red" })).toBe(false)
  expect(isCursorPayload({ ...cursor, x: Number.POSITIVE_INFINITY })).toBe(false)
  expect(isCursorPayload({ ...cursor, y: "5" })).toBe(false)
  expect(isCursorPayload("tab-lin")).toBe(false)
})

test("Implement applyIncoming, which applies one push to the board. 1. Switch on the event. 2. shape:added upserts the shape, shape:moved moves by id, shape:deleted removes by id, each only when its guard passes. 3. Skip any op for state.draggingId, and an unknown event.", () => {
  const state = new BoardState([], 1)
  applyIncoming(state, "shape:added", rect({ z: 0 }))
  expect(state.shapes.get(ID_A)).toEqual(rect({ z: 0 }))
  applyIncoming(state, "shape:moved", { id: ID_A, x: 9, y: 8 })
  expect(state.shapes.get(ID_A)).toMatchObject({ x: 9, y: 8 })
  applyIncoming(state, "shape:deleted", { id: ID_A })
  expect(state.shapes.size).toBe(0)

  const kept = new BoardState([rect()], 1)
  const before = kept.shapes
  applyIncoming(kept, "shape:added", { kind: "star", id: ID_B })
  applyIncoming(kept, "shape:moved", { id: ID_A, x: 9 })
  applyIncoming(kept, "shape:deleted", null)
  applyIncoming(kept, "shape:exploded", { id: ID_A })
  expect(kept.shapes).toBe(before)

  kept.draggingId = ID_A
  applyIncoming(kept, "shape:moved", { id: ID_A, x: 1, y: 1 })
  applyIncoming(kept, "shape:added", rect({ x: 5 }))
  applyIncoming(kept, "shape:deleted", { id: ID_A })
  expect(kept.shapes.get(ID_A)).toEqual(rect())
  applyIncoming(kept, "shape:added", ellipse())
  expect(kept.shapes.has(ID_B)).toBe(true)
})

test("Implement listen so the board hears the three shape pushes until it stops. 1. live.handleEvent each event with a callback that applies its payload, and keep the refs. 2. Return a function that removes each listener by its ref.", () => {
  const live = createFakeLive()
  const state = new BoardState([], 1)
  const stop = listen(live, state)

  expect(listening(live)).toEqual([1, 1, 1])
  live.emit("shape:added", rect())
  live.emit("shape:moved", { id: ID_A, x: 7, y: 8 })
  expect(state.shapes.get(ID_A)).toMatchObject({ x: 7, y: 8 })
  live.emit("shape:deleted", { id: ID_A })
  expect(state.shapes.has(ID_A)).toBe(false)

  stop()
  expect(listening(live)).toEqual([0, 0, 0])
  live.emit("shape:added", ellipse())
  expect(state.shapes.size).toBe(0)
}, { exercises: "10: handle the three shape events, and stop" })

test("On the Board, another viewer's shape arrives as a push and is drawn, while a push about the shape being dragged is ignored, the drag's own move goes to the server on pointer up, and a malformed reply puts it back where the drag began.", async () => {
  const live = createFakeLive()
  const { canvas, described, unmount } = mountBoard(live)
  try {
    live.emit("shape:added", ellipse())
    flushSync()
    expect(described()).toEqual(["rectangle 200 by 100 at 100, 100", "ellipse 200 by 100 at 400, 300"])

    await pointer(canvas, "pointerDown", 150, 130)
    await pointer(canvas, "pointerMove", 250, 230)
    live.emit("shape:moved", { id: ID_A, x: 900, y: 900 })
    flushSync()
    expect(described()[0]).toBe("rectangle 200 by 100 at 200, 200")

    await pointer(canvas, "pointerUp", 250, 230)
    const moves = live.pushed.filter((p) => p.event === "shape:move")
    expect(moves.map((p) => p.payload)).toEqual([{ id: ID_A, x: 200, y: 200 }])

    moves[0].onReply?.(null)
    flushSync()
    expect(described()[0]).toBe("rectangle 200 by 100 at 100, 100")
  } finally {
    unmount()
  }
}, { exercises: "10: handle the three shape events, and stop" })

test("Board's cleanup removes its shape listeners when it unmounts.", () => {
  const live = createFakeLive()
  const { unmount } = mountBoard(live)
  let mounted = true
  try {
    expect(live.listenerCount("shape:added")).toBe(_a(1))
    unmount()
    mounted = false
    expect(live.listenerCount("shape:added")).toBe(_a(0))
  } finally {
    if (mounted) unmount()
  }
}, { exercises: "10: handle the three shape events, and stop" })
