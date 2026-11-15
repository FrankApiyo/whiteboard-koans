import { PALETTE, type Color } from "./types"

export function isRecord(value: unknown): value is Record<string, unknown> {
  // >>> 01
  __blank("01: plain object check");
  // <<< 01
}

export function isFiniteNumber(value: unknown): value is number {
  // >>> 01
  __blank("01: finite number check");
  // <<< 01
}

export function isString(value: unknown): value is string {
  // >>> 01
  __blank("01: string check");
  // <<< 01
}

export function isColor(value: unknown): value is Color {
  // >>> 01
  __blank("01: palette check");
  // <<< 01
}
