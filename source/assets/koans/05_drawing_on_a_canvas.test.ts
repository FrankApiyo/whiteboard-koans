/*
Files this chapter touches
  - assets/js/render.ts: fitCanvas, drawShape, drawBoard
  - assets/js/tools.ts: pointerDown, pointerMove, stretch, pointerUp
  - assets/svelte/Canvas.svelte: the canvas element, the redraw effect, down, move, up
  - assets/test/support/fake_context.ts: createFakeContext (given; read it)

Drawing on a canvas. A canvas is pixels painted through its 2D context, canvas.getContext("2d").
ctx.strokeStyle = color picks the ink, beginPath() starts a path, moveTo(x, y) lifts the pen to a
point, lineTo(x, y) draws on to the next and stroke() inks the path. strokeRect(x, y, w, h)
outlines a box in one call, and clearRect(x, y, w, h) wipes one. An X is a path with two strokes:

    ctx.beginPath()
    ctx.moveTo(0, 0)
    ctx.lineTo(8, 8)
    ctx.moveTo(8, 0)
    ctx.lineTo(0, 8)
    ctx.stroke()

The board is 1600 by 1000 units on any screen; where devicePixelRatio is 3, a CSS pixel is 3 by
3 device pixels, so a sharp canvas.width is 4800. setTransform(a, b, c, d, e, f) maps every later
call: a and d scale x and y, b and c skew, e and f shift, so setTransform(1, 0, 0, 1, 50, 0) draws
everything 50 to the right. Setting canvas.width resets the transform, so size first.

tools.ts is a state machine. pointerDown, pointerMove and pointerUp take a ToolState and return a
new one: idle turns into drawing, a draft grown from its origin, or dragging, a shape id and the
grab offset; pointerUp goes back to idle with a commit, an add or a move, or null. On pointer
down, setPointerCapture(event.pointerId) keeps the moves coming when the pointer leaves.

    Write:          assets/js/render.ts:28  (05: size the canvas)
    Exercised by:   assets/koans/05_drawing_on_a_canvas.test.ts:116

API you'll use
  - ctx.lineWidth, lineCap, lineJoin: lineCap is "butt", "round" or "square", lineJoin is
    "miter", "round" or "bevel"; STROKE_WIDTH in render.ts is 3
  - ctx.ellipse: ctx.ellipse(50, 40, 30, 20, 0, 0, Math.PI * 2) is a whole ellipse 60 wide and
    40 tall about 50, 40: centre, radii, rotation, then start and end angles
  - createFakeContext: ctx.lineWidth = 8 records ["set:lineWidth", 8] and ctx.beginPath()
    records ["beginPath"], in order, in ctx.calls; a method's arguments follow its name
  - recorded: recorded(canvas).calls is what Canvas.svelte drew on the stub in setup.ts, each
    as { name: "moveTo", args: [4, 5] }
  - placeCanvas, pointer, nextFrame: given in assets/test/support/canvas.ts; await nextFrame()
    waits until the frames already asked for have run
  - Math.min and Math.abs: Math.min(7, 3) is 3 and Math.abs(3 - 7) is 4
  - clamp, emptyDraft: given in tools.ts; clamp keeps a point on the board, and
    emptyDraft(tool, p, env) is a new shape of that tool at p with no size yet
  - hasSize, dragTarget: given in tools.ts; hasSize(shape) is false for a box with no width or
    height and a line or pen that never left its start, and dragTarget(t, p) is the id with
    the pointer minus the grab offset while dragging, else null
  - topmostAt: topmostAt(shapes, p) from chapter 02 is the shape on top at p, or null
  - drawSelection, holdGrabbed: given; drawSelection(ctx, shapes, selectedId) boxes the
    selected shape in dashes, and holdGrabbed() marks the shape a drag holds, and selects it
  - crypto.randomUUID: crypto.randomUUID() is a new random id like the fixtures' ID_A
  - event.currentTarget: the element whose handler is running, here the canvas
  - style:aspect-ratio="{w} / {h}" keeps an element's shape; onpointerdown={press} hands an
    element a handler, and onpointermove, onpointerup and onpointercancel work the same way
  - requestAnimationFrame: const id = requestAnimationFrame(cb) runs cb before the next paint,
    and cancelAnimationFrame(id) drops it if it has not run yet
  - vi.stubGlobal: vi.stubGlobal("devicePixelRatio", 2) until vi.unstubAllGlobals()

Picture: lessons/svg/05_tool_machine.svg
*/
import { expect, vi } from "vitest"
import { test } from "@koans/runtime"
import { flushSync } from "svelte"
import { render, screen } from "@testing-library/svelte"
import Canvas from "../svelte/Canvas.svelte"
import { BoardState } from "../js/board_state.svelte"
import { drawBoard, drawShape, fitCanvas } from "../js/render"
import { pointerDown, pointerMove, pointerUp, type ToolEnv, type ToolState } from "../js/tools"
import type { Shape, Tool } from "../js/types"
import { createFakeContext, type FakeContext } from "../test/support/fake_context"
import { nextFrame, placeCanvas, pointer, recorded } from "../test/support/canvas"
import { ellipse, ID_A, ID_B, line, pen, rect } from "../test/support/fixtures"

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
const idle: ToolState = { mode: "idle" }
const env: ToolEnv = { color: "#1098ad", newId: () => ID_B, shapes: [rect()] }

function drawn(shape: Shape): FakeContext {
  const ctx = createFakeContext()
  drawShape(ctx, shape)
  return ctx
}

const path = (ctx: FakeContext) => ctx.calls.filter(([name]) => !name.startsWith("set:"))

const style = (ctx: FakeContext) =>
  Object.fromEntries(
    ctx.calls.filter(([name]) => name.startsWith("set:")).map(([name, value]) => [name.slice(4), value]),
  )

function mountCanvas(tool: Tool = "select", shapes: Shape[] = [rect()]) {
  const state = new BoardState(shapes, 1)
  state.tool = tool
  const oncommit = vi.fn()
  const oncursor = vi.fn()
  render(Canvas, { state, oncommit, oncursor })
  const canvas = screen.getByRole("group", { name: "Whiteboard" }).querySelector("canvas")
  if (!canvas) throw new Error("The Whiteboard group holds no canvas element")
  placeCanvas(canvas, { left: 0, top: 0, width: 800, height: 500 })
  return { state, oncommit, oncursor, canvas }
}

const clears = (canvas: HTMLCanvasElement) =>
  recorded(canvas).calls.filter((call) => call.name === "clearRect").length

test("A fake context keeps a list of what was done to it: a property set, then each method call with its arguments.", () => {
  const ctx = createFakeContext()
  ctx.strokeStyle = "#2f9e44"
  ctx.beginPath()
  ctx.lineTo(4, 5)
  expect(ctx.calls).toEqual(_a([["set:strokeStyle", "#2f9e44"], ["beginPath"], ["lineTo", 4, 5]]))
})

test("Implement fitCanvas so the canvas holds dpr device pixels per board unit while later calls still draw in board units. 1. Size the backing store, its width and height, to the board's times dpr. 2. Set a transform that scales both axes by dpr, with no skew and no shift.", () => {
  const canvas = document.createElement("canvas")
  const ctx = createFakeContext()
  fitCanvas(canvas, ctx, 1.5)
  expect([canvas.width, canvas.height]).toEqual([2400, 1500])
  expect(ctx.calls).toEqual([["setTransform", 1.5, 0, 0, 1.5, 0, 0]])
})

test("Implement drawShape so every shape is stroked in its own colour, STROKE_WIDTH wide with round caps and joins. 1. Set the four stroke properties. 2. Switch on s.kind: one strokeRect for a rect; a path round the centre of its box for an ellipse; a path from the start to the far end for a line; a path from the start through each point for a pen. 3. End with a default that returns assertNever of s.", () => {
  expect(style(drawn(rect()))).toEqual({ strokeStyle: "#e03131", lineWidth: 3, lineCap: "round", lineJoin: "round" })
  expect(style(drawn(ellipse())).strokeStyle).toBe("#1971c2")
  expect(path(drawn(rect()))).toEqual([["strokeRect", 100, 100, 200, 100]])
  expect(path(drawn(ellipse()))).toEqual([["beginPath"], ["ellipse", 500, 350, 100, 50, 0, 0, Math.PI * 2], ["stroke"]])
  expect(path(drawn(line({ dx: -40, dy: 30 })))).toEqual([["beginPath"], ["moveTo", 50, 50], ["lineTo", 10, 80], ["stroke"]])
  expect(path(drawn(pen()))).toEqual([["beginPath"], ["moveTo", 20, 20], ["lineTo", 30, 20], ["lineTo", 30, 30], ["stroke"]])
})

test("Implement the start of drawBoard so it wipes the whole board, then draws the shapes in array order, so a later shape covers an earlier one. The transform already turns board units into pixels, so the wipe is in board units.", () => {
  const ctx = createFakeContext()
  drawBoard(ctx, [ellipse(), rect()], null)
  expect(path(ctx)).toEqual([
    ["clearRect", 0, 0, 1600, 1000],
    ["beginPath"],
    ["ellipse", 500, 350, 100, 50, 0, 0, Math.PI * 2],
    ["stroke"],
    ["strokeRect", 100, 100, 200, 100],
  ])
})

test("Implement pointerDown so a press clamped to the board starts a gesture. 1. Clamp the point. 2. For any tool but select, return drawing from that origin with emptyDraft's shape. 3. For select, return dragging the topmost shape at the point, with the offset from the shape's x and y to the point, or idle over empty board.", () => {
  expect(pointerDown(idle, "rect", { x: 10, y: 20 }, env)).toEqual({
    mode: "drawing",
    origin: { x: 10, y: 20 },
    draft: { kind: "rect", id: ID_B, color: "#1098ad", x: 10, y: 20, w: 0, h: 0 },
  })
  expect(pointerDown(idle, "select", { x: 150, y: 130 }, env)).toEqual({
    mode: "dragging",
    id: ID_A,
    origin: { x: 150, y: 130 },
    offset: { x: 50, y: 30 },
  })
  expect(pointerDown(idle, "select", { x: 900, y: 900 }, env)).toEqual({ mode: "idle" })
  expect(pointerDown(idle, "line", { x: 1600, y: 1000 }, env)).toMatchObject({ origin: { x: 1600, y: 1000 } })
  expect(pointerDown(idle, "line", { x: 1601, y: -1 }, env)).toMatchObject({ origin: { x: 1600, y: 0 } })
})

test("Implement pointerMove and the box case of stretch so a rect or ellipse draft always spans its origin and the clamped pointer, with its corner top left and a positive size, whichever way it is dragged. 1. Leave any state but drawing as it is; while drawing, return a copy whose draft is stretched from origin to the clamped point. 2. In stretch, a box takes x and y from the smaller coordinates and w and h from the distances.", () => {
  const down = pointerDown(idle, "rect", { x: 100, y: 100 }, env)
  const left = pointerMove(down, { x: 60, y: 130 })
  expect(left).toMatchObject({ draft: { x: 60, y: 100, w: 40, h: 30 } })
  expect(pointerMove(left, { x: 150, y: 160 })).toMatchObject({ draft: { x: 100, y: 100, w: 50, h: 60 } })
  expect(pointerMove(down, { x: 2000, y: 100 })).toMatchObject({ draft: { x: 100, w: 1500, h: 0 } })
  expect(down).toMatchObject({ draft: { w: 0, h: 0 } })
  expect(pointerMove(idle, { x: 1, y: 1 })).toBe(idle)
})

test("Implement pointerUp so every gesture ends back at idle with its commit. 1. Clamp the point. 2. A drag released on its origin was a click and commits nothing; any other drag commits a move to dragTarget. 3. A draft takes the final point through pointerMove and commits as an add only if hasSize says it has a size.", () => {
  const drawing = pointerDown(idle, "rect", { x: 10, y: 10 }, env)
  expect(pointerUp(drawing, { x: 60, y: 40 })).toEqual({
    state: { mode: "idle" },
    commit: { kind: "add", shape: { kind: "rect", id: ID_B, color: "#1098ad", x: 10, y: 10, w: 50, h: 30 } },
  })
  expect(pointerUp(pointerDown(idle, "ellipse", { x: 10, y: 10 }, env), { x: 10, y: 40 }).commit).toBeNull()
  expect(pointerUp(pointerDown(idle, "pen", { x: 10, y: 10 }, env), { x: 12, y: 14 }).commit).toEqual({
    kind: "add",
    shape: { kind: "pen", id: ID_B, color: "#1098ad", x: 10, y: 10, points: [[2, 4]] },
  })
  const grab = pointerDown(idle, "select", { x: 150, y: 130 }, env)
  expect(pointerUp(grab, { x: 150, y: 130 })).toEqual({ state: { mode: "idle" }, commit: null })
  expect(pointerUp(grab, { x: 151, y: 130 }).commit).toEqual({ kind: "move", id: ID_A, x: 101, y: 100 })
  const corner = { ...env, shapes: [rect({ x: 1500, y: 900, w: 100, h: 100 })] }
  expect(pointerUp(pointerDown(idle, "select", { x: 1605, y: 950 }, corner), { x: 1605, y: 950 }).commit).toBeNull()
})

test("Fill the canvas element in Canvas.svelte: bound to canvas, so the given effect fits it to the screen, shaped like the board, with each shape's description listed inside it for screen readers. Its pointer handlers are tried in the last koan. 1. Use bind:this and style:aspect-ratio with BOARD_WIDTH and BOARD_HEIGHT. 2. Hand it down, move, up and cancel. 3. Inside, an each over shapes keyed by id, a list item per shape.", () => {
  vi.stubGlobal("devicePixelRatio", 2)
  try {
    const { canvas } = mountCanvas("select", [ellipse(), rect()])
    expect([canvas.width, canvas.height]).toEqual([3200, 2000])
    expect(canvas.style.aspectRatio).toBe("1600 / 1000")
    expect(screen.getAllByRole("listitem").map((item) => item.textContent)).toEqual([
      "ellipse 200 by 100 at 400, 300",
      "rectangle 200 by 100 at 100, 100",
    ])
  } finally {
    vi.unstubAllGlobals()
  }
}, { exercises: "05: the canvas element" })

test("Implement the redraw effect in Canvas.svelte: it draws nothing until the next animation frame, draws again when the shapes or the selection change, and two changes before a frame draw once. 1. Get the context, and stop if there is none. 2. Read the shapes to draw and the selected id in the effect itself, so it tracks them. 3. Ask for a frame that draws the board, and return a cleanup that cancels it.", async () => {
  const { state, canvas } = mountCanvas()
  expect(clears(canvas)).toBe(0)
  await nextFrame()
  expect(clears(canvas)).toBe(1)
  expect(recorded(canvas).calls).toContainEqual({ name: "strokeRect", args: [100, 100, 200, 100] })
  state.upsert(ellipse())
  flushSync()
  state.moveShape(ID_B, 600, 300)
  flushSync()
  await nextFrame()
  expect(clears(canvas)).toBe(2)
  expect(recorded(canvas).calls).toContainEqual({ name: "ellipse", args: [700, 350, 100, 50, 0, 0, Math.PI * 2] })
  state.selectedId = ID_A
  flushSync()
  await nextFrame()
  expect(clears(canvas)).toBe(3)
  expect(recorded(canvas).calls.at(-1)?.name).toBe("restore")
}, { exercises: ["05: the canvas element", "05: redraw in the next frame"] })

test("Implement the pointer handlers in Canvas.svelte so a drag with the rectangle tool shows its draft while the button is down and commits it as an add on release. 1. In down, capture the pointer, then step the tool with pointerDown at the board point, with the board's colour, crypto.randomUUID for ids, and the shapes. 2. In move, report the point to oncursor, then step the tool with pointerMove. 3. In up, finish with the commit pointerUp returns.", async () => {
  const { state, oncommit, oncursor, canvas } = mountCanvas("rect", [])
  state.color = "#1971c2"
  const capture = vi.spyOn(canvas, "setPointerCapture")
  await pointer(canvas, "pointerDown", 100, 100, { pointerId: 7 })
  expect(capture).toHaveBeenCalledExactlyOnceWith(7)
  await pointer(canvas, "pointerMove", 150, 125, { pointerId: 7 })
  expect(oncursor).toHaveBeenCalledExactlyOnceWith({ x: 300, y: 250 })
  await nextFrame()
  expect(recorded(canvas).calls).toContainEqual({ name: "strokeRect", args: [200, 200, 100, 50] })
  expect(state.shapes.size).toBe(0)
  expect(oncommit).not.toHaveBeenCalled()
  await pointer(canvas, "pointerUp", 300, 250, { pointerId: 7 })
  expect(oncommit).toHaveBeenCalledExactlyOnceWith(
    {
      kind: "add",
      shape: { kind: "rect", id: expect.stringMatching(UUID), color: "#1971c2", x: 200, y: 200, w: 400, h: 300 },
    },
    undefined,
  )
}, {
  exercises: [
    "05: the canvas element",
    "05: redraw in the next frame",
    "05: capture and start",
    "05: follow the pointer",
    "05: finish on pointer up",
  ],
})
