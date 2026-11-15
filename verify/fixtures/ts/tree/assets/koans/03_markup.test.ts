import { expect } from "vitest"
import { render, screen } from "@testing-library/svelte"
import { test } from "@koans/runtime"
import PeopleList from "../svelte/PeopleList.svelte"

test("the list names everyone on the board", () => {
  render(PeopleList, { people: ["Ada", "Grace"] })
  expect(screen.getByText("Ada")).toBeTruthy()
}, { exercises: "03: people list" })
