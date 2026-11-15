/*
Files this chapter touches
  - assets/koans/drills/04_escape_key.svelte: listen for escape
  - assets/koans/drills/04_name_field.svelte: bind the name
  - assets/koans/drills/04_focus_field.svelte: field (given; read it)
  - assets/js/board_state.svelte.ts: upsert, replaceAll, remove, moveShape, ordered, snapshot
  - assets/svelte/Toolbar.svelte: a button per tool, a delete button

Effects, bindings and the toolbar. $effect(fn) runs fn after the component mounts, then again
after any state that fn read while it ran changes. Only synchronous reads count: a value read
later, in a timer or after an await, is not tracked. fn may return a cleanup function, which runs
before the next run and when the component is destroyed, so what an effect starts it also stops:

    $effect(() => {
      const id = setTimeout(() => (saved = true), delay)
      return () => clearTimeout(id)
    })

bind:value={name} ties an input to state both ways: typing sets name, and setting name changes
the field. bind:this={field} stores the element once it is mounted, so read it in an effect.
let name = $state(initial) reads initial once, and svelte-check warns state_referenced_locally.
When a one-time seed is what you mean, say so: $state(untrack(() => initial)).

$state proxies a plain object or array deeply, so a push inside it is seen. A Map, Set or
class instance is not proxied, so its .set is never seen (svelte/reactivity has SvelteMap).
$state.raw never proxies: only assigning a new value is seen. BoardState holds its shapes as
a raw ReadonlyMap and always assigns a new one. $state.snapshot(x) is a plain copy of a
proxy, for logging or structuredClone. In a koan, $effect.root(fn) hosts effects.

    Write:          assets/js/board_state.svelte.ts:25  (04: add or replace one)
    Exercised by:   assets/koans/04_effects_bindings_and_the_toolbar.svelte.test.ts:160

API you'll use
  - window.addEventListener: window.addEventListener("keydown", onKey) calls
    onKey(event: KeyboardEvent) on each key; <svelte:window onkeydown={onKey} /> does the same
    in markup, and Svelte removes that listener itself
  - window.removeEventListener: window.removeEventListener("keydown", onKey), the same function
  - event.key: "Escape" for the Escape key, "a" for the A key
  - unmount: const { unmount } = render(Drill) and unmount() destroys it, running its cleanups
  - screen.getByLabelText: screen.getByLabelText("Name") is the field labelled Name
  - fireEvent.input: await fireEvent.input(field, { target: { value: "Lin" } }) types Lin
  - new Map: new Map(scores).set("ada", 3) is a copy of scores with ada's entry set
  - .values: Math.max(...scores.values()) spreads a Map's values; insertion order is kept
  - .filter: [...scores].filter(([, n]) => n > 0) keeps the [key, value] pairs that pass
  - .has, .get: m.has(k) is true when k is a key; m.get(k) is its value or undefined
  - .sort: xs.sort((a, b) => rank(a) - rank(b)) sorts xs itself, so sort a copy
  - byId, zRank: given in board_state.svelte.ts: a Map by id, and z with no z ranked last
  - moveTo: moveTo(shape, x, y) from chapter 02 is a moved copy
  - class:name={cond} adds the class while cond is true; aria-pressed={cond} sets the attribute;
    Toolbar buttons use daisyUI: "btn btn-sm", plus btn-primary for the current tool and
    btn-error for Delete
  - vi.useFakeTimers: then vi.advanceTimersByTime(10) runs timers due in the next 10 ms

Picture: lessons/svg/04_effect_lifecycle.svg
*/
import { expect, vi } from "vitest"
import { test } from "@koans/runtime"
import { fireEvent, render, screen } from "@testing-library/svelte"
import { flushSync } from "svelte"
import EscapeKey from "./drills/04_escape_key.svelte"
import FocusField from "./drills/04_focus_field.svelte"
import NameField from "./drills/04_name_field.svelte"
import Toolbar from "../svelte/Toolbar.svelte"
import { BoardState } from "../js/board_state.svelte"
import { ellipse, ID_A, ID_B, rect } from "../test/support/fixtures"

const button = (name: string) => screen.getByRole("button", { name }) as HTMLButtonElement
const TOOL_NAMES = ["Select", "Rectangle", "Ellipse", "Line", "Pen"]
const pressed = () => TOOL_NAMES.map((name) => button(name).getAttribute("aria-pressed"))
const primary = () => TOOL_NAMES.filter((name) => button(name).classList.contains("btn-primary"))

class Pointer {
  x = $state(0)
  y = $state(0)
}

class Drafts {
  deep = $state<number[]>([])
  raw = $state.raw<number[]>([])
}

test("An effect re-runs when state it read while running changes; state read later, in a timer, is not tracked.", () => {
  vi.useFakeTimers()
  const pointer = new Pointer()
  const log: number[] = []
  const stop = $effect.root(() => {
    $effect(() => {
      log.push(pointer.x)
      setTimeout(() => log.push(pointer.y), 10)
    })
  })
  try {
    flushSync()
    vi.advanceTimersByTime(10)
    pointer.y = 5
    flushSync()
    pointer.x = 3
    flushSync()
    vi.advanceTimersByTime(10)
    expect(log).toEqual(__)
  } finally {
    stop()
    vi.useRealTimers()
  }
})

test("Fill the escape drill's effect so Escape on window calls onescape and other keys don't, and destroying the drill stops it. 1. Declare a handler that checks event.key. 2. Add it to window for keydown. 3. Return a cleanup that removes that same handler.", async () => {
  let escapes = 0
  const { unmount } = render(EscapeKey, { onescape: () => (escapes += 1) })
  await fireEvent.keyDown(window, { key: "a" })
  await fireEvent.keyDown(window, { key: "Escape" })
  expect(escapes).toBe(1)
  unmount()
  await fireEvent.keyDown(window, { key: "Escape" })
  expect(escapes).toBe(1)
})

test("Fill the name field, an input labelled Name whose value is bound to name: typing updates the greeting and Clear empties the field. name is seeded once from initial, so a new initial leaves what was typed alone.", async () => {
  const { rerender } = render(NameField, { initial: "Ada" })
  const field = screen.getByLabelText("Name") as HTMLInputElement
  expect(field.value).toBe("Ada")
  await fireEvent.input(field, { target: { value: "Lin" } })
  expect(screen.getByText("Hello, Lin")).toBeTruthy()
  await rerender({ initial: "Grace" })
  expect(field.value).toBe("Lin")
  await fireEvent.click(button("Clear"))
  expect(field.value).toBe("")
}, { exercises: "04: bind the name" })

test("bind:this hands the drill its input once it is mounted, and the effect that reads it runs after that, so focus lands in the field.", () => {
  render(FocusField)
  expect(document.activeElement === screen.getByLabelText("Title")).toBe(__)
})

test("A state array is a deep proxy that sees a push; a raw state array sees only a new array, and a snapshot is a copy that stays as it was.", () => {
  const drafts = new Drafts()
  const lengths: number[][] = []
  const stop = $effect.root(() => {
    $effect(() => {
      lengths.push([drafts.deep.length, drafts.raw.length])
    })
  })
  try {
    flushSync()
    drafts.deep.push(1)
    flushSync()
    drafts.raw.push(1)
    flushSync()
    drafts.raw = [...drafts.raw, 2]
    flushSync()
    expect(lengths).toEqual(__)
    const copy = $state.snapshot(drafts.deep)
    drafts.deep.push(2)
    expect(copy).toEqual(__)
  } finally {
    stop()
  }
})

test("Implement upsert and replaceAll in assets/js/board_state.svelte.ts so each assigns shapes a new Map: upsert adds or replaces one shape by id, and replaceAll swaps every shape and the sync id. shapes is only ever replaced, never changed, so the old map stays as it was.", () => {
  const state = new BoardState([], 1)
  const before = state.shapes
  state.upsert(rect())
  state.upsert(rect({ x: 9 }))
  expect(before.size).toBe(0)
  expect(state.shapes.size).toBe(1)
  expect(state.shapes.get(ID_A)?.x).toBe(9)
  state.replaceAll([ellipse()], 2)
  expect([...state.shapes.keys()]).toEqual([ID_B])
  expect(state.syncId).toBe(2)
})

test("Implement remove and moveShape: an unknown id leaves shapes as the same map, remove clears a selection only when it pointed at the removed shape, and moveShape upserts a moved copy.", () => {
  const state = new BoardState([rect(), ellipse()], 1)
  const before = state.shapes
  state.remove("no-such-id")
  state.moveShape("no-such-id", 1, 1)
  expect(state.shapes).toBe(before)
  state.moveShape(ID_B, 3, 4)
  expect(state.shapes.get(ID_B)).toMatchObject({ x: 3, y: 4 })
  expect(before.get(ID_B)).toMatchObject({ x: 400, y: 300 })
  state.selectedId = ID_A
  state.remove(ID_B)
  expect(state.selectedId).toBe(ID_A)
  state.remove(ID_A)
  expect(state.shapes.size).toBe(0)
  expect(state.selectedId).toBeNull()
})

test("Implement ordered and snapshot so each returns a new array of the shapes: ordered sorts by zRank, so local shapes with no z come last, and snapshot keeps map order.", () => {
  const state = new BoardState([rect({ id: ID_A, z: 5 }), ellipse({ id: ID_B, z: 1 })], 1)
  state.upsert(rect({ id: "local" }))
  expect(state.ordered().map((s) => s.id)).toEqual([ID_B, ID_A, "local"])
  const copy = state.snapshot()
  expect(copy.map((s) => s.id)).toEqual([ID_A, ID_B, "local"])
  copy.pop()
  expect(state.shapes.size).toBe(3)
})

test("Fill the tool buttons in Toolbar: an each over TOOLS keyed by tool, one button per tool labelled with its label, pressed and btn-primary while it is the board's tool, and a click makes it the tool.", async () => {
  const state = new BoardState([], 1)
  render(Toolbar, { state, ondelete: () => {} })
  expect(pressed()).toEqual(["true", "false", "false", "false", "false"])
  await fireEvent.click(button("Ellipse"))
  expect(state.tool).toBe("ellipse")
  expect(pressed()).toEqual(["false", "false", "true", "false", "false"])
  expect(primary()).toEqual(["Ellipse"])
}, { exercises: "04: a button per tool" })

test("Fill the delete button: disabled while nothing is selected, and a click calls ondelete. Setting selectedId from outside schedules the update as a click does, so the koan calls flushSync before it looks.", async () => {
  const state = new BoardState([rect()], 1)
  let deletes = 0
  render(Toolbar, { state, ondelete: () => (deletes += 1) })
  expect(button("Delete").disabled).toBe(true)
  state.selectedId = ID_A
  flushSync()
  expect(button("Delete").disabled).toBe(false)
  await fireEvent.click(button("Delete"))
  expect(deletes).toBe(1)
}, { exercises: "04: a delete button" })
