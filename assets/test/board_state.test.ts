import { describe, expect, it } from "vitest"
import { BoardState } from "../js/board_state.svelte"
import { PALETTE } from "../js/types"
import { ellipse, ID_A, ID_B, rect } from "./support/fixtures"

describe("BoardState", () => {
  it("starts from shapes and a sync id with defaults for the rest", () => {
    const state = new BoardState([rect()], 7)
    expect(state.syncId).toBe(7)
    expect(state.shapes.get(ID_A)).toEqual(rect())
    expect([state.selectedId, state.tool, state.draggingId]).toEqual([null, "select", null])
    expect(state.color).toBe(PALETTE[0])
  })

  it("upsert adds, then replaces by id, without mutating the old map", () => {
    const state = new BoardState([], 1)
    const before = state.shapes
    state.upsert(rect())
    state.upsert(rect({ x: 9 }))
    expect(before.size).toBe(0)
    expect(state.shapes.size).toBe(1)
    expect(state.shapes.get(ID_A)?.x).toBe(9)
  })

  it("remove drops the shape and clears a selection pointing at it", () => {
    const state = new BoardState([rect()], 1)
    state.selectedId = ID_A
    state.remove(ID_A)
    expect(state.shapes.size).toBe(0)
    expect(state.selectedId).toBeNull()
  })

  it("remove of an unknown id changes nothing", () => {
    const state = new BoardState([rect()], 1)
    const before = state.shapes
    state.remove(ID_B)
    expect(state.shapes).toBe(before)
  })

  it("moveShape moves a known shape and ignores an unknown id", () => {
    const state = new BoardState([rect()], 1)
    const before = state.shapes
    state.moveShape(ID_A, 3, 4)
    expect(state.shapes.get(ID_A)).toMatchObject({ x: 3, y: 4 })
    expect(before.get(ID_A)).toMatchObject({ x: 100, y: 100 })
    const after = state.shapes
    state.moveShape(ID_B, 1, 1)
    expect(state.shapes).toBe(after)
  })

  it("replaceAll swaps the map and the sync id", () => {
    const state = new BoardState([rect()], 1)
    state.replaceAll([ellipse()], 2)
    expect([...state.shapes.keys()]).toEqual([ID_B])
    expect(state.syncId).toBe(2)
  })

  it("ordered puts shapes by z, local shapes without z last", () => {
    const state = new BoardState([rect({ id: ID_A, z: 5 }), ellipse({ id: ID_B, z: 1 })], 1)
    state.upsert(rect({ id: "local" }))
    expect(state.ordered().map((s) => s.id)).toEqual([ID_B, ID_A, "local"])
  })

  it("snapshot is a plain array copy in map order", () => {
    const state = new BoardState([rect(), ellipse()], 1)
    const copy = state.snapshot()
    expect(copy.map((s) => s.id)).toEqual([ID_A, ID_B])
    copy.pop()
    expect(state.shapes.size).toBe(2)
  })
})
