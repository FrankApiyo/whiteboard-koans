/*
Files this chapter touches
  - assets/js/payloads.ts: isShape, isReply
  - assets/js/outbox.ts: onReply, sendAdd, sendMove, sendDelete
  - lib/easel_web/live/board_live.ex (this chapter's Elixir koans)
  - lib/easel/shapes.ex (this chapter's Elixir koans)

Browser to server and back. From the Phoenix course:
handle_event/3 runs for each event the browser sends (chapter 10, LiveView basics), and a
changeset checks data from outside (chapter 04). Here code sends the event, not a form:
live.pushEvent(event, payload, onReply) pushes it, and the server's {:reply, map, socket}
arrives as the handler's first argument. JSON carries no types, so the reply is unknown.

Easel draws first and asks second. sendAdd, sendMove and sendDelete change BoardState at once,
then push the change with a handler from onReply. The server answers { ok: true }, or
{ ok: false, shape } with its copy, or shape null when it has none; the handler keeps the
change, puts the server's copy back, or removes the shape. Anything else rolls back to before,
the shape as it was, or nothing for an add: a clause that answers {:noreply, socket} reaches
the handler as null. A push that fails or times out never calls it; on a timeout LiveView
reloads the page. A drag passes the shape from before the drag as sendMove's before.

A guard turns unknown into a type: once isReply passes, reply.ok and reply.shape type-check.
One for a note that may carry a page number:

    function isNote(value: unknown): value is Note {
      if (!isRecord(value)) return false
      return isString(value.text) && (value.page === undefined || isFiniteNumber(value.page))
    }

    Write:          assets/js/payloads.ts:40  (09: the fields every kind shares)
    Exercised by:   assets/koans/09_client_to_server.test.ts:66

API you'll use
  - live.pushEvent: live.pushEvent("vote", { choice: 2 }, (reply) => tally(reply)) sends an
    event and later calls the handler with the server's reply
  - isRecord, isString, isColor, isFiniteNumber: chapter 01's guards
  - hasNumbers: hasNumbers(value, ["w", "h"]), given in payloads.ts, is true when each key
    holds a finite number
  - state.upsert, state.moveShape, state.remove: chapter 04's BoardState; state.shapes.get(id)
    is the shape with that id or undefined
  - onReply: onReply(state, id, before) is the reply handler for a change to shape id
  - createFakeLive: given; live.pushed lists each push as { event, payload, onReply }
  - fireEvent.click, drag, pointer: press a toolbar button; chapter 05's pointer helpers
  - rect, ellipse: the fixtures; rect() is ID_A at x 100, y 100, 200 by 100, and rect({ x: 42 })
    the same rect at x 42; ellipse() is ID_B

Picture: lessons/svg/09_round_trip.svg
*/
import { expect } from "vitest"
import { test } from "@koans/runtime"
import { flushSync } from "svelte"
import { fireEvent, render, screen } from "@testing-library/svelte"
import Board from "../svelte/Board.svelte"
import { BoardState } from "../js/board_state.svelte"
import { onReply, sendAdd, sendMove } from "../js/outbox"
import { isReply, isShape } from "../js/payloads"
import type { Person, Shape } from "../js/types"
import { createFakeLive, type FakeLive } from "../test/support/fake_live"
import { drag, placeCanvas, pointer } from "../test/support/canvas"
import { ellipse, ID_A, ID_B, rect } from "../test/support/fixtures"

const ada: Person = { tab: "tab-ada", name: "Ada", color: "#e03131" }

const shapePushes = (live: FakeLive) => live.pushed.filter((p) => p.event.startsWith("shape:"))

test("Finish isShape, the guard for a shape that came over the wire: besides the kind's own fields, which the given line above the blank checks, it needs a string id, a palette colour, finite x and y, and a z that is missing or a finite number.", () => {
  expect(isShape(rect())).toBe(true)
  expect(isShape(rect({ z: 3 }))).toBe(true)
  expect(isShape({ ...rect(), z: "3" })).toBe(false)
  expect(isShape({ ...rect(), id: 7 })).toBe(false)
  expect(isShape({ ...rect(), color: "#000000" })).toBe(false)
  expect(isShape({ ...rect(), x: Number.NaN })).toBe(false)
  expect(isShape({ ...rect(), y: "100" })).toBe(false)
  expect(isShape({ ...rect(), w: undefined })).toBe(false)
})

test("Implement isReply so only the replies the server sends pass: ok true, or ok false with a shape that passes isShape or with null. A missing shape, a bad shape, an ok that is not a boolean or a bare string is no reply.", () => {
  expect(isReply({ ok: true })).toBe(true)
  expect(isReply({ ok: false, shape: null })).toBe(true)
  expect(isReply({ ok: false, shape: rect() })).toBe(true)
  expect(isReply({ ok: false })).toBe(false)
  expect(isReply({ ok: false, shape: { kind: "star" } })).toBe(false)
  expect(isReply({ ok: "yes" })).toBe(false)
  expect(isReply("timeout")).toBe(false)
  expect(isReply(null)).toBe(false)
})

test("Implement the handler onReply returns. 1. An ok reply keeps the local change. 2. A refusal puts the server's shape back, or removes the shape when the server has none. 3. Anything that is not a reply rolls back to before, or removes the shape when before is null.", () => {
  const state = new BoardState([rect({ x: 300 })], 1)

  onReply(state, ID_A, rect())({ ok: true })
  expect(state.shapes.get(ID_A)?.x).toBe(300)
  onReply(state, ID_A, rect())({ ok: false, shape: rect({ x: 42 }) })
  expect(state.shapes.get(ID_A)?.x).toBe(42)
  onReply(state, ID_A, rect())(null)
  expect(state.shapes.get(ID_A)?.x).toBe(100)
  onReply(state, ID_A, rect())({ ok: false, shape: null })
  expect(state.shapes.has(ID_A)).toBe(false)

  state.upsert(ellipse())
  onReply(state, ID_B, null)({ oops: 1 })
  expect(state.shapes.has(ID_B)).toBe(false)
})

test("Implement sendAdd so a new shape shows at once and the server hears about it. 1. Upsert the shape into the state. 2. Push shape:add with the whole shape as the payload and onReply's handler for its id, with nothing to roll back to.", () => {
  const live = createFakeLive()
  const state = new BoardState([], 1)

  sendAdd(live, state, ellipse())
  expect(state.shapes.get(ID_B)).toEqual(ellipse())
  expect(live.pushed.map((p) => p.event)).toEqual(["shape:add"])
  expect(live.pushed[0].payload).toEqual(ellipse())

  live.pushed[0].onReply?.(null)
  expect(state.shapes.has(ID_B)).toBe(false)
})

test("Implement sendMove: move the shape now, then push shape:move with only id, x and y and a handler that rolls back to before. A drag passes before; a call without it rolls back to the shape as the state held it.", () => {
  const live = createFakeLive()
  const dragged = new BoardState([rect({ x: 300, y: 200 })], 1)

  sendMove(live, dragged, ID_A, 320, 210, rect())
  expect(dragged.shapes.get(ID_A)).toMatchObject({ x: 320, y: 210 })
  expect(live.pushed[0].event).toBe("shape:move")
  expect(live.pushed[0].payload).toEqual({ id: ID_A, x: 320, y: 210 })
  live.pushed[0].onReply?.(null)
  expect(dragged.shapes.get(ID_A)?.x).toBe(100)

  const still = new BoardState([rect()], 1)
  sendMove(live, still, ID_A, 5, 6)
  live.pushed[1].onReply?.(null)
  expect(still.shapes.get(ID_A)?.x).toBe(100)
})

test("Implement sendDelete so a shape disappears at once and the server hears shape:delete with just its id, and a malformed reply brings it back. On the Board, drawing a rectangle pushes shape:add and selecting it and pressing Delete pushes shape:delete, so Board passes commit to the canvas and deleteSelected to the toolbar.", async () => {
  const live = createFakeLive()
  const { unmount } = render(Board, { shapes: [], sync_id: 1, me: ada, people: [ada], live })
  const canvas = screen.getByRole("group", { name: "Whiteboard" }).querySelector("canvas")
  if (!canvas) throw new Error("The Whiteboard group holds no canvas element")
  placeCanvas(canvas)
  const described = () => [...canvas.querySelectorAll("li")].map((item) => item.textContent)
  try {
    await fireEvent.click(screen.getByRole("button", { name: "Rectangle" }))
    await drag(canvas, [100, 100], [300, 250])
    const [add] = shapePushes(live)
    expect(add.event).toBe("shape:add")
    expect(add.payload).toMatchObject({ kind: "rect", x: 100, y: 100, w: 200, h: 150 })

    await fireEvent.click(screen.getByRole("button", { name: "Select" }))
    await pointer(canvas, "pointerDown", 150, 130)
    await pointer(canvas, "pointerUp", 150, 130)
    await fireEvent.click(screen.getByRole("button", { name: "Delete" }))
    const pushes = shapePushes(live)
    expect(pushes.map((p) => p.event)).toEqual(["shape:add", "shape:delete"])
    expect(pushes[1].payload).toEqual({ id: (add.payload as Shape).id })
    expect(described()).toEqual([])

    pushes[1].onReply?.(null)
    flushSync()
    expect(described()).toEqual(["rectangle 200 by 150 at 100, 100"])
  } finally {
    unmount()
  }
}, { exercises: ["09: draw it now, push shape:add", "09: remove it now, push shape:delete"] })
