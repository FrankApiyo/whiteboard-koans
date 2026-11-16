import { fireEvent, render, screen } from "@testing-library/svelte"
import { flushSync } from "svelte"
import { describe, expect, it, vi } from "vitest"
import Toolbar from "../svelte/Toolbar.svelte"
import { BoardState } from "../js/board_state.svelte"
import { PALETTE } from "../js/types"
import { ID_A, rect } from "./support/fixtures"

const button = (name: string) => screen.getByRole("button", { name }) as HTMLButtonElement

describe("Toolbar", () => {
  it("has a pressed-state button for each tool", () => {
    render(Toolbar, { state: new BoardState([], 1), ondelete: () => {} })
    expect(screen.getByRole("group", { name: "Drawing tools" })).toBeTruthy()
    expect(screen.queryByRole("toolbar")).toBeNull()
    const pressed = ["Select", "Rectangle", "Ellipse", "Line", "Pen"].map(
      (name) => button(name).getAttribute("aria-pressed"),
    )
    expect(pressed).toEqual(["true", "false", "false", "false", "false"])
  })

  it("choosing a tool sets it on the board state", async () => {
    const state = new BoardState([], 1)
    render(Toolbar, { state, ondelete: () => {} })
    await fireEvent.click(button("Ellipse"))
    expect(state.tool).toBe("ellipse")
    expect(button("Ellipse").getAttribute("aria-pressed")).toBe("true")
    expect(button("Select").getAttribute("aria-pressed")).toBe("false")
  })

  it("picking a colour sets it on the board state", async () => {
    const state = new BoardState([], 1)
    render(Toolbar, { state, ondelete: () => {} })
    await fireEvent.click(screen.getByRole("radio", { name: "Teal" }))
    expect(state.color).toBe(PALETTE[4])
  })

  it("delete is disabled until a shape is selected", async () => {
    const state = new BoardState([rect()], 1)
    const ondelete = vi.fn()
    render(Toolbar, { state, ondelete })
    expect(button("Delete").disabled).toBe(true)
    state.selectedId = ID_A
    flushSync()
    expect(button("Delete").disabled).toBe(false)
    await fireEvent.click(button("Delete"))
    expect(ondelete).toHaveBeenCalledOnce()
  })
})
