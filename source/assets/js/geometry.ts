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
      // >>> answer 02: box of a rect
      return { x: s.x, y: s.y, w: s.w, h: s.h }
      // <<<
    case "line":
      // >>> answer 02: box of a line
      return boxAround([s, { x: s.x + s.dx, y: s.y + s.dy }])
      // <<<
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
      // >>> answer 02: hit a rect
      return (
        p.x >= s.x - tolerance &&
        p.x <= s.x + s.w + tolerance &&
        p.y >= s.y - tolerance &&
        p.y <= s.y + s.h + tolerance
      )
      // <<<
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
  // >>> answer 02: moved copy
  return { ...s, x, y }
  // <<<
}

export function toBoard(
  clientX: number,
  clientY: number,
  rect: { left: number; top: number; width: number; height: number },
): Point {
  // >>> answer 02: client to board
  return {
    x: Math.round(((clientX - rect.left) / rect.width) * BOARD_WIDTH),
    y: Math.round(((clientY - rect.top) / rect.height) * BOARD_HEIGHT),
  }
  // <<<
}

export function topmostAt(shapes: readonly Shape[], p: Point): Shape | null {
  // >>> answer 02: topmost shape at a point
  return [...shapes].reverse().find((s) => hitTest(s, p)) ?? null
  // <<<
}

export function describe(s: Shape): string {
  // >>> answer 02: describe each kind
  switch (s.kind) {
    case "rect":
      return `rectangle ${s.w} by ${s.h} at ${s.x}, ${s.y}`
    case "ellipse":
      return `ellipse ${s.w} by ${s.h} at ${s.x}, ${s.y}`
    case "line":
      return `line from ${s.x}, ${s.y} to ${s.x + s.dx}, ${s.y + s.dy}`
    case "pen":
      return `pen stroke of ${s.points.length} points from ${s.x}, ${s.y}`
    default:
      return assertNever(s)
  }
  // <<<
}
