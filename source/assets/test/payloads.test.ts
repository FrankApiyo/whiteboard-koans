import { describe, expect, it } from "vitest"
import { isCursorPayload, isDeletePayload, isMovePayload, isReply, isShape } from "../js/payloads"
import { MAX_PEN_POINTS } from "../js/types"
import { ellipse, ID_A, line, pen, rect } from "./support/fixtures"

describe("isShape", () => {
  it("accepts each kind", () => {
    for (const shape of [rect(), ellipse(), line(), pen(), rect({ z: 3 })]) {
      expect(isShape(shape)).toBe(true)
    }
  })

  it("rejects unknown kinds, bad colours, missing and non-numeric fields", () => {
    expect(isShape({ ...rect(), kind: "star" })).toBe(false)
    expect(isShape({ ...rect(), color: "#000000" })).toBe(false)
    expect(isShape({ ...rect(), w: undefined })).toBe(false)
    expect(isShape({ ...rect(), x: "1" })).toBe(false)
    expect(isShape({ ...rect(), id: 4 })).toBe(false)
    expect(isShape({ ...rect(), z: "high" })).toBe(false)
    expect(isShape(null)).toBe(false)
  })

  it("rejects malformed or oversized pen points", () => {
    expect(isShape({ ...pen(), points: [[1]] })).toBe(false)
    expect(isShape({ ...pen(), points: "x" })).toBe(false)
    expect(isShape({ ...pen(), points: Array.from({ length: MAX_PEN_POINTS + 1 }, () => [0, 0]) })).toBe(false)
  })
})

describe("event payloads", () => {
  it("isMovePayload needs id, x and y", () => {
    expect(isMovePayload({ id: ID_A, x: 1, y: 2 })).toBe(true)
    expect(isMovePayload({ id: ID_A, x: 1 })).toBe(false)
  })

  it("isDeletePayload needs an id", () => {
    expect(isDeletePayload({ id: ID_A })).toBe(true)
    expect(isDeletePayload({})).toBe(false)
  })

  it("isCursorPayload needs tab, name, a palette colour and coordinates", () => {
    const cursor = { tab: "t", name: "Ada", color: "#e03131", x: 1, y: 2 }
    expect(isCursorPayload(cursor)).toBe(true)
    expect(isCursorPayload({ ...cursor, color: "red" })).toBe(false)
    expect(isCursorPayload({ ...cursor, x: null })).toBe(false)
  })
})

describe("isReply", () => {
  it("accepts ok true, and ok false with a shape or null", () => {
    expect(isReply({ ok: true })).toBe(true)
    expect(isReply({ ok: false, shape: null })).toBe(true)
    expect(isReply({ ok: false, shape: rect() })).toBe(true)
  })

  it("rejects everything else", () => {
    expect(isReply({ ok: false })).toBe(false)
    expect(isReply({ ok: false, shape: { kind: "star" } })).toBe(false)
    expect(isReply({ ok: "yes" })).toBe(false)
    expect(isReply(undefined)).toBe(false)
  })
})
