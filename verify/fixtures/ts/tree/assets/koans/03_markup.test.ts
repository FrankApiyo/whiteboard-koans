import { expect } from "vitest"
import { fireEvent, render, screen } from "@testing-library/svelte"
import { test } from "@koans/runtime"
import PeopleList from "../svelte/PeopleList.svelte"
import ClearButton from "../svelte/ClearButton.svelte"

test("the list names everyone on the board", () => {
  render(PeopleList, { people: ["Ada", "Grace"] })
  expect(screen.getByText("Ada")).toBeTruthy()
}, { exercises: "03: people list" })

test("clicking clear relabels the button", async () => {
  render(ClearButton)
  await fireEvent.click(screen.getByRole("button"))
  expect(screen.getByRole("button").textContent).toBe("Cleared")
})
