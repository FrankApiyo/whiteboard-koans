import { describe, expect, it } from "vitest"
import { listenCursors, pruneCursors, upsertCursor, type Cursors } from "../js/cursors"
import { createFakeLive } from "./support/fake_live"

const ada = { tab: "t1", name: "Ada", color: "#e03131", x: 1, y: 2 } as const
const bob = { tab: "t2", name: "Bob", color: "#1971c2", x: 3, y: 4 } as const

describe("upsertCursor", () => {
  it("adds and then replaces by tab, returning new maps", () => {
    const empty: Cursors = new Map()
    const one = upsertCursor(empty, ada)
    const moved = upsertCursor(one, { ...ada, x: 50 })
    expect(empty.size).toBe(0)
    expect(one.get("t1")?.x).toBe(1)
    expect(moved.get("t1")?.x).toBe(50)
  })
})

describe("pruneCursors", () => {
  it("keeps only cursors whose tab is still present", () => {
    const cursors = upsertCursor(upsertCursor(new Map(), ada), bob)
    const pruned = pruneCursors(cursors, [{ tab: "t2", name: "Bob", color: "#1971c2" }])
    expect([...pruned.keys()]).toEqual(["t2"])
    expect(cursors.size).toBe(2)
  })
})

describe("listenCursors", () => {
  it("feeds cursor:moved payloads to the updater and ignores malformed ones", () => {
    const live = createFakeLive()
    let cursors: Cursors = new Map()
    listenCursors(live, (update) => (cursors = update(cursors)))
    live.emit("cursor:moved", ada)
    live.emit("cursor:moved", { nope: true })
    expect([...cursors.keys()]).toEqual(["t1"])
  })

  it("returns a function that removes the listener", () => {
    const live = createFakeLive()
    const stop = listenCursors(live, () => {})
    expect(live.listenerCount("cursor:moved")).toBe(1)
    stop()
    expect(live.listenerCount("cursor:moved")).toBe(0)
  })
})
