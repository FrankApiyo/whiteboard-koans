import { expect } from "vitest"
import { test } from "@koans/runtime"

const count: number = "three"

test("a number is a number", () => {
  expect(count).toBe(3)
})
