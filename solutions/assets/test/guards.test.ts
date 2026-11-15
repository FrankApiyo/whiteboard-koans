import { describe, expect, it } from "vitest"
import { isColor, isFiniteNumber, isRecord, isString } from "../js/guards"
import { PALETTE } from "../js/types"

describe("guards", () => {
  it("isRecord accepts plain objects only", () => {
    expect(isRecord({ a: 1 })).toBe(true)
    expect(isRecord(null)).toBe(false)
    expect(isRecord([])).toBe(false)
    expect(isRecord("x")).toBe(false)
  })

  it("isFiniteNumber rejects NaN, Infinity and numeric strings", () => {
    expect(isFiniteNumber(3)).toBe(true)
    expect(isFiniteNumber(0)).toBe(true)
    expect(isFiniteNumber(Number.NaN)).toBe(false)
    expect(isFiniteNumber(Infinity)).toBe(false)
    expect(isFiniteNumber("3")).toBe(false)
  })

  it("isString accepts strings only", () => {
    expect(isString("")).toBe(true)
    expect(isString(1)).toBe(false)
  })

  it("isColor accepts exactly the palette", () => {
    for (const color of PALETTE) expect(isColor(color)).toBe(true)
    expect(isColor("#000000")).toBe(false)
    expect(isColor(undefined)).toBe(false)
  })
})
