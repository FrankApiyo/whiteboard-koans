import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { BoardState } from "../js/board_state.svelte"
import { makeCursorSender, onReply, sendAdd, sendDelete, sendMove } from "../js/outbox"
import { createFakeLive } from "./support/fake_live"
import { ellipse, ID_A, rect } from "./support/fixtures"

describe("sendAdd", () => {
  it("shows the shape locally and pushes shape:add", () => {
    const live = createFakeLive()
    const state = new BoardState([], 1)
    sendAdd(live, state, rect())
    expect(state.shapes.get(ID_A)).toEqual(rect())
    expect(live.pushed[0]).toMatchObject({ event: "shape:add", payload: rect() })
  })
})

describe("sendMove", () => {
  it("moves locally and pushes shape:move with only id and position", () => {
    const live = createFakeLive()
    const state = new BoardState([rect()], 1)
    sendMove(live, state, ID_A, 5, 6)
    expect(state.shapes.get(ID_A)).toMatchObject({ x: 5, y: 6 })
    expect(live.pushed[0]).toMatchObject({ event: "shape:move", payload: { id: ID_A, x: 5, y: 6 } })
  })

  it("rolls back to the given shape when the move was already shown locally", () => {
    const live = createFakeLive()
    const state = new BoardState([rect({ x: 300 })], 1)
    sendMove(live, state, ID_A, 300, 100, rect())
    live.pushed[0].onReply?.("garbage")
    expect(state.shapes.get(ID_A)).toEqual(rect())
  })
})

describe("sendDelete", () => {
  it("removes locally and pushes shape:delete", () => {
    const live = createFakeLive()
    const state = new BoardState([rect()], 1)
    sendDelete(live, state, ID_A)
    expect(state.shapes.size).toBe(0)
    expect(live.pushed[0]).toMatchObject({ event: "shape:delete", payload: { id: ID_A } })
  })
})

describe("replies", () => {
  it("reply_ok_false_restores_server_shape_or_removes_local", () => {
    const live = createFakeLive()
    const state = new BoardState([rect()], 1)

    sendMove(live, state, ID_A, 900, 900)
    live.pushed[0].onReply?.({ ok: false, shape: rect({ x: 42 }) })
    expect(state.shapes.get(ID_A)).toEqual(rect({ x: 42 }))

    sendAdd(live, state, ellipse())
    live.pushed[1].onReply?.({ ok: false, shape: null })
    expect(state.shapes.has(ellipse().id)).toBe(false)
  })

  it("an ok reply leaves the optimistic state alone", () => {
    const live = createFakeLive()
    const state = new BoardState([rect()], 1)
    sendMove(live, state, ID_A, 7, 8)
    live.pushed[0].onReply?.({ ok: true })
    expect(state.shapes.get(ID_A)).toMatchObject({ x: 7, y: 8 })
  })

  it("a malformed reply rolls back to the shape from before", () => {
    const state = new BoardState([rect({ x: 7 })], 1)
    onReply(state, ID_A, rect())("garbage")
    expect(state.shapes.get(ID_A)).toEqual(rect())
    onReply(state, ID_A, null)(undefined)
    expect(state.shapes.has(ID_A)).toBe(false)
  })
})

describe("makeCursorSender", () => {
  beforeEach(() => vi.useFakeTimers())
  afterEach(() => vi.useRealTimers())

  it("pushes cursor:move at most once per interval, trailing last", () => {
    const live = createFakeLive()
    const send = makeCursorSender(live, 50)
    send({ x: 1, y: 1 })
    send({ x: 2, y: 2 })
    send({ x: 3, y: 3 })
    expect(live.pushed.map((p) => p.payload)).toEqual([{ x: 1, y: 1 }])
    vi.advanceTimersByTime(50)
    expect(live.pushed.map((p) => p.payload)).toEqual([{ x: 1, y: 1 }, { x: 3, y: 3 }])
    expect(live.pushed.every((p) => p.event === "cursor:move")).toBe(true)
  })

  it("rounds coordinates to integers", () => {
    const live = createFakeLive()
    makeCursorSender(live)({ x: 1.6, y: 2.4 })
    expect(live.pushed[0].payload).toEqual({ x: 2, y: 2 })
  })

  it("cancel drops a held trailing push", () => {
    const live = createFakeLive()
    const send = makeCursorSender(live, 50)
    send({ x: 1, y: 1 })
    send({ x: 2, y: 2 })
    send.cancel()
    vi.advanceTimersByTime(100)
    expect(live.pushed).toHaveLength(1)
  })
})
