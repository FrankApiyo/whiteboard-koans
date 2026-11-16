import { fireEvent, render, screen } from "@testing-library/svelte"
import { describe, expect, it, vi } from "vitest"
import ColorPicker from "../svelte/ColorPicker.svelte"
import { COLOR_NAMES, PALETTE } from "../js/types"

const radio = (name: string) => screen.getByRole("radio", { name }) as HTMLInputElement

describe("ColorPicker", () => {
  it("offers every colour as a labelled radio in one group", () => {
    render(ColorPicker, { colors: PALETTE, value: PALETTE[0], onpick: () => {} })
    expect(screen.getByRole("group", { name: "Colour" })).toBeTruthy()
    const values = screen.getAllByRole("radio").map((r) => (r as HTMLInputElement).value)
    expect(values).toEqual([...PALETTE])
  })

  it("gives each picker its own radio group", () => {
    render(ColorPicker, { colors: PALETTE, value: PALETTE[0], onpick: () => {} })
    render(ColorPicker, { colors: PALETTE, value: PALETTE[1], onpick: () => {} })
    const names = new Set(screen.getAllByRole("radio").map((r) => (r as HTMLInputElement).name))
    expect(names.size).toBe(2)
    expect(screen.getAllByRole("radio").filter((r) => (r as HTMLInputElement).checked)).toHaveLength(2)
  })

  it("checks the current value only", () => {
    render(ColorPicker, { colors: PALETTE, value: PALETTE[3], onpick: () => {} })
    expect(radio("Green").checked).toBe(true)
    expect(screen.getAllByRole("radio").filter((r) => (r as HTMLInputElement).checked)).toHaveLength(1)
  })

  it("calls onpick with the chosen colour", async () => {
    const onpick = vi.fn()
    render(ColorPicker, { colors: PALETTE, value: PALETTE[0], onpick })
    await fireEvent.click(radio(COLOR_NAMES[PALETTE[5]]))
    expect(onpick).toHaveBeenCalledExactlyOnceWith(PALETTE[5])
  })
})
