import { render, screen } from "@testing-library/svelte"
import { flushSync } from "svelte"
import { afterEach, describe, expect, it, vi } from "vitest"
import Canvas from "../svelte/Canvas.svelte"
import { BoardState } from "../js/board_state.svelte"
import type { Tool } from "../js/types"
import { drag, nextFrame, placeCanvas, pointer, recorded } from "./support/canvas"
import { ellipse, ID_A, rect } from "./support/fixtures"

function setup(tool: Tool = "select", shapes = [rect()]) {
  const state = new BoardState(shapes, 1)
  state.tool = tool
  const oncommit = vi.fn()
  const oncursor = vi.fn()
  render(Canvas, { state, oncommit, oncursor })
  const canvas = screen.getByRole("group", { name: "Whiteboard" }).querySelector("canvas") as HTMLCanvasElement
  placeCanvas(canvas, { left: 0, top: 0, width: 800, height: 500 })
  return { state, oncommit, oncursor, canvas }
}

const names = (canvas: HTMLCanvasElement, from = 0) =>
  recorded(canvas).calls.slice(from).map((call) => call.name)

afterEach(() => {
  vi.unstubAllGlobals()
})

describe("Canvas drawing", () => {
  it("sizes the canvas for the device pixel ratio", () => {
    vi.stubGlobal("devicePixelRatio", 2)
    const { canvas } = setup()
    expect([canvas.width, canvas.height]).toEqual([3200, 2000])
    expect(recorded(canvas).calls).toContainEqual({ name: "setTransform", args: [2, 0, 0, 2, 0, 0] })
  })

  it("draws the board in the next animation frame", async () => {
    const { canvas } = setup()
    expect(names(canvas)).not.toContain("clearRect")
    await nextFrame()
    expect(names(canvas)).toContain("clearRect")
    expect(recorded(canvas).calls).toContainEqual({ name: "strokeRect", args: [100, 100, 200, 100] })
  })

  it("redraws when the board state changes", async () => {
    const { state, canvas } = setup()
    await nextFrame()
    const before = recorded(canvas).calls.length
    state.upsert(ellipse())
    flushSync()
    await nextFrame()
    expect(names(canvas, before)).toContain("ellipse")
  })

  it("lists the shapes for assistive technology", () => {
    setup()
    expect(screen.getByText("rectangle 200 by 100 at 100, 100")).toBeTruthy()
  })
})

describe("Canvas pointer tools", () => {
  it("draws a rectangle in board coordinates and commits it as an add", async () => {
    const { state, oncommit, canvas } = setup("rect", [])
    const capture = vi.spyOn(canvas, "setPointerCapture")
    await drag(canvas, [100, 100], [300, 250])
    expect(capture).toHaveBeenCalledWith(1)
    expect(oncommit).toHaveBeenCalledExactlyOnceWith({
      kind: "add",
      shape: expect.objectContaining({ kind: "rect", color: state.color, x: 200, y: 200, w: 400, h: 300 }),
    }, undefined)
  })

  it("draws the draft while the pointer is down without adding it", async () => {
    const { state, oncommit, canvas } = setup("rect", [])
    await pointer(canvas, "pointerDown", 100, 100)
    await pointer(canvas, "pointerMove", 150, 150)
    await nextFrame()
    expect(recorded(canvas).calls).toContainEqual({ name: "strokeRect", args: [200, 200, 100, 100] })
    expect(state.shapes.size).toBe(0)
    expect(oncommit).not.toHaveBeenCalled()
  })

  it("drags a shape locally and commits the final move", async () => {
    const { state, oncommit, canvas } = setup()
    await pointer(canvas, "pointerDown", 75, 65)
    expect(state.draggingId).toBe(ID_A)
    expect(state.selectedId).toBe(ID_A)
    await pointer(canvas, "pointerMove", 125, 115)
    expect(state.shapes.get(ID_A)).toMatchObject({ x: 200, y: 200 })
    await pointer(canvas, "pointerUp", 125, 115)
    expect(state.draggingId).toBeNull()
    expect(oncommit).toHaveBeenCalledExactlyOnceWith({ kind: "move", id: ID_A, x: 200, y: 200 }, rect())
  })

  it("a cancelled drag is dropped where it was last dragged", async () => {
    const { state, oncommit, canvas } = setup()
    await pointer(canvas, "pointerDown", 75, 65)
    await pointer(canvas, "pointerMove", 125, 115)
    await pointer(canvas, "pointerCancel", 0, 0)
    expect(state.draggingId).toBeNull()
    expect(oncommit).toHaveBeenCalledExactlyOnceWith({ kind: "move", id: ID_A, x: 200, y: 200 }, rect())
  })

  it("a cancelled press that never moved commits nothing", async () => {
    const { state, oncommit, canvas } = setup()
    await pointer(canvas, "pointerDown", 75, 65)
    await pointer(canvas, "pointerCancel", 0, 0)
    expect(state.draggingId).toBeNull()
    expect(oncommit).not.toHaveBeenCalled()
  })

  it("ignores buttons other than the main one", async () => {
    const { oncommit, canvas } = setup("rect", [])
    const capture = vi.spyOn(canvas, "setPointerCapture")
    await pointer(canvas, "pointerDown", 100, 100, { button: 2 })
    await pointer(canvas, "pointerMove", 300, 250)
    await pointer(canvas, "pointerUp", 300, 250, { button: 2 })
    expect(capture).not.toHaveBeenCalled()
    expect(oncommit).not.toHaveBeenCalled()
  })

  it("a second touch does not take over a drag", async () => {
    const { state, oncommit, canvas } = setup()
    await pointer(canvas, "pointerDown", 75, 65)
    await pointer(canvas, "pointerDown", 700, 450, { pointerId: 2, isPrimary: false })
    await pointer(canvas, "pointerMove", 10, 10, { pointerId: 2, isPrimary: false })
    await pointer(canvas, "pointerUp", 10, 10, { pointerId: 2, isPrimary: false })
    await pointer(canvas, "pointerCancel", 10, 10, { pointerId: 2, isPrimary: false })
    expect(state.draggingId).toBe(ID_A)
    expect(state.selectedId).toBe(ID_A)
    expect(state.shapes.get(ID_A)).toEqual(rect())
    await pointer(canvas, "pointerMove", 125, 115)
    await pointer(canvas, "pointerUp", 125, 115)
    expect(oncommit).toHaveBeenCalledExactlyOnceWith({ kind: "move", id: ID_A, x: 200, y: 200 }, rect())
  })

  it("a click on a shape selects it and commits nothing", async () => {
    const { state, oncommit, canvas } = setup()
    await pointer(canvas, "pointerDown", 75, 65)
    await pointer(canvas, "pointerUp", 75, 65)
    expect(state.selectedId).toBe(ID_A)
    expect(state.draggingId).toBeNull()
    expect(oncommit).not.toHaveBeenCalled()
  })

  it("a click on empty board clears the selection", async () => {
    const { state, canvas } = setup()
    state.selectedId = ID_A
    await pointer(canvas, "pointerDown", 700, 450)
    await pointer(canvas, "pointerUp", 700, 450)
    expect(state.selectedId).toBeNull()
  })

  it("reports the pointer in board coordinates", async () => {
    const { oncursor, canvas } = setup()
    await pointer(canvas, "pointerMove", 400, 250)
    expect(oncursor).toHaveBeenCalledExactlyOnceWith({ x: 800, y: 500 })
  })
})
