/*
Files this chapter touches
  - assets/test/support/board_harness.ts: renderBoard
  - test/support/board_helpers.ex (this chapter's Elixir koans)

Testing at three heights. Most tests are pure: geometry, guards, the tool machine and the throttle
are functions over plain data. Components run in jsdom with Testing Library, as the Phoenix
course's LiveView tests (chapter 22, testing the app) ran with no browser: render mounts one,
queries find elements by role and name as a person would, and a fake live records pushes and plays
events. Only the Playwright suite in e2e/ runs the real thing, the solved app and two browsers,
and only there do Board and BoardLive meet: LiveViewTest runs no JavaScript and Vitest fakes live,
so a renamed event or prop passes both and fails only here.

A harness puts the setup every test of a component repeats in one function. A Toolbar harness:

    function renderToolbar(tool: Tool = "select") {
      const state = new BoardState([], 1)
      state.tool = tool
      return { ...render(Toolbar, { state, ondelete: () => {} }), state }
    }

renderBoard is Board's: the overrides a test gives laid over default props, Board rendered, and
its canvas found in the render's own container, so two Boards can share a page. Board.test in
assets/test uses it (KOANS_LIB=solutions/lib npm run test:app here, npm test once exported). The
e2e suite never uses the dev server: playwright.config.ts starts its own, with MIX_ENV "e2e" on
port 4100 and its own database. collaboration.spec.ts checks what only a real browser can, such as
"every shape is still there after a reload": a fresh mount. Before each test, e2e/board.ts signs
two people in, each in its own browser context (own cookies, so two names).

    Write:          assets/test/support/board_harness.ts:19  (14: render Board, place its canvas)
    Exercised by:   assets/koans/14_testing_the_whole_thing.test.ts:63

API you'll use
  - render, within: render(Toolbar, props) answers container, rerender, unmount and queries;
    within(container).getByRole("button", { name: "Pen" }) looks inside that render only
  - container.querySelector("canvas"): its first canvas element, or null
  - createFakeLive, placeCanvas, rect, ada, lin: given; the default props are rect() on the
    board, sync_id 1, ada as me and ada and lin as the people
  - vi.useFakeTimers, vi.advanceTimersByTime, vi.useRealTimers: chapter 11
  - aria-pressed: a tool button's is "true" while it is the tool; the people list reads
    "Ada (you)" and "Lin"
  - readFileSync: readFileSync("e2e/board.ts", "utf8") is that file's text, read from the
    repository's root
  - drag, pointer: chapter 05; a Rectangle drag from 100, 100 to 300, 250 draws
    "rectangle 200 by 150 at 100, 100"

Picture: lessons/svg/14_test_layers.svg
*/
import { readFileSync } from "node:fs"
import { expect, vi } from "vitest"
import { test } from "@koans/runtime"
import { flushSync } from "svelte"
import { fireEvent, within } from "@testing-library/svelte"
import { ada, lin, renderBoard } from "../test/support/board_harness"
import type { FakeLive } from "../test/support/fake_live"
import { drag, pointer } from "../test/support/canvas"
import { rect } from "../test/support/fixtures"

const described = (canvas: HTMLCanvasElement) =>
  [...canvas.querySelectorAll("li")].map((item) => item.textContent)
const pushedNamed = (live: FakeLive, event: string) => live.pushed.filter((p) => p.event === event)

test("Implement renderBoard, the harness for Board tests. 1. Make a fake live. 2. Lay the overrides over the default props, with that live. 3. Render Board with them. 4. Find the canvas in the render's own container, and place it. 5. Answer the render result spread out, with live, props and canvas.", async () => {
  const { live, props, canvas, container } = renderBoard({ people: [ada] })

  expect(props).toEqual({ shapes: [rect()], sync_id: 1, me: ada, people: [ada], live })
  expect(container.contains(canvas)).toBe(true)
  expect(described(canvas)).toEqual(["rectangle 200 by 100 at 100, 100"])
  expect(canvas.getBoundingClientRect().width).toBe(1600)
  await pointer(canvas, "pointerMove", 400, 300)
  expect(pushedNamed(live, "cursor:move").map((p) => p.payload)).toEqual([{ x: 400, y: 300 }])
})

test("Two Boards on two fake lives, with the koan playing the server between them: Ada draws, the koan plays her shape:add back to both Boards as shape:added, and Lin's canvas shows it.", async () => {
  const mine = renderBoard({ shapes: [] })
  const theirs = renderBoard({ shapes: [], me: lin })
  await fireEvent.click(within(mine.container).getByRole("button", { name: "Rectangle" }))
  await drag(mine.canvas, [100, 100], [300, 250])

  const [add] = pushedNamed(mine.live, "shape:add")
  expect(pushedNamed(theirs.live, "shape:add")).toEqual([])
  expect(described(theirs.canvas)).toEqual([])
  for (const board of [mine, theirs]) board.live.emit("shape:added", { ...add.payload, z: 0 })
  flushSync()
  expect(described(theirs.canvas)).toEqual(_a(["rectangle 200 by 150 at 100, 100"]))
})

test("Fake timers step over the cursor throttle: two quick moves push the first at once and hold the second, and unmounting Board cancels the held one, so a second later only one cursor:move has gone out.", async () => {
  vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout", "Date"] })
  try {
    const { live, canvas, unmount } = renderBoard()
    await pointer(canvas, "pointerMove", 10, 10)
    await pointer(canvas, "pointerMove", 20, 20)
    unmount()
    vi.advanceTimersByTime(1_000)
    expect(pushedNamed(live, "cursor:move").length).toBe(_a(1))
  } finally {
    vi.useRealTimers()
  }
})

test("Tests find Board's parts as a person does, by role and name: the group Drawing tools, whose pressed tool has aria-pressed true, and the list People on this board.", async () => {
  const page = within(renderBoard().container)
  const tools = within(page.getByRole("group", { name: "Drawing tools" }))
  await fireEvent.click(tools.getByRole("button", { name: "Pen" }))

  expect(tools.getByRole("button", { name: "Pen" }).getAttribute("aria-pressed")).toBe(_a("true"))
  const people = within(page.getByRole("list", { name: "People on this board" }))
  const names = people.getAllByRole("listitem").map((item) => item.textContent?.trim())
  expect(names).toEqual(_a(["Ada (you)", "Lin"]))
})

test("The Playwright suite is read here, never run: it starts the app with MIX_ENV e2e on port 4100, one of its tests reloads the page, and before each test two people sign in, each in a browser context of its own.", () => {
  const config = readFileSync("playwright.config.ts", "utf8")
  const spec = readFileSync("e2e/collaboration.spec.ts", "utf8")
  const helpers = readFileSync("e2e/board.ts", "utf8")

  expect(/const port = (\d+)/.exec(config)?.[1]).toBe(_a("4100"))
  expect(config).toContain('MIX_ENV: "e2e"')
  expect(/^test\("(every shape[^"]*)"/m.exec(spec)?.[1]).toBe(_a("every shape is still there after a reload"))
  expect(spec).toContain("visitors = await twoPeopleOnOneBoard(browser)")
  expect(helpers).toContain("const context = await browser.newContext()")
})
