import { fireEvent, screen } from "@testing-library/svelte"
import { flushSync } from "svelte"
import { afterEach, describe, expect, it, vi } from "vitest"
import type { FakeLive } from "./support/fake_live"
import { drag, pointer } from "./support/canvas"
import { ada, lin, renderBoard } from "./support/board_harness"
import { ellipse, ID_A, rect } from "./support/fixtures"

const SHAPE_EVENTS = ["shape:added", "shape:moved", "shape:deleted"]
const RECT_TEXT = "rectangle 200 by 100 at 100, 100"
const ELLIPSE_TEXT = "ellipse 200 by 100 at 400, 300"

const shown = (text: string) => screen.queryByText(text) !== null
const pushedNamed = (live: FakeLive, event: string) => live.pushed.filter((p) => p.event === event)

afterEach(() => {
  vi.useRealTimers()
})

describe("Board composition", () => {
  it("renders the toolbar, the shapes from props and the people", () => {
    renderBoard()
    expect(screen.getByRole("group", { name: "Drawing tools" })).toBeTruthy()
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

  it("a click on a shape still applies a move made meanwhile", async () => {
    const { live, canvas } = renderBoard()
    await pointer(canvas, "pointerDown", 150, 130)
    live.emit("shape:moved", { id: ID_A, x: 600, y: 600 })
    await pointer(canvas, "pointerUp", 150, 130)
    flushSync()
    expect(shown("rectangle 200 by 100 at 600, 600")).toBe(true)
    expect(pushedNamed(live, "shape:move")).toHaveLength(0)
  })

  it("a drag that comes back to its start still sends its final position", async () => {
    const { live, canvas } = renderBoard()
    await pointer(canvas, "pointerDown", 150, 130)
    await pointer(canvas, "pointerMove", 250, 230)
    await pointer(canvas, "pointerMove", 150, 130)
    await pointer(canvas, "pointerUp", 150, 130)
    const moves = pushedNamed(live, "shape:move").map((p) => p.payload)
    expect(moves).toEqual([{ id: ID_A, x: 100, y: 100 }])
  })

  it("a malformed reply to a drag restores the position from before the drag", async () => {
    const { live, canvas } = renderBoard()
    await drag(canvas, [150, 130], [250, 230])
    const [move] = pushedNamed(live, "shape:move")
    move.onReply?.("garbage")
    flushSync()
    expect(shown(RECT_TEXT)).toBe(true)
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

  it("a resync without the selected shape clears the selection", async () => {
    const { props, rerender, canvas } = renderBoard()
    const deleteButton = screen.getByRole("button", { name: "Delete" }) as HTMLButtonElement
    await pointer(canvas, "pointerDown", 150, 130)
    await pointer(canvas, "pointerUp", 150, 130)
    expect(deleteButton.disabled).toBe(false)

    await rerender({ ...props, shapes: [ellipse()], sync_id: 2 })
    expect(deleteButton.disabled).toBe(true)
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
