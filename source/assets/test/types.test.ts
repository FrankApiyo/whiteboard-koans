import { describe, expect, it } from "vitest"
import { assertNever, BOARD_HEIGHT, BOARD_WIDTH, MAX_PEN_POINTS, PALETTE } from "../js/types"

describe("types", () => {
  it("PALETTE copies the server palette", () => {
    expect(PALETTE).toEqual([
      "#e03131",
      "#f08c00",
      "#fab005",
      "#2f9e44",
      "#1098ad",
      "#1971c2",
      "#7048e8",
      "#c2255c",
    ])
  })

  it("exports the board limits", () => {
    expect([BOARD_WIDTH, BOARD_HEIGHT, MAX_PEN_POINTS]).toEqual([1600, 1000, 2000])
  })

  it("assertNever throws naming the value", () => {
    expect(() => assertNever("surprise" as never)).toThrow(/surprise/)
  })
})
