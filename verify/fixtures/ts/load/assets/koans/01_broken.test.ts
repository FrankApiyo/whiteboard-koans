import { expect } from "vitest"
import { test } from "@koans/runtime"

const parsed = JSON.parse("{")

test("a file that cannot load", () => {
  expect(parsed).toBe(1)
})
