import { expect, test } from "vitest"
import { area } from "../js/geo"

test("area multiplies", () => {
  expect(area({ w: 2, h: 3 })).toBe(6)
})
