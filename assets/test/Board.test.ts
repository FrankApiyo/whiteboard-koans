import { fireEvent, render, screen } from "@testing-library/svelte"
import { flushSync } from "svelte"
import { afterEach, describe, expect, it, vi } from "vitest"
import Board from "../svelte/Board.svelte"
import type { BoardProps, Person } from "../js/types"
import { createFakeLive, type FakeLive } from "./support/fake_live"
import { drag, placeCanvas, pointer } from "./support/canvas"
import { ellipse, ID_A, rect } from "./support/fixtures"

const ada: Person = { tab: "tab-ada", name: "Ada", color: "#e03131" }
const lin: Person = { tab: "tab-lin", name: "Lin", color: "#1971c2" }
const SHAPE_EVENTS = ["shape:added", "shape:moved", "shape:deleted"]
const RECT_TEXT = "rectangle 200 by 100 at 100, 100"
const ELLIPSE_TEXT = "ellipse 200 by 100 at 400, 300"

function propsFor(live: FakeLive, overrides: Partial<BoardProps> = {}): BoardProps {
  return { shapes: [rect()], sync_id: 1, me: ada, people: [ada, lin], live, ...overrides }
}

function renderBoard(overrides: Partial<BoardProps> = {}) {
  const live = createFakeLive()
  const props = propsFor(live, overrides)
  const view = render(Board, props)
  const canvas = screen.getByLabelText("Whiteboard") as HTMLCanvasElement
  placeCanvas(canvas)
  return { ...view, live, props, canvas }
}

const shown = (text: string) => screen.queryByText(text) !== null
const pushedNamed = (live: FakeLive, event: string) => live.pushed.filter((p) => p.event === event)

afterEach(() => {
  vi.useRealTimers()
})

describe("Board composition", () => {
  it("renders the toolbar, the shapes from props and the people", () => {
    renderBoard()
    expect(screen.getByRole("toolbar", { name: "Drawing tools" })).toBeTruthy()
    expect(shown(RECT_TEXT)).toBe(true)
    expect(screen.getByRole("list", { name: "People on this board" }).textContent).toContain("Lin")
  })

  it("applies incoming shape events", () => {
    const { live } = renderBoard()
    live.emit("shape:added", ellipse())
    live.emit("shape:deleted", { id: ID_A })
    flushSync()
    expect(shown(ELLIPSE_TEXT)).toBe(true)
    expect(shown(RECT_TEXT)).toBe(false)
  })

  it("shows the cursors of other people", () => {
    const { live, container } = renderBoard()
    live.emit("cursor:moved", { ...lin, x: 400, y: 500 })
    flushSync()
    const cursor = container.querySelector(`[data-tab="${lin.tab}"]`) as HTMLElement
    expect(cursor.textContent).toContain("Lin")
  })
})

describe("Board sending", () => {
  it("pushes a drawn shape as shape:add", async () => {
    const { live, canvas } = renderBoard({ shapes: [] })
    await fireEvent.click(screen.getByRole("button", { name: "Rectangle" }))
    await drag(canvas, [100, 100], [300, 250])
    const [add] = pushedNamed(live, "shape:add")
    expect(add.payload).toMatchObject({ kind: "rect", x: 100, y: 100, w: 200, h: 150 })
    expect(shown("rectangle 200 by 150 at 100, 100")).toBe(true)
  })

  it("deletes the selected shape", async () => {
    const { live, canvas } = renderBoard()
    await pointer(canvas, "pointerDown", 150, 130)
    await pointer(canvas, "pointerUp", 150, 130)
    await fireEvent.click(screen.getByRole("button", { name: "Delete" }))
    expect(pushedNamed(live, "shape:delete").map((p) => p.payload)).toEqual([{ id: ID_A }])
    expect(shown(RECT_TEXT)).toBe(false)
  })

  it("sends the pointer as cursor:move", async () => {
    const { live, canvas } = renderBoard()
    await pointer(canvas, "pointerMove", 400, 300)
    expect(pushedNamed(live, "cursor:move").map((p) => p.payload)).toEqual([{ x: 400, y: 300 }])
  })

  it("reply_ok_false_restores_server_shape_or_removes_local", async () => {
    const { live, canvas } = renderBoard()
    await drag(canvas, [150, 130], [250, 230])
    const [move] = pushedNamed(live, "shape:move")
    expect(move.payload).toEqual({ id: ID_A, x: 200, y: 200 })
    expect(shown("rectangle 200 by 100 at 200, 200")).toBe(true)
    move.onReply?.({ ok: false, shape: rect() })
    flushSync()
    expect(shown(RECT_TEXT)).toBe(true)

    await fireEvent.click(screen.getByRole("button", { name: "Ellipse" }))
    await drag(canvas, [500, 500], [600, 560])
    const [add] = pushedNamed(live, "shape:add")
    expect(shown("ellipse 100 by 60 at 500, 500")).toBe(true)
    add.onReply?.({ ok: false, shape: null })
    flushSync()
    expect(shown("ellipse 100 by 60 at 500, 500")).toBe(false)
  })
})

describe("Board props", () => {
  it("new_sync_id_replaces_the_whole_map", async () => {
    const { live, props, rerender } = renderBoard()
    live.emit("shape:added", ellipse())
    await rerender({ ...props, shapes: [], people: [ada] })
    expect([shown(RECT_TEXT), shown(ELLIPSE_TEXT)]).toEqual([true, true])

    await rerender({ ...props, shapes: [ellipse()], sync_id: 2 })
    expect([shown(RECT_TEXT), shown(ELLIPSE_TEXT)]).toEqual([false, true])
  })

  it("listeners_removed_on_destroy", async () => {
    vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout", "Date"] })
    const { live, canvas, unmount } = renderBoard()
    const counts = () => [...SHAPE_EVENTS, "cursor:moved"].map((e) => live.listenerCount(e))
    expect(counts()).toEqual([1, 1, 1, 1])

    await pointer(canvas, "pointerMove", 10, 10)
    await pointer(canvas, "pointerMove", 20, 20)
    expect(pushedNamed(live, "cursor:move")).toHaveLength(1)

    unmount()
    vi.advanceTimersByTime(1_000)
    expect(counts()).toEqual([0, 0, 0, 0])
    expect(pushedNamed(live, "cursor:move")).toHaveLength(1)
  })
})
