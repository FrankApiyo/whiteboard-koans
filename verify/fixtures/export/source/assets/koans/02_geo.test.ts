/*
Geo.
*/
import { expect } from "vitest"
import { test } from "@koans/runtime"
import { area } from "../js/geo"

test("area multiplies", () => {
  expect(area({ w: 2, h: 3 })).toBe(_a(6))
})
