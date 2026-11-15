import { readdirSync, readFileSync } from "node:fs"
import path from "node:path"
import { describe, expect, test } from "vitest"
import { renderFooter, type FooterInput } from "../footer"

const goldens = "verify/fixtures/footer_golden"

const cases = readdirSync(goldens)
  .filter((name) => name.endsWith(".json"))
  .sort()

describe("renderFooter", () => {
  test("goldens_cover_every_footer_shape", () => {
    expect(cases.length).toBeGreaterThanOrEqual(7)
  })

  test.each(cases)("renders_%s_like_the_elixir_footer", (name) => {
    const input = JSON.parse(readFileSync(path.join(goldens, name), "utf8")) as FooterInput
    const text = readFileSync(path.join(goldens, name.replace(/\.json$/, ".txt")), "utf8")

    expect(renderFooter(input)).toBe(text.replace(/\n$/, ""))
  })
})
