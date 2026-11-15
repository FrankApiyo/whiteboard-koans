import { describe, expect, it } from "vitest"
import { bounds, describe as describeShape, hitTest, moveTo, toBoard, topmostAt } from "../js/geometry"
import { ellipse, ID_A, ID_B, line, pen, rect } from "./support/fixtures"

describe("bounds", () => {
  it("is x, y, w, h for a rect and an ellipse", () => {
    expect(bounds(rect())).toEqual({ x: 100, y: 100, w: 200, h: 100 })
    expect(bounds(ellipse())).toEqual({ x: 400, y: 300, w: 200, h: 100 })
  })

  it("normalises a line that points up and left", () => {
    expect(bounds(line({ x: 150, y: 150, dx: -100, dy: -50 }))).toEqual({
      x: 50,
      y: 100,
      w: 100,
      h: 50,
    })
  })

  it("covers the start and every point of a pen", () => {
    expect(bounds(pen({ x: 20, y: 20, points: [[10, 0], [-5, 30]] }))).toEqual({
      x: 15,
      y: 20,
      w: 15,
      h: 30,
    })
  })
})

describe("hitTest", () => {
  it("hits inside a rect and within tolerance of its edge", () => {
    expect(hitTest(rect(), { x: 150, y: 150 })).toBe(true)
    expect(hitTest(rect(), { x: 95, y: 150 })).toBe(true)
    expect(hitTest(rect(), { x: 80, y: 150 })).toBe(false)
  })

  it("hits an ellipse inside the curve, not in the corner of its box", () => {
    expect(hitTest(ellipse(), { x: 500, y: 350 })).toBe(true)
    expect(hitTest(ellipse(), { x: 405, y: 305 })).toBe(false)
  })

  it("hits a line near the segment only", () => {
    const diagonal = line({ x: 0, y: 0, dx: 100, dy: 100 })
    expect(hitTest(diagonal, { x: 50, y: 53 })).toBe(true)
    expect(hitTest(diagonal, { x: 50, y: 70 })).toBe(false)
    expect(hitTest(diagonal, { x: 150, y: 150 })).toBe(false)
  })

  it("hits a pen near its path, not inside its bounding box", () => {
    const l = pen({ x: 0, y: 0, points: [[100, 0], [100, 100]] })
    expect(hitTest(l, { x: 50, y: 2 })).toBe(true)
    expect(hitTest(l, { x: 20, y: 80 })).toBe(false)
  })

  it("takes the tolerance as a parameter", () => {
    expect(hitTest(rect(), { x: 80, y: 150 }, 25)).toBe(true)
  })
})

describe("moveTo", () => {
  it("returns a moved copy and leaves the original alone", () => {
    const original = rect()
    const moved = moveTo(original, 5, 6)
    expect(moved).toEqual({ ...original, x: 5, y: 6 })
    expect(original.x).toBe(100)
  })
})

describe("toBoard", () => {
  const rectOnPage = { left: 10, top: 20, width: 800, height: 500 }

  it("scales client coordinates to board coordinates, rounded", () => {
    expect(toBoard(410, 270, rectOnPage)).toEqual({ x: 800, y: 500 })
    expect(toBoard(11, 21, rectOnPage)).toEqual({ x: 2, y: 2 })
  })
})

describe("topmostAt", () => {
  it("returns the last shape under the point", () => {
    const below = rect({ id: ID_A })
    const above = rect({ id: ID_B, x: 120, y: 120 })
    expect(topmostAt([below, above], { x: 150, y: 150 })?.id).toBe(ID_B)
  })

  it("returns null over empty canvas", () => {
    expect(topmostAt([rect()], { x: 900, y: 900 })).toBeNull()
  })
})

describe("describe", () => {
  it("names each kind with its position", () => {
    expect(describeShape(rect())).toBe("rectangle 200 by 100 at 100, 100")
    expect(describeShape(ellipse())).toBe("ellipse 200 by 100 at 400, 300")
    expect(describeShape(line())).toBe("line from 50, 50 to 150, 150")
    expect(describeShape(pen())).toBe("pen stroke of 2 points from 20, 20")
  })
})
