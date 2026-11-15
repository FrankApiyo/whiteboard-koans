import { describe, expect, it } from "vitest"
import { BoardState } from "../js/board_state.svelte"
import { applyProps } from "../js/resync"
import { ellipse, ID_A, ID_B, rect } from "./support/fixtures"

describe("applyProps", () => {
  it("new_sync_id_replaces_the_whole_map", () => {
    const state = new BoardState([rect()], 1)
    applyProps(state, { sync_id: 2, shapes: [ellipse()] })
    expect([...state.shapes.keys()]).toEqual([ID_B])
    expect(state.syncId).toBe(2)
  })

  it("the same sync id leaves live state alone", () => {
    const state = new BoardState([rect()], 1)
    state.moveShape(ID_A, 9, 9)
    applyProps(state, { sync_id: 1, shapes: [rect()] })
    expect(state.shapes.get(ID_A)).toMatchObject({ x: 9, y: 9 })
  })
})
