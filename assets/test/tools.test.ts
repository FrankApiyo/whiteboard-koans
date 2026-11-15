import { describe, expect, it } from "vitest"
import { dragTarget, pointerDown, pointerMove, pointerUp, type ToolState } from "../js/tools"
import { MAX_PEN_POINTS } from "../js/types"
import { ID_A, ID_B, pen, rect } from "./support/fixtures"

const idle: ToolState = { mode: "idle" }
const env = (shapes = [rect()]) => ({ color: "#1098ad" as const, newId: () => ID_B, shapes })

describe("pointerDown", () => {
  it("starts a draft for each drawing tool with the chosen colour and id", () => {
    const down = pointerDown(idle, "rect", { x: 10, y: 20 }, env())
    expect(down).toMatchObject({
      mode: "drawing",
      draft: { kind: "rect", id: ID_B, color: "#1098ad", x: 10, y: 20, w: 0, h: 0 },
    })
    expect(pointerDown(idle, "pen", { x: 1, y: 2 }, env())).toMatchObject({
      draft: { kind: "pen", points: [] },
    })
  })

  it("select over a shape starts dragging with the grab offset", () => {
    expect(pointerDown(idle, "select", { x: 150, y: 130 }, env())).toEqual({
      mode: "dragging",
      id: ID_A,
      origin: { x: 150, y: 130 },
      offset: { x: 50, y: 30 },
    })
  })

  it("select over empty canvas stays idle", () => {
    expect(pointerDown(idle, "select", { x: 900, y: 900 }, env())).toEqual(idle)
  })

  it("clamps a press outside the board to its edge", () => {
    const down = pointerDown(idle, "line", { x: -5, y: 2000 }, env())
    expect(down).toMatchObject({ draft: { x: 0, y: 1000 } })
  })
})

describe("pointerMove", () => {
  it("grows a rect in any direction", () => {
    const down = pointerDown(idle, "rect", { x: 100, y: 100 }, env())
    const moved = pointerMove(down, { x: 60, y: 130 })
    expect(moved).toMatchObject({ draft: { x: 60, y: 100, w: 40, h: 30 } })
  })

  it("stretches a line by delta from its start", () => {
    const down = pointerDown(idle, "line", { x: 100, y: 100 }, env())
    expect(pointerMove(down, { x: 80, y: 140 })).toMatchObject({
      draft: { x: 100, y: 100, dx: -20, dy: 40 },
    })
  })

  it("appends pen offsets from the start", () => {
    const down = pointerDown(idle, "pen", { x: 10, y: 10 }, env())
    const moved = pointerMove(pointerMove(down, { x: 15, y: 10 }), { x: 15, y: 25 })
    expect(moved).toMatchObject({ draft: { points: [[5, 0], [5, 15]] } })
  })

  it("pen_draft_stops_at_max_points", () => {
    let t = pointerDown(idle, "pen", { x: 0, y: 0 }, env())
    for (let i = 0; i < MAX_PEN_POINTS + 50; i++) t = pointerMove(t, { x: i % 1600, y: 5 })
    expect(t.mode === "drawing" && t.draft.kind === "pen" && t.draft.points.length).toBe(MAX_PEN_POINTS)
  })

  it("does not mutate the previous state", () => {
    const down = pointerDown(idle, "pen", { x: 0, y: 0 }, env())
    pointerMove(down, { x: 5, y: 5 })
    expect(down).toMatchObject({ draft: { points: [] } })
  })

  it("ignores moves while idle", () => {
    expect(pointerMove(idle, { x: 1, y: 1 })).toBe(idle)
  })
})

describe("dragTarget", () => {
  it("is the pointer minus the grab offset while dragging, else null", () => {
    const dragging: ToolState = { mode: "dragging", id: ID_A, origin: { x: 100, y: 100 }, offset: { x: 50, y: 30 } }
    expect(dragTarget(dragging, { x: 200, y: 200 })).toEqual({ id: ID_A, x: 150, y: 170 })
    expect(dragTarget(idle, { x: 1, y: 1 })).toBeNull()
  })
})

describe("pointerUp", () => {
  it("commits a finished shape as an add and returns to idle", () => {
    const down = pointerDown(idle, "rect", { x: 10, y: 10 }, env())
    const up = pointerUp(down, { x: 60, y: 40 })
    expect(up.state).toEqual(idle)
    expect(up.commit).toEqual({
      kind: "add",
      shape: { kind: "rect", id: ID_B, color: "#1098ad", x: 10, y: 10, w: 50, h: 30 },
    })
  })

  it("drops a draft with no size", () => {
    const down = pointerDown(idle, "ellipse", { x: 10, y: 10 }, env())
    expect(pointerUp(down, { x: 10, y: 40 }).commit).toBeNull()
    expect(pointerUp(pointerDown(idle, "pen", { x: 1, y: 1 }, env()), { x: 1, y: 1 }).commit).toBeNull()
  })

  it("commits a pen with the final point included", () => {
    const down = pointerDown(idle, "pen", { x: 10, y: 10 }, env())
    const { commit } = pointerUp(down, { x: 12, y: 14 })
    expect(commit).toMatchObject({ kind: "add", shape: pen({ id: ID_B, color: "#1098ad", x: 10, y: 10, points: [[2, 4]] }) })
  })

  it("commits a drag as a move to the pointer minus the offset", () => {
    const dragging: ToolState = { mode: "dragging", id: ID_A, origin: { x: 100, y: 100 }, offset: { x: 50, y: 30 } }
    expect(pointerUp(dragging, { x: 200, y: 200 })).toEqual({
      state: idle,
      commit: { kind: "move", id: ID_A, x: 150, y: 170 },
    })
  })

  it("a plain click on a shape commits no move", () => {
    const down = pointerDown(idle, "select", { x: 150, y: 130 }, env())
    expect(pointerUp(down, { x: 150, y: 130 }).commit).toBeNull()
  })

  it("keeps a dragged shape's origin on the board", () => {
    const dragging: ToolState = { mode: "dragging", id: ID_A, origin: { x: 100, y: 100 }, offset: { x: 50, y: 30 } }
    expect(dragTarget(dragging, { x: 10, y: 5 })).toEqual({ id: ID_A, x: 0, y: 0 })
    expect(dragTarget(dragging, { x: 1600, y: 1000 })).toEqual({ id: ID_A, x: 1550, y: 970 })
  })

  it("commits nothing from idle", () => {
    expect(pointerUp(idle, { x: 1, y: 1 })).toEqual({ state: idle, commit: null })
  })
})
