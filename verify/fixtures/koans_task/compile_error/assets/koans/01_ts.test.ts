import { expect } from "vitest"
import { test } from "@koans/runtime"

test("a number equals itself", () => {
  expect(1).toBe(1)
})

test("a string equals itself", () => {
  expect("a").toBe("a")
})
