/*
Files this chapter touches
  - assets/svelte/Board.svelte: seed the board state once, the toolbar, the canvas, the people
    list
  - lib/easel_web/live/board_live.ex: render/1, svelte_props/1 (this chapter's Elixir koans)

live_svelte inside a LiveView. From the Phoenix course: mount/3 sets
assigns, render/1 turns them into HEEx, and a page renders twice, as plain HTML and then over
the socket (chapter 10, LiveView basics); <.header> and friends are function components
(chapter 03). On the server, <.svelte name="Board" props={...} /> writes a div whose data-props
is the props as JSON. Hooks run only after the socket joins, so the hook from assets/js/app.js
reads the connected render's data-props, mounts the component Vite built from Board.svelte,
and adds one prop the server never sends: live, the hook itself (pushEvent, handleEvent).
live_svelte's Vite plugin builds the components map app.js passes to getHooks, keyed by
file name, so name="Board" finds assets/svelte/Board.svelte.

Board is the root. It reads its props (given), builds the BoardState its children share, and
hands it down. Props go in as attributes, a callback prop is a function, and {people} is short
for people={people}. live_svelte hands over the props as one $state object, so shapes is a deep
proxy: seed from a plain copy, inside untrack to say a one-time read is meant (chapter 04):

    let { entries }: LogProps = $props()
    const recent = untrack(() => entries.slice(-10))

    <Row {entry} />
    <Pager total={entries.length} onnext={next} />

After the seed, Board's shapes change only through events and resyncs (chapters 10 and 13).

    Write:          assets/svelte/Board.svelte:20  (06: seed the board state once)
    Exercised by:   assets/koans/06_live_svelte.test.ts:81

API you'll use
  - element.dataset: div.dataset.name is the data-name attribute, "Board" on the board page
  - JSON.parse: JSON.parse('{"zone":"UTC","ticks":0}') is { zone: "UTC", ticks: 0 }
  - "key" in object: "zone" in { zone: "UTC" } is true, and "live" in { zone: "UTC" } is false
  - getHooks: getHooks({ default: [{ default: Clock }], filenames: ["../svelte/Clock.svelte"] })
    is { SvelteHook }, with Clock named after its file, as the Vite plugin's map names it
  - SvelteHook.mounted.call(hook): mounts as LiveView does after the join, hook.el the div;
    hook._instance.state is then the props, and unmount(hook._instance) tears it down
  - $props: let { count, onclear }: CounterProps = $props() reads a component's props
  - untrack: untrack(() => count * 2) reads count without making the caller depend on it
  - $state.snapshot: $state.snapshot(list) is a plain copy of a state proxy
  - new BoardState(shapes, syncId): chapter 04's shared state of one board
  - createFakeLive: given in assets/test/support/fake_live.ts, a live that records pushes
  - rerender: const { rerender } = render(Clock, props); await rerender({ zone: "CET" })
  - placeCanvas, pointer: chapter 05's helpers; a press and release on a shape selects it
  - rect(), ellipse(): the fixtures, described as "rectangle 200 by 100 at 100, 100" and
    "ellipse 200 by 100 at 400, 300"

Picture: lessons/svg/06_two_renders.svg
*/
import { expect } from "vitest"
import { test } from "@koans/runtime"
import { unmount } from "svelte"
import { render, screen } from "@testing-library/svelte"
import { getHooks } from "@koans/live_svelte_hooks"
import Board from "../svelte/Board.svelte"
import type { BoardProps, Person } from "../js/types"
import { createFakeLive, type FakeLive } from "../test/support/fake_live"
import { placeCanvas, pointer } from "../test/support/canvas"
import { ellipse, rect } from "../test/support/fixtures"

const ada: Person = { tab: "tab-ada", name: "Ada", color: "#e03131" }
const lin: Person = { tab: "tab-lin", name: "Lin", color: "#1971c2" }

function mountBoard(overrides: Partial<BoardProps> = {}) {
  const props = { shapes: [rect()], sync_id: 1, me: ada, people: [ada, lin], live: createFakeLive() }
  const view = render(Board, { ...props, ...overrides })
  const canvas = screen.getByRole("group", { name: "Whiteboard" }).querySelector("canvas")
  if (!canvas) throw new Error("The Whiteboard group holds no canvas element")
  placeCanvas(canvas)
  return { ...view, canvas }
}

type MountedHook = FakeLive & { el: HTMLElement; _instance?: { state: Record<string, unknown> } }

const described = (canvas: HTMLCanvasElement) =>
  [...canvas.querySelectorAll("li")].map((item) => item.textContent)

test("Fill Board.svelte's state and its canvas so the shapes from props reach the canvas, which lists each one for screen readers. 1. Seed one BoardState, once, from a plain copy of shapes and from sync_id. 2. Put a Canvas in the stage, before the cursor layer; Canvas.svelte's Props type says what it needs, and Board's script already holds each one.", () => {
  const { canvas } = mountBoard({ shapes: [ellipse(), rect()] })
  expect(described(canvas)).toEqual(["ellipse 200 by 100 at 400, 300", "rectangle 200 by 100 at 100, 100"])
}, { exercises: "06: the canvas" })

test("SvelteHook, which app.js builds with getHooks, mounts the component data-name names into the div's data-svelte-target, with the parsed data-props as its props plus live, the hook itself, which the server never sends.", () => {
  const el = document.createElement("div")
  el.dataset.name = "Board"
  el.dataset.props = JSON.stringify({ shapes: [rect()], sync_id: 7, me: ada, people: [ada] })
  el.innerHTML = "<div data-svelte-target></div>"
  document.body.append(el)
  const hook: MountedHook = { el, ...createFakeLive() }
  const { SvelteHook } = getHooks({ default: [{ default: Board }], filenames: ["../svelte/Board.svelte"] })
  try {
    SvelteHook.mounted.call(hook)
    const canvas = el.querySelector("[data-svelte-target]")?.querySelector("canvas")
    if (!canvas) throw new Error("The hook mounted no canvas inside data-svelte-target")
    const state = hook._instance?.state ?? {}
    expect(described(canvas)).toEqual(__)
    expect(state.sync_id).toBe(__)
    expect("live" in JSON.parse(el.dataset.props ?? "{}")).toBe(__)
    expect(state.live).toHaveProperty("el", el)
  } finally {
    if (hook._instance) unmount(hook._instance)
    el.remove()
  }
}, { exercises: "06: the canvas" })

test("Fill the toolbar slot in Board.svelte with a Toolbar that shares the canvas's state and can delete the selection: selecting the rect on the canvas enables Delete in the toolbar.", async () => {
  const { canvas } = mountBoard()
  const remove = screen.getByRole("button", { name: "Delete" }) as HTMLButtonElement
  expect(remove.disabled).toBe(true)
  await pointer(canvas, "pointerDown", 150, 130)
  await pointer(canvas, "pointerUp", 150, 130)
  expect(remove.disabled).toBe(false)
}, { exercises: ["06: the toolbar", "06: the canvas"] })

test("Fill the people slot in Board.svelte with a PeopleList of the people and me from props, so the list beside the board marks you.", () => {
  mountBoard()
  const list = screen.getByRole("list", { name: "People on this board" })
  const names = [...list.querySelectorAll("li")].map((item) => item.textContent?.trim())
  expect(names).toEqual(["Ada (you)", "Lin"])
}, { exercises: ["06: the people list", "06: the canvas"] })

test("Board seeds its state from props once: new shapes under the same sync_id leave the canvas as it was.", async () => {
  const { canvas, rerender } = mountBoard({ shapes: [rect()] })
  await rerender({ shapes: [ellipse()] })
  expect(described(canvas)).toEqual(__)
}, { exercises: "06: the canvas" })
