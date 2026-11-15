import type { Live } from "./live"

export const PALETTE = [
  "#e03131",
  "#f08c00",
  "#fab005",
  "#2f9e44",
  "#1098ad",
  "#1971c2",
  "#7048e8",
  "#c2255c",
] as const

export type Color = (typeof PALETTE)[number]

export const BOARD_WIDTH = 1600
export const BOARD_HEIGHT = 1000
export const MAX_PEN_POINTS = 2000

export interface Point {
  x: number
  y: number
}

interface Base {
  id: string
  color: Color
  x: number
  y: number
  z?: number
}

export interface Rect extends Base {
  kind: "rect"
  w: number
  h: number
}

export interface Ellipse extends Base {
  kind: "ellipse"
  w: number
  h: number
}

export interface Line extends Base {
  kind: "line"
  dx: number
  dy: number
}

export interface Pen extends Base {
  kind: "pen"
  points: [number, number][]
}

export type Shape = Rect | Ellipse | Line | Pen

export type Tool = "select" | "rect" | "ellipse" | "line" | "pen"

export interface Person {
  tab: string
  name: string
  color: Color
}

export type Me = Omit<Person, "tab"> & { tab?: string }

export interface BoardProps {
  shapes: Shape[]
  sync_id: number
  me: Me
  people: Person[]
  live: Live
}

export interface MovePayload {
  id: string
  x: number
  y: number
}

export interface DeletePayload {
  id: string
}

export interface CursorPayload extends Person, Point {}

export type Reply = { ok: true } | { ok: false; shape: Shape | null }

export function assertNever(x: never): never {
  throw new Error(`Unexpected value: ${JSON.stringify(x)}`)
}
