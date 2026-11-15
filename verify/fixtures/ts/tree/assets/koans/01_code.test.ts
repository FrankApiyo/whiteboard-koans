import { expect } from "vitest"
import { test } from "@koans/runtime"
import { contains } from "../js/geometry"

test("a point inside the rectangle hits it", () => {
  expect(contains({ x: 0, y: 0, w: 10, h: 10 }, 5, 5)).toBe(true)
})

test("an async koan checks after it awaits", async () => {
  const n = await Promise.resolve(1)
  expect(n).toBe(2)
})

test("an async koan reaches a blank after it awaits", async () => {
  await Promise.resolve()
  expect(contains({ x: 0, y: 0, w: 1, h: 1 }, 5, 5)).toBe(false)
})

test("the fixture keeps a longer file to sort by size", () => {
  const sizes = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
  expect(sizes.length).toBe(20)
})
