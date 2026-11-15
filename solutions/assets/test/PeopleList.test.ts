import { render, screen } from "@testing-library/svelte"
import { describe, expect, it } from "vitest"
import PeopleList from "../svelte/PeopleList.svelte"
import type { Me, Person } from "../js/types"

const ada: Person = { tab: "tab-ada", name: "Ada", color: "#e03131" }
const lin: Person = { tab: "tab-lin", name: "Lin", color: "#1971c2" }
const me: Me = { tab: ada.tab, name: ada.name, color: ada.color }

const names = () => screen.getAllByRole("listitem").map((li) => li.textContent?.trim())

describe("PeopleList", () => {
  it("lists everyone on the board and marks you", () => {
    render(PeopleList, { people: [ada, lin], me })
    expect(screen.getByRole("list", { name: "People on this board" })).toBeTruthy()
    expect(names()).toEqual(["Ada (you)", "Lin"])
  })

  it("counts the people", () => {
    render(PeopleList, { people: [ada, lin], me })
    expect(screen.getByText("2 here")).toBeTruthy()
  })

  it("shows just you before anyone is listed", () => {
    render(PeopleList, { people: [], me: { name: "Ada", color: "#e03131" } })
    expect(names()).toEqual(["Ada (you)"])
    expect(screen.getByText("1 here")).toBeTruthy()
  })

  it("shows each person's colour", () => {
    render(PeopleList, { people: [lin], me })
    const dot = screen.getByRole("listitem").querySelector("[data-color]") as HTMLElement
    expect(dot.dataset.color).toBe(lin.color)
    expect(dot.style.backgroundColor).not.toBe("")
  })
})
