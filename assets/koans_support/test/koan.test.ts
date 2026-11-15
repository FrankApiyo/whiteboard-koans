import { beforeEach, expect } from "vitest"
import { test } from "@koans/runtime"

let meta: { exercises?: string[] } = {}

beforeEach(({ task }) => {
  meta = { ...task.meta }
})

test("meditation_is_the_test_name", () => {
  expect(expect.getState().currentTestName).toBe("meditation_is_the_test_name")
})

test("exercises_reach_the_meta", () => {
  expect(meta.exercises).toEqual(["03: people list"])
}, { exercises: "03: people list" })

test("exercise_lists_reach_the_meta", () => {
  expect(meta.exercises).toEqual(["03: people list", "04: badge"])
}, { exercises: ["03: people list", "04: badge"] })

test("a_koan_without_exercises_has_none", () => {
  expect(meta.exercises).toEqual([])
})

test("an_async_body_is_awaited", async () => {
  const value = await new Promise<number>((resolve) => setTimeout(() => resolve(7), 5))
  expect(value).toBe(7)
})
