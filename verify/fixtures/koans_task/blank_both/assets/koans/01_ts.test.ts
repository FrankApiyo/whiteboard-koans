import { expect } from "vitest"
import { test } from "@koans/runtime"
import { contains } from "../js/geometry"

test("a point inside the rectangle hits it", () => {
  expect(contains({ x: 0, y: 0, w: 10, h: 10 }, 5, 5)).toBe(true)
})

test("an area is a number you can name", () => {
  expect(2 * 3).toBe(__)
})
