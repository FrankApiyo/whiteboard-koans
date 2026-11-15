import {
  assertNever,
  BOARD_HEIGHT,
  BOARD_WIDTH,
  MAX_PEN_POINTS,
  type Color,
  type Point,
  type Shape,
  type Tool,
} from "./types"
import { topmostAt } from "./geometry"

export type ToolState =
  | { mode: "idle" }
  | { mode: "drawing"; origin: Point; draft: Shape }
  | { mode: "dragging"; id: string; origin: Point; offset: Point }

export type Commit =
  | { kind: "add"; shape: Shape }
  | { kind: "move"; id: string; x: number; y: number }

export interface ToolEnv {
  color: Color
  newId(): string
  shapes: readonly Shape[]
}

const idle: ToolState = { mode: "idle" }

function clamp(p: Point): Point {
  return {
    x: Math.min(BOARD_WIDTH, Math.max(0, p.x)),
    y: Math.min(BOARD_HEIGHT, Math.max(0, p.y)),
  }
}

function emptyDraft(tool: Exclude<Tool, "select">, p: Point, env: ToolEnv): Shape {
  const base = { id: env.newId(), color: env.color, x: p.x, y: p.y }
  switch (tool) {
    case "rect":
      return { ...base, kind: "rect", w: 0, h: 0 }
    case "ellipse":
      return { ...base, kind: "ellipse", w: 0, h: 0 }
    case "line":
      return { ...base, kind: "line", dx: 0, dy: 0 }
    case "pen":
      return { ...base, kind: "pen", points: [] }
    default:
      return assertNever(tool)
  }
}

export function pointerDown(_t: ToolState, tool: Tool, point: Point, env: ToolEnv): ToolState {
  // >>> answer 05: start a draft or a drag
  const p = clamp(point)
  if (tool !== "select") return { mode: "drawing", origin: p, draft: emptyDraft(tool, p, env) }

  const hit = topmostAt(env.shapes, p)
  return hit ? { mode: "dragging", id: hit.id, origin: p, offset: { x: p.x - hit.x, y: p.y - hit.y } } : idle
  // <<<
}

function stretch(draft: Shape, origin: Point, p: Point): Shape {
  switch (draft.kind) {
    case "rect":
    case "ellipse":
      // >>> answer 05: stretch a box
      return {
        ...draft,
        x: Math.min(origin.x, p.x),
        y: Math.min(origin.y, p.y),
        w: Math.abs(p.x - origin.x),
        h: Math.abs(p.y - origin.y),
      }
      // <<<
    case "line":
      return { ...draft, dx: p.x - origin.x, dy: p.y - origin.y }
    case "pen":
      return draft.points.length >= MAX_PEN_POINTS
        ? draft
        : { ...draft, points: [...draft.points, [p.x - origin.x, p.y - origin.y]] }
    default:
      return assertNever(draft)
  }
}

export function pointerMove(t: ToolState, point: Point): ToolState {
  // >>> answer 05: move while drawing
  if (t.mode !== "drawing") return t
  return { ...t, draft: stretch(t.draft, t.origin, clamp(point)) }
  // <<<
}

export function dragTarget(t: ToolState, p: Point): { id: string; x: number; y: number } | null {
  if (t.mode !== "dragging") return null
  const { x, y } = clamp({ x: p.x - t.offset.x, y: p.y - t.offset.y })
  return { id: t.id, x, y }
}

function hasSize(s: Shape): boolean {
  switch (s.kind) {
    case "rect":
    case "ellipse":
      return s.w > 0 && s.h > 0
    case "line":
      return s.dx !== 0 || s.dy !== 0
    case "pen":
      return s.points.some(([dx, dy]) => dx !== 0 || dy !== 0)
    default:
      return assertNever(s)
  }
}

export function pointerUp(t: ToolState, point: Point): { state: ToolState; commit: Commit | null } {
  // >>> answer 05: finish the gesture
  const p = clamp(point)
  const target = dragTarget(t, p)
  if (t.mode === "dragging" && t.origin.x === p.x && t.origin.y === p.y) {
    return { state: idle, commit: null }
  }
  if (target) return { state: idle, commit: { kind: "move", ...target } }

  const finished = pointerMove(t, p)
  if (finished.mode === "drawing" && hasSize(finished.draft)) {
    return { state: idle, commit: { kind: "add", shape: finished.draft } }
  }
  return { state: idle, commit: null }
  // <<<
}
