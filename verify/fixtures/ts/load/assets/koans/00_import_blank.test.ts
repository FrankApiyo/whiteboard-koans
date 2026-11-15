import { expect } from "vitest"
import { test } from "@koans/runtime"
import { settings } from "../js/boot"

test("the board is as wide as its settings", () => {
  expect(settings.width).toBe(1600)
})
