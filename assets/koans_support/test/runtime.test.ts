import { describe, expect, test } from "vitest"
import { KoanBlank } from "@koans/runtime"

describe("blank runtime", () => {
  test("dunder_is_a_unique_symbol", () => {
    expect(typeof __).toBe("symbol")
    expect(__).not.toBe(Symbol("koan blank"))
  })

  test("a_blank_without_a_fallback_throws_koanblank", () => {
    let thrown: unknown = null

    try {
      __blank("01: hit test")
    } catch (error) {
      thrown = error
    }

    expect(thrown).toBeInstanceOf(KoanBlank)
    expect(thrown).toMatchObject({
      name: "KoanBlank",
      tag: "01: hit test",
      message: "Replace __blank() with the code the meditation describes.",
    })
  })

  test("a_blank_with_a_fallback_returns_it", () => {
    expect(__blank("03: people list", "")).toBe("")
    expect(__blank("12: people", [])).toEqual([])
  })

  test("an_undefined_fallback_still_counts_as_given", () => {
    expect(__blank("05: maybe", undefined)).toBeUndefined()
  })
})
