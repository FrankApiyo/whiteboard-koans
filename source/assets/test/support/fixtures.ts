import type { Ellipse, Line, Pen, Rect } from "../../js/types"

export const ID_A = "0b8c3a52-7a8f-4c1e-9d7e-1f0a5f3b2c01"
export const ID_B = "5d2f9d0e-3c4b-4a6e-8b1d-7e2c9a4f6b02"

export const rect = (overrides: Partial<Rect> = {}): Rect => ({
  kind: "rect",
  id: ID_A,
  color: "#e03131",
  x: 100,
  y: 100,
  w: 200,
  h: 100,
  ...overrides,
})

export const ellipse = (overrides: Partial<Ellipse> = {}): Ellipse => ({
  kind: "ellipse",
  id: ID_B,
  color: "#1971c2",
  x: 400,
  y: 300,
  w: 200,
  h: 100,
  ...overrides,
})

export const line = (overrides: Partial<Line> = {}): Line => ({
  kind: "line",
  id: ID_A,
  color: "#2f9e44",
  x: 50,
  y: 50,
  dx: 100,
  dy: 100,
  ...overrides,
})

export const pen = (overrides: Partial<Pen> = {}): Pen => ({
  kind: "pen",
  id: ID_B,
  color: "#7048e8",
  x: 20,
  y: 20,
  points: [
    [10, 0],
    [10, 10],
  ],
  ...overrides,
})
