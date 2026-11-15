import { describe, expect, it } from "vitest"
import { BoardState } from "../js/board_state.svelte"
import { applyIncoming, listen } from "../js/inbox"
import { createFakeLive } from "./support/fake_live"
import { ellipse, ID_A, ID_B, rect } from "./support/fixtures"

describe("applyIncoming", () => {
  it("shape:added upserts, shape:moved moves, shape:deleted removes", () => {
    const state = new BoardState([], 1)
    applyIncoming(state, "shape:added", rect({ z: 0 }))
    expect(state.shapes.get(ID_A)).toMatchObject({ z: 0 })
    applyIncoming(state, "shape:moved", { id: ID_A, x: 9, y: 8 })
    expect(state.shapes.get(ID_A)).toMatchObject({ x: 9, y: 8 })
    applyIncoming(state, "shape:deleted", { id: ID_A })
    expect(state.shapes.size).toBe(0)
  })

  it("incoming_ops_for_the_dragged_shape_are_ignored", () => {
    const state = new BoardState([rect()], 1)
    state.draggingId = ID_A
    applyIncoming(state, "shape:moved", { id: ID_A, x: 1, y: 1 })
    applyIncoming(state, "shape:deleted", { id: ID_A })
    applyIncoming(state, "shape:added", rect({ x: 5 }))
    expect(state.shapes.get(ID_A)).toEqual(rect())
    applyIncoming(state, "shape:added", ellipse({ id: ID_B }))
    expect(state.shapes.has(ID_B)).toBe(true)
  })

  it("ignores malformed payloads and unknown events", () => {
    const state = new BoardState([rect()], 1)
    const before = state.shapes
    applyIncoming(state, "shape:added", { kind: "star" })
    applyIncoming(state, "shape:moved", { id: ID_A })
    applyIncoming(state, "shape:deleted", null)
    applyIncoming(state, "shape:exploded", { id: ID_A })
    expect(state.shapes).toBe(before)
  })
})

describe("listen", () => {
  it("applies events the server pushes", () => {
    const live = createFakeLive()
    const state = new BoardState([], 1)
    listen(live, state)
    live.emit("shape:added", rect())
    expect(state.shapes.has(ID_A)).toBe(true)
  })

  it("returns a function that removes every listener", () => {
    const live = createFakeLive()
    const state = new BoardState([], 1)
    const stop = listen(live, state)
    expect(live.listenerCount("shape:added")).toBe(1)
    stop()
    for (const event of ["shape:added", "shape:moved", "shape:deleted"]) {
      expect(live.listenerCount(event)).toBe(0)
    }
    live.emit("shape:added", rect())
    expect(state.shapes.size).toBe(0)
  })
})
