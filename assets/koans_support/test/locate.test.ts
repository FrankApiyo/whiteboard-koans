import { describe, expect, test } from "vitest"
import { locateTag } from "../locate"

const tree = "verify/fixtures/ts/tree/assets"

describe("locateTag", () => {
  test("finds_a_code_blank_in_js", () => {
    expect(locateTag("01: hit test", tree)).toEqual({ path: `${tree}/js/geometry.ts`, line: 13 })
  })

  test("finds_a_markup_blank_in_svelte", () => {
    expect(locateTag("03: people list", tree)).toEqual({
      path: `${tree}/svelte/PeopleList.svelte`,
      line: 9,
    })
  })

  test("finds_a_blank_in_a_drill", () => {
    expect(locateTag("03: badge", tree)).toEqual({
      path: `${tree}/koans/drills/03_badge.svelte`,
      line: 9,
    })
  })

  test("a_tag_prefix_is_not_a_match", () => {
    expect(locateTag("03: people", tree)).toBeNull()
  })

  test("an_unknown_tag_is_null", () => {
    expect(locateTag("99: nowhere", tree)).toBeNull()
  })

  test("a_missing_tree_is_null", () => {
    expect(locateTag("01: hit test", "verify/fixtures/ts/no_such_tree")).toBeNull()
  })
})
