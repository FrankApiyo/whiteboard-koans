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
  // >>> answer 09: the fields every kind shares
  return (
    isString(value.id) &&
    isColor(value.color) &&
    hasNumbers(value, ["x", "y"]) &&
    (value.z === undefined || isFiniteNumber(value.z))
  )
  // <<<
}

export function isMovePayload(value: unknown): value is MovePayload {
  // >>> answer 10: a move payload
  return isRecord(value) && isString(value.id) && hasNumbers(value, ["x", "y"])
  // <<<
}

export function isDeletePayload(value: unknown): value is DeletePayload {
  // >>> answer 10: a delete payload
  return isRecord(value) && isString(value.id)
  // <<<
}

export function isCursorPayload(value: unknown): value is CursorPayload {
  // >>> answer 10: a cursor payload
  return (
    isRecord(value) &&
    isString(value.tab) &&
    isString(value.name) &&
    isColor(value.color) &&
    hasNumbers(value, ["x", "y"])
  )
  // <<<
}

export function isReply(value: unknown): value is Reply {
  // >>> answer 09: a reply, ok or with the server's shape
  if (!isRecord(value)) return false
  if (value.ok === true) return true
  return value.ok === false && (value.shape === null || isShape(value.shape))
  // <<<
}
