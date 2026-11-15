import { flushSync } from "svelte"
import { describe, expect, it } from "vitest"
import { BoardState } from "../js/board_state.svelte"
import { ID_A, rect } from "./support/fixtures"

function watchSize(state: BoardState): { seen: number[]; stop: () => void } {
  const seen: number[] = []
  const stop = $effect.root(() => {
    $effect(() => {
      seen.push(state.shapes.size)
    })
  })
  flushSync()
  return { seen, stop }
}

describe("BoardState reactivity", () => {
  it("replacing shapes re-runs effects that read them", () => {
    const state = new BoardState([], 1)
    const { seen, stop } = watchSize(state)
    state.upsert(rect())
    flushSync()
    state.remove(ID_A)
    flushSync()
    stop()
    expect(seen).toEqual([0, 1, 0])
  })

  it("mutating the stored map in place is invisible to effects", () => {
    const state = new BoardState([], 1)
    const { seen, stop } = watchSize(state)
    ;(state.shapes as Map<string, ReturnType<typeof rect>>).set(ID_A, rect())
    flushSync()
    stop()
    expect(seen).toEqual([0])
  })
})
