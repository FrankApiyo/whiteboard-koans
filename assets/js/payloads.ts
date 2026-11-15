import { isColor, isFiniteNumber, isRecord, isString } from "./guards"
import {
  MAX_PEN_POINTS,
  type CursorPayload,
  type DeletePayload,
  type MovePayload,
  type Reply,
  type Shape,
} from "./types"

function isPoints(value: unknown): value is [number, number][] {
  return (
    Array.isArray(value) &&
    value.length <= MAX_PEN_POINTS &&
    value.every((pair) => Array.isArray(pair) && pair.length === 2 && pair.every(isFiniteNumber))
  )
}

function hasNumbers(value: Record<string, unknown>, keys: string[]): boolean {
  return keys.every((key) => isFiniteNumber(value[key]))
}

function kindFieldsValid(value: Record<string, unknown>): boolean {
  switch (value.kind) {
    case "rect":
    case "ellipse":
      return hasNumbers(value, ["w", "h"])
    case "line":
      return hasNumbers(value, ["dx", "dy"])
    case "pen":
      return isPoints(value.points)
    default:
      return false
  }
}

export function isShape(value: unknown): value is Shape {
  if (!isRecord(value) || !kindFieldsValid(value)) return false
  // >>> 09
  __blank("09: the fields every kind shares");
  // <<< 09
}

export function isMovePayload(value: unknown): value is MovePayload {
  // >>> 10
  __blank("10: a move payload");
  // <<< 10
}

export function isDeletePayload(value: unknown): value is DeletePayload {
  // >>> 10
  __blank("10: a delete payload");
  // <<< 10
}

export function isCursorPayload(value: unknown): value is CursorPayload {
  // >>> 10
  __blank("10: a cursor payload");
  // <<< 10
}

export function isReply(value: unknown): value is Reply {
  // >>> 09
  __blank("09: a reply, ok or with the server's shape");
  // <<< 09
}
