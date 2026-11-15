import { describe, expect, test } from "vitest"
import { classify } from "../classify"

const tree = "verify/fixtures/ts/tree/assets"

const areaKoan = [
  'import { area } from "../js/geometry"',
  "",
  "",
  "",
  'test("an area is a number you can name", () => {',
  "  const r = { x: 0, y: 0, w: 4, h: 5 }",
  "  expect(area(r)).toBe(__)",
  "})",
].join("\n")

const wrongBeforeBlank = [
  "",
  "",
  "",
  "",
  'test("a wrong answer comes first", () => {',
  "  expect(area(r)).toBe(19)",
  "  expect(area(r)).toBe(__)",
  "})",
].join("\n")

const markupKoan = [
  "",
  "",
  "",
  "",
  "",
  'test("the list names everyone on the board", () => {',
  '  render(PeopleList, { people: ["Ada"] })',
  '  expect(screen.getByText("Ada")).toBeTruthy()',
  '}, { exercises: "03: people list" })',
].join("\n")

const dunderNames = [
  "",
  "",
  "",
  "",
  'test("names are not blanks", () => {',
  '  expect(foo__bar).toBe("__")',
  "})",
].join("\n")

function koanWith(failingLine: string): string {
  return ["", "", "", "", 'test("a koan", () => {', failingLine, "})"].join("\n")
}

function classifyLine(failingLine: string) {
  return classify({
    error: { name: "AssertionError", line: 6 },
    koanSource: koanWith(failingLine),
    koanLine: 5,
    exercises: [],
    tree,
  })
}

describe("classify", () => {
  test("koanblank_is_a_code_blank_with_its_write_line", () => {
    const result = classify({
      error: { name: "KoanBlank", tag: "01: hit test", line: 6 },
      koanSource: areaKoan,
      koanLine: 5,
      exercises: [],
      tree,
    })

    expect(result).toEqual({
      status: "blank",
      at: 5,
      tag: "01: hit test",
      write: { path: `${tree}/js/geometry.ts`, line: 13, where: "01: hit test" },
    })
  })

  test("bare_dunder_on_the_failing_line_is_a_value_blank", () => {
    const result = classify({
      error: { name: "AssertionError", line: 7 },
      koanSource: areaKoan,
      koanLine: 5,
      exercises: [],
      tree,
    })

    expect(result).toEqual({ status: "blank", at: 7, tag: null, write: null })
  })

  test("an_earlier_wrong_answer_beats_a_later_blank", () => {
    expect(wrongBeforeBlank.split("\n")[6]).toContain("__")

    const result = classify({
      error: { name: "AssertionError", line: 6 },
      koanSource: wrongBeforeBlank,
      koanLine: 5,
      exercises: [],
      tree,
    })

    expect(result).toEqual({ status: "fail", at: 6, tag: null, write: null })
  })

  test("markup_blank_failure_names_the_write_line", () => {
    const result = classify({
      error: { name: "TestingLibraryElementError", line: 8 },
      koanSource: markupKoan,
      koanLine: 6,
      exercises: ["03: people list"],
      tree,
    })

    expect(result).toEqual({
      status: "blank",
      at: 6,
      tag: "03: people list",
      write: { path: `${tree}/svelte/PeopleList.svelte`, line: 9, where: "03: people list" },
    })
  })

  test("a_filled_exercised_tag_leaves_the_original_failure", () => {
    const result = classify({
      error: { name: "TestingLibraryElementError", line: 8 },
      koanSource: markupKoan,
      koanLine: 6,
      exercises: ["03: a tag the learner has filled"],
      tree,
    })

    expect(result).toEqual({ status: "fail", at: 8, tag: null, write: null })
  })

  test("a_name_containing_dunder_is_not_a_blank", () => {
    const result = classify({
      error: { name: "AssertionError", line: 6 },
      koanSource: dunderNames,
      koanLine: 5,
      exercises: [],
      tree,
    })

    expect(result).toEqual({ status: "fail", at: 6, tag: null, write: null })
  })

  test("a_passing_koan_is_ok_at_its_line", () => {
    const result = classify({ error: null, koanSource: areaKoan, koanLine: 5, exercises: [], tree })
    expect(result).toEqual({ status: "ok", at: 5, tag: null, write: null })
  })

  test("a_koanblank_called_in_the_koan_file_is_met_at_its_line", () => {
    const result = classify({
      error: { name: "KoanBlank", tag: "00: inline", line: 7 },
      koanSource: areaKoan,
      koanLine: 5,
      exercises: [],
      tree,
    })

    expect(result).toEqual({ status: "blank", at: 7, tag: "00: inline", write: null })
  })

  test("a_failure_outside_the_koan_file_is_met_at_the_koan_line", () => {
    const result = classify({
      error: { name: "TypeError" },
      koanSource: areaKoan,
      koanLine: 5,
      exercises: [],
      tree,
    })

    expect(result).toEqual({ status: "fail", at: 5, tag: null, write: null })
  })

  test("dunder_inside_a_template_expression_is_a_value_blank", () => {
    expect(classifyLine("  expect(label(r)).toBe(`${__} px`)")).toMatchObject({
      status: "blank",
      at: 6,
    })
  })

  test("dunder_in_template_text_is_not_a_blank", () => {
    expect(classifyLine("  expect(label(r)).toBe(`__ px`)")).toMatchObject({ status: "fail" })
  })

  test("dunder_in_a_trailing_comment_is_not_a_blank", () => {
    expect(classifyLine("  expect(area(r)).toBe(19) // was __")).toMatchObject({
      status: "fail",
      at: 6,
    })
  })

  test("a_double_slash_inside_a_string_does_not_hide_a_blank", () => {
    expect(classifyLine('  expect(link("http://x")).toBe(__)')).toMatchObject({
      status: "blank",
    })
  })
})
