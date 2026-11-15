import { expect } from "vitest"
import { test } from "@koans/runtime"
import { area } from "../js/geometry"

test("a rectangle's area is its width times its height", () => {
  expect(area({ x: 0, y: 0, w: 2, h: 3 })).toBe(6)
})

test("an area is a number you can name", () => {
  const r = { x: 0, y: 0, w: 4, h: 5 }
  expect(area(r)).toBe(__)
})
