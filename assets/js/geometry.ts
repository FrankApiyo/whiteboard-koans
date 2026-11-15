import { assertNever, BOARD_HEIGHT, BOARD_WIDTH, type Point, type Shape } from "./types"

export interface Box {
  x: number
  y: number
  w: number
  h: number
}

function boxAround(points: readonly Point[]): Box {
  const xs = points.map((p) => p.x)
  const ys = points.map((p) => p.y)
  const x = Math.min(...xs)
  const y = Math.min(...ys)
  return { x, y, w: Math.max(...xs) - x, h: Math.max(...ys) - y }
}

export function bounds(s: Shape): Box {
  switch (s.kind) {
    case "rect":
    case "ellipse":
      // >>> 02
      __blank("02: box of a rect");
      // <<< 02
    case "line":
      // >>> 02
      __blank("02: box of a line");
      // <<< 02
    case "pen":
      return boxAround([s, ...s.points.map(([dx, dy]) => ({ x: s.x + dx, y: s.y + dy }))])
    default:
      return assertNever(s)
  }
}

function distanceToSegment(p: Point, a: Point, b: Point): number {
  const dx = b.x - a.x
  const dy = b.y - a.y
  const lengthSquared = dx * dx + dy * dy
  const t = lengthSquared === 0 ? 0 : ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared
  const along = Math.max(0, Math.min(1, t))
  return Math.hypot(p.x - (a.x + along * dx), p.y - (a.y + along * dy))
}

function nearPath(path: readonly Point[], p: Point, tolerance: number): boolean {
  return path.slice(1).some((end, i) => distanceToSegment(p, path[i], end) <= tolerance)
}

function insideEllipse(s: { x: number; y: number; w: number; h: number }, p: Point, grow: number) {
  const rx = s.w / 2 + grow
  const ry = s.h / 2 + grow
  return ((p.x - (s.x + s.w / 2)) / rx) ** 2 + ((p.y - (s.y + s.h / 2)) / ry) ** 2 <= 1
}

export function hitTest(s: Shape, p: Point, tolerance = 6): boolean {
  switch (s.kind) {
    case "rect":
      // >>> 02
      __blank("02: hit a rect");
      // <<< 02
    case "ellipse":
      return insideEllipse(s, p, tolerance)
    case "line":
      return nearPath([s, { x: s.x + s.dx, y: s.y + s.dy }], p, tolerance)
    case "pen":
      return nearPath(
        [s, ...s.points.map(([dx, dy]) => ({ x: s.x + dx, y: s.y + dy }))],
        p,
        tolerance,
      )
    default:
      return assertNever(s)
  }
}

export function moveTo(s: Shape, x: number, y: number): Shape {
  // >>> 02
  __blank("02: moved copy");
  // <<< 02
}

export function toBoard(
  clientX: number,
  clientY: number,
  rect: { left: number; top: number; width: number; height: number },
): Point {
  // >>> 02
  __blank("02: client to board");
  // <<< 02
}

export function topmostAt(shapes: readonly Shape[], p: Point): Shape | null {
  // >>> 02
  __blank("02: topmost shape at a point");
  // <<< 02
}

export function describe(s: Shape): string {
  // >>> 02
  __blank("02: describe each kind");
  // <<< 02
}
