/*
Files this chapter touches
  - assets/koans/drills/03_counter.svelte: a button that counts
  - assets/svelte/PeopleList.svelte: a row per person, just you
  - assets/svelte/ColorPicker.svelte: a radio per colour
  - assets/koans/drills/03_greeting.svelte: name, excited (given; read it)

Components and runes. A .svelte file is a component: a <script lang="ts"> block, then markup.
Props arrive through $props(), typed by an interface, and a default fills one left out:

    interface Props { name: string; excited?: boolean }
    let { name, excited = false }: Props = $props()
    <h1>Hello, {name}{excited ? "!" : "."}</h1>

That is the greeting drill: given name "Ada" it shows Hello, Ada. and excited: true ends it in !.
$state(0) makes a value the markup follows: assign to it and the page updates. $derived(expr) is
computed from the state and props it reads, and is current whenever it is read. Don't copy one
value into another from an $effect: the effect runs later, so the copy is stale until then. Runes
also work as class fields in .svelte.ts files; assets/js/board_state.svelte.ts keeps the board so.

{#if cond}...{:else}...{/if} shows markup on a condition. {#each items as item (item.id)} repeats
it, and the key in brackets lets Svelte move an item's element when the list is reordered instead
of rewriting every row. Attributes take expressions, checked={on}, and an event attribute takes a
function: <button onclick={() => (open = !open)}>Toggle</button>. A child calls a callback prop
such as onpick to tell its parent, and never assigns to its own props. Svelte batches DOM updates:
right after a click the counter drill, which starts at Clicked 0 times, still shows the old text,
until flushSync() applies the update.

    Write:          assets/koans/drills/03_counter.svelte:12  (03: a button that counts)
    Exercised by:   assets/koans/03_components_and_runes.svelte.test.ts:86

API you'll use
  - render: const { rerender } = render(Greeting, { name: "Ada" }) mounts it in the page
  - rerender: await rerender({ name: "Lin" }) hands the mounted component new props
  - screen.getByRole: screen.getByRole("button") is the one button, and throws when there is none
  - screen.getAllByRole: screen.getAllByRole("listitem") is every list item, in page order
  - fireEvent.click: await fireEvent.click(radio) clicks, then waits for Svelte to update
  - flushSync: flushSync() from svelte applies pending updates now
  - $props.id: const group = $props.id() is an id unique to each mounted instance
  - $effect.root: const stop = $effect.root(() => { ... }) hosts effects outside a component
  - style:background-color={c} sets one inline style; data-color={c} sets an attribute
  - aria-label={c} names an element, so screen.getByRole("radio", { name: c }) finds it
  - $derived: PeopleList shows {count} here, count = $derived(Math.max(people.length, 1))

Picture: none for this chapter; the lesson is on lessons/index.html too.
*/
import { expect } from "vitest"
import { test } from "@koans/runtime"
import { fireEvent, render, screen } from "@testing-library/svelte"
import { flushSync } from "svelte"
import Counter from "./drills/03_counter.svelte"
import Greeting from "./drills/03_greeting.svelte"
import ColorPicker from "../svelte/ColorPicker.svelte"
import PeopleList from "../svelte/PeopleList.svelte"
import { PALETTE, type Color, type Me, type Person } from "../js/types"

const ada: Person = { tab: "tab-ada", name: "Ada", color: "#e03131" }
const lin: Person = { tab: "tab-lin", name: "Lin", color: "#1971c2" }
const me: Me = { tab: ada.tab, name: ada.name, color: ada.color }

const rows = () => screen.getAllByRole("listitem")
const names = () => rows().map((li) => li.textContent?.trim())
const dotOf = (row: HTMLElement) => row.querySelector("[data-color]") as HTMLElement
const radios = () => screen.getAllByRole("radio") as HTMLInputElement[]

class Sheet {
  w = $state(200)
  h = $state(100)
  area = $derived(this.w * this.h)
}

class Doubler {
  n = $state(1)
  doubled = $derived(this.n * 2)
  copied = $state(0)
}

test("A component takes typed props, a prop with a default may be left out, and new props update what it shows.", async () => {
  const { rerender } = render(Greeting, { name: "Ada" })
  const heading = screen.getByRole("heading")
  expect(heading.textContent).toBe(__)
  await rerender({ name: "Ada", excited: true })
  expect(heading.textContent).toBe(__)
})

test("Fill the counter drill's button so each click adds step to count, and its label reads Clicked, the count, then times. 1. Open the drill on the Write: line. 2. Replace the __blank line with a button element whose onclick adds step to count, and keep the marker lines.", async () => {
  render(Counter, { step: 2 })
  const button = screen.getByRole("button")
  await fireEvent.click(button)
  await fireEvent.click(button)
  expect(button.textContent).toBe("Clicked 4 times")
}, { exercises: "03: a button that counts" })

test("Svelte batches DOM updates: right after a click the button still shows the old count, and flushSync applies the update.", () => {
  render(Counter)
  const button = screen.getByRole("button")
  button.click()
  expect(button.textContent).toBe(__)
  flushSync()
  expect(button.textContent).toBe(__)
}, { exercises: "03: a button that counts" })

test("A derived value is computed from the state it reads, and is current as soon as that state changes.", () => {
  const sheet = new Sheet()
  expect(sheet.area).toBe(__)
  sheet.w = 300
  expect(sheet.area).toBe(__)
})

test("A value copied in an effect lags: until effects run it holds the old copy, while a derived value is already current.", () => {
  const d = new Doubler()
  const stop = $effect.root(() => {
    $effect(() => {
      d.copied = d.n * 2
    })
  })
  try {
    flushSync()
    d.n = 4
    expect(d.doubled).toBe(__)
    expect(d.copied).toBe(__)
    flushSync()
    expect(d.copied).toBe(__)
  } finally {
    stop()
  }
})

test("PeopleList's count is derived from people, so its heading follows each new list and never says fewer than 1.", async () => {
  const { rerender } = render(PeopleList, { people: [ada, lin], me })
  const heading = screen.getByRole("heading")
  expect(heading.textContent).toBe(__)
  await rerender({ people: [], me })
  expect(heading.textContent).toBe(__)
})

test("Fill the rows in PeopleList: an each over people keyed by tab, a list item per person with a dot whose data-color and background colour are theirs, then the name, and your own row ends with you in round brackets.", () => {
  render(PeopleList, { people: [ada, lin], me })
  expect(names()).toEqual(["Ada (you)", "Lin"])
  const dot = dotOf(rows()[1])
  expect(dot.dataset.color).toBe("#1971c2")
  expect(dot.style.backgroundColor).toBe("rgb(25, 113, 194)")
}, { exercises: "03: a row per person" })

test("Fill just you in PeopleList: before presence lists anyone, an if block shows one row for me, marked the same way, and it is gone once anyone is listed.", async () => {
  const { rerender } = render(PeopleList, { people: [], me: { name: "Ada", color: "#e03131" } })
  expect(names()).toEqual(["Ada (you)"])
  expect(dotOf(rows()[0]).dataset.color).toBe("#e03131")
  await rerender({ people: [lin], me })
  expect(names()).toEqual(["Lin"])
}, { exercises: "03: just you" })

test("A keyed each moves an element with its key, so when people is reordered Lin's row is still the same element.", async () => {
  const { rerender } = render(PeopleList, { people: [ada, lin], me })
  const linRow = rows()[1]
  await rerender({ people: [lin, ada], me })
  expect(rows()[0] === linRow).toBe(__)
}, { exercises: "03: a row per person" })

test("Fill the radio in ColorPicker: one per colour and labelled by it, all named by group, each with its colour as the value, and checked only when it is the current value.", () => {
  render(ColorPicker, { colors: PALETTE, value: PALETTE[3], onpick: () => {} })
  expect(radios().map((r) => r.value)).toEqual([...PALETTE])
  expect(radios().filter((r) => r.checked).map((r) => r.value)).toEqual(["#2f9e44"])
  expect(new Set(radios().map((r) => r.name)).size).toBe(1)
}, { exercises: "03: a radio per colour" })

test("Choosing a radio fires its change event, which calls the onpick callback prop once with that radio's colour.", async () => {
  const picked: Color[] = []
  render(ColorPicker, { colors: PALETTE, value: PALETTE[0], onpick: (color) => picked.push(color) })
  await fireEvent.click(screen.getByRole("radio", { name: "#1971c2" }))
  expect(picked).toEqual(["#1971c2"])
}, { exercises: "03: a radio per colour" })

test("Each ColorPicker names its radio group with its own props id, so two pickers on one page keep a checked radio each.", () => {
  render(ColorPicker, { colors: PALETTE, value: PALETTE[0], onpick: () => {} })
  render(ColorPicker, { colors: PALETTE, value: PALETTE[1], onpick: () => {} })
  expect(new Set(radios().map((r) => r.name)).size).toBe(__)
  expect(radios().filter((r) => r.checked).length).toBe(__)
}, { exercises: "03: a radio per colour" })
