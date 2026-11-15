import { PALETTE, type Color } from "./types"

export function isRecord(value: unknown): value is Record<string, unknown> {
  // >>> answer 01: plain object check
  return typeof value === "object" && value !== null && !Array.isArray(value)
  // <<<
}

export function isFiniteNumber(value: unknown): value is number {
  // >>> answer 01: finite number check
  return typeof value === "number" && Number.isFinite(value)
  // <<<
}

export function isString(value: unknown): value is string {
  // >>> answer 01: string check
  return typeof value === "string"
  // <<<
}

export function isColor(value: unknown): value is Color {
  // >>> answer 01: palette check
  return PALETTE.some((color) => color === value)
  // <<<
}
