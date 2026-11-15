/*
Files this chapter touches
  - assets/js/geometry.ts: bounds, hitTest, moveTo, toBoard, topmostAt, describe
  - assets/js/types.ts: Shape, assertNever (given; read them)

Modelling shapes. Shape in types.ts is a discriminated union, Rect | Ellipse | Line | Pen: four
interfaces that share id, color, x, y and an optional z, and differ in a literal kind field. A
rect or an ellipse adds w and h, a line adds dx and dy to its far end, and a pen adds points,
each [dx, dy] from x, y. Comparing kind narrows the type, in an if or a switch:

    function area(s: Shape): number {
      switch (s.kind) {
        case "rect": return s.w * s.h
        case "ellipse": return (Math.PI * s.w * s.h) / 4
        case "line": case "pen": return 0
        default: return assertNever(s)
      }
    }

In the default branch s is never, because every kind has a case, and assertNever(x: never)
accepts only that: add a fifth kind and each such switch fails to compile until it handles it.
If a bad value gets through at run time it throws Error(`Unexpected value: ${JSON.stringify(x)}`).

Fixtures: rect() is 200 by 100 at 100, 100; ellipse() is 200 by 100 at 400, 300; line() runs from
50, 50 by dx 100, dy 100; pen() starts at 20, 20 with 2 points. Shapes on the board are drawn in
array order, so the last one is on top. The board is 1600 by 1000 at any canvas size: a pointer's
clientX and clientY are measured from the canvas's left and top on the page and scaled by its
width and height, as getBoundingClientRect() reports them.

    Write:          assets/js/geometry.ts:100  (02: describe each kind)
    Exercised by:   assets/koans/02_modelling_shapes.test.ts:68

API you'll use
  - switch on kind: case "line": narrows s to Line until the next case
  - JSON.stringify: JSON.stringify("dot") is "dot" with its double quotes, JSON.stringify(2) is 2
  - spread: { ...s, color: "#1971c2" } is a copy of s with one field replaced
  - Math.round: Math.round(2.5) is 3, Math.round(2.4) is 2
  - .find: [1, 2, 3].find((n) => n > 1) is 2, and undefined when nothing matches
  - ??: a ?? b is b when a is null or undefined
  - [...xs].reverse(): a reversed copy; xs.reverse() alone reverses xs itself

Picture: lessons/svg/02_bounds_and_board.svg
*/
import { expect } from "vitest"
import { test } from "@koans/runtime"
import { bounds, describe, hitTest, moveTo, toBoard, topmostAt } from "../js/geometry"
import { assertNever, type Shape } from "../js/types"
import { ellipse, ID_A, ID_B, line, pen, rect } from "../test/support/fixtures"

function farX(s: Shape): number {
  return s.kind === "line" ? s.x + s.dx : s.x
}

test("Every Shape carries a literal kind, and the kind says which of the four interfaces it is.", () => {
  const shapes: Shape[] = [rect(), ellipse(), line(), pen()]
  expect(shapes.map((s) => s.kind)).toEqual(_a(["rect", "ellipse", "line", "pen"]))
})

test("Comparing kind narrows the type, so farX may read dx only on the branch where kind is line.", () => {
  expect(farX(line())).toBe(_a(150))
  expect(farX(rect())).toBe(_a(100))
})

test("assertNever compiles only where every kind is handled, and at run time it throws naming what got through.", () => {
  expect(() => assertNever("hexagon" as never)).toThrowError(new Error(_a('Unexpected value: "hexagon"')))
})

test("Implement describe in assets/js/geometry.ts so it names each kind with its size or far end and its position. 1. Switch on s.kind with a case per kind, each returning a template literal. 2. End with a default that returns assertNever of s, so a fifth kind would not compile.", () => {
  expect(describe(rect())).toBe("rectangle 200 by 100 at 100, 100")
  expect(describe(ellipse())).toBe("ellipse 200 by 100 at 400, 300")
  expect(describe(line())).toBe("line from 50, 50 to 150, 150")
  expect(describe(pen())).toBe("pen stroke of 2 points from 20, 20")
})

test("Fill the rect and ellipse case of bounds: their box is their own x, y, w and h.", () => {
  expect(bounds(rect())).toEqual({ x: 100, y: 100, w: 200, h: 100 })
  expect(bounds(ellipse({ x: 0, y: 5 }))).toEqual({ x: 0, y: 5, w: 200, h: 100 })
})

test("Fill the line case of bounds: a line pointing up and left still has a box with its corner top left and a positive w and h. The pen case below it shows the helper to use.", () => {
  expect(bounds(line({ x: 150, y: 150, dx: -100, dy: -50 }))).toEqual({ x: 50, y: 100, w: 100, h: 50 })
  expect(bounds(line())).toEqual({ x: 50, y: 50, w: 100, h: 100 })
})

test("Fill the rect case of hitTest: a point inside the rect, or within tolerance of its edge, hits it. A finger or a mouse is never exact, so the tolerance defaults to 6.", () => {
  expect(hitTest(rect(), { x: 150, y: 150 })).toBe(true)
  expect(hitTest(rect(), { x: 95, y: 150 })).toBe(true)
  expect(hitTest(rect(), { x: 306, y: 206 })).toBe(true)
  expect(hitTest(rect(), { x: 80, y: 150 })).toBe(false)
  expect(hitTest(rect(), { x: 150, y: 207 })).toBe(false)
  expect(hitTest(rect(), { x: 80, y: 150 }, 25)).toBe(true)
})

test("Implement topmostAt so it returns the last shape the point hits, or null over empty board, without reordering the array it was given.", () => {
  const below = rect({ id: ID_A })
  const above = rect({ id: ID_B, x: 120, y: 120 })
  const shapes = [below, above]
  expect(topmostAt(shapes, { x: 150, y: 150 })).toBe(above)
  expect(topmostAt(shapes, { x: 105, y: 105 })).toBe(below)
  expect(topmostAt(shapes, { x: 900, y: 900 })).toBeNull()
  expect(shapes).toEqual([below, above])
})

test("Implement moveTo so it returns a copy of the shape at the new x and y and leaves the original alone. Svelte redraws when it sees a new object, so shapes are replaced, never changed in place.", () => {
  const original = pen()
  const moved = moveTo(original, 5, 6)
  expect(moved).toEqual({ ...original, x: 5, y: 6 })
  expect(moved).not.toBe(original)
  expect(original.x).toBe(20)
})

test("Implement toBoard so it maps a pointer's client coordinates to board coordinates, rounded to whole numbers.", () => {
  const canvasOnPage = { left: 10, top: 20, width: 800, height: 500 }
  expect(toBoard(410, 270, canvasOnPage)).toEqual({ x: 800, y: 500 })
  expect(toBoard(10, 20, canvasOnPage)).toEqual({ x: 0, y: 0 })
  expect(toBoard(11, 21, canvasOnPage)).toEqual({ x: 2, y: 2 })
  expect(toBoard(810, 520, { left: 10, top: 20, width: 1600, height: 1000 })).toEqual({ x: 800, y: 500 })
})
