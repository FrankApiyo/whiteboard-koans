import { render, screen } from "@testing-library/svelte"
import { describe, expect, it } from "vitest"
import CursorLayer from "../svelte/CursorLayer.svelte"
import type { Cursors } from "../js/cursors"
import type { CursorPayload, Person } from "../js/types"

const ada: Person = { tab: "tab-ada", name: "Ada", color: "#e03131" }
const lin: Person = { tab: "tab-lin", name: "Lin", color: "#1971c2" }

const at = (person: Person, x: number, y: number): CursorPayload => ({ ...person, x, y })
const cursorsOf = (...payloads: CursorPayload[]): Cursors =>
  new Map(payloads.map((payload) => [payload.tab, payload]))

describe("CursorLayer", () => {
  it("labels each cursor with its name and places it on the board", () => {
    render(CursorLayer, { cursors: cursorsOf(at(ada, 800, 250)), people: [ada] })
    const cursor = screen.getByText("Ada").closest("[data-tab]") as HTMLElement
    expect(cursor.dataset.tab).toBe(ada.tab)
    expect(cursor.style.left).toBe("50%")
    expect(cursor.style.top).toBe("25%")
  })

  it("hides the cursor of someone who has left", () => {
    render(CursorLayer, { cursors: cursorsOf(at(ada, 1, 1), at(lin, 2, 2)), people: [lin] })
    expect(screen.queryByText("Ada")).toBeNull()
    expect(screen.getByText("Lin")).toBeTruthy()
  })

  it("keeps the same element when a cursor moves", async () => {
    const { rerender } = render(CursorLayer, {
      cursors: cursorsOf(at(ada, 0, 0), at(lin, 0, 0)),
      people: [ada, lin],
    })
    const before = screen.getByText("Lin").closest("[data-tab]")
    await rerender({ cursors: cursorsOf(at(lin, 160, 100)), people: [lin] })
    const after = screen.getByText("Lin").closest("[data-tab]") as HTMLElement
    expect(after).toBe(before)
    expect(after.style.left).toBe("10%")
  })
})
