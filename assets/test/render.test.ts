import { describe, expect, it } from "vitest"
import { drawBoard, drawShape, fitCanvas } from "../js/render"
import { createFakeContext } from "./support/fake_context"
import { ellipse, ID_A, line, pen, rect } from "./support/fixtures"

describe("fitCanvas", () => {
  it("sizes the backing store by the device pixel ratio and scales the transform", () => {
    const canvas = document.createElement("canvas")
    const ctx = createFakeContext()
    fitCanvas(canvas, ctx, 2)
    expect([canvas.width, canvas.height]).toEqual([3200, 2000])
    expect(ctx.calls).toEqual([["setTransform", 2, 0, 0, 2, 0, 0]])
  })
})

describe("drawShape", () => {
  it("strokes a rect in its colour", () => {
    const ctx = createFakeContext()
    drawShape(ctx, rect())
    expect(ctx.calls).toContainEqual(["set:strokeStyle", "#e03131"])
    expect(ctx.calls).toContainEqual(["strokeRect", 100, 100, 200, 100])
  })

  it("draws an ellipse around the centre of its box", () => {
    const ctx = createFakeContext()
    drawShape(ctx, ellipse())
    expect(ctx.calls).toContainEqual(["ellipse", 500, 350, 100, 50, 0, 0, Math.PI * 2])
  })

  it("draws a line from its start to start plus delta", () => {
    const ctx = createFakeContext()
    drawShape(ctx, line())
    expect(ctx.calls).toContainEqual(["moveTo", 50, 50])
    expect(ctx.calls).toContainEqual(["lineTo", 150, 150])
  })

  it("draws a pen as a path through its offsets", () => {
    const ctx = createFakeContext()
    drawShape(ctx, pen())
    const path = ctx.calls.filter(([name]) => name === "moveTo" || name === "lineTo")
    expect(path).toEqual([
      ["moveTo", 20, 20],
      ["lineTo", 30, 20],
      ["lineTo", 30, 30],
    ])
  })
})

describe("drawBoard", () => {
  it("draw_board_on_fake_context_records_calls", () => {
    const ctx = createFakeContext()
    drawBoard(ctx, [rect(), line({ id: "x" })], null)
    const names = ctx.calls.map(([name]) => name)
    expect(names[0]).toBe("clearRect")
    expect(ctx.calls[0]).toEqual(["clearRect", 0, 0, 1600, 1000])
    expect(names.filter((n) => n === "strokeRect")).toHaveLength(1)
    expect(names.filter((n) => n === "stroke")).toHaveLength(1)
  })

  it("outlines only the selected shape with a dashed box", () => {
    const ctx = createFakeContext()
    drawBoard(ctx, [rect({ id: ID_A })], ID_A)
    expect(ctx.calls).toContainEqual(["setLineDash", [6, 4]])
    expect(ctx.calls.filter(([n]) => n === "strokeRect")).toHaveLength(2)
  })

  it("draws nothing extra when the selection is not on the board", () => {
    const ctx = createFakeContext()
    drawBoard(ctx, [rect()], "missing")
    expect(ctx.calls.some(([n]) => n === "setLineDash")).toBe(false)
  })
})
