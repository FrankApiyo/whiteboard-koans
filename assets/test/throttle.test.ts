import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { throttle } from "../js/throttle"

describe("throttle", () => {
  beforeEach(() => vi.useFakeTimers())
  afterEach(() => vi.useRealTimers())

  it("calls at once on the leading edge", () => {
    const fn = vi.fn()
    throttle(fn, 100)("a")
    expect(fn).toHaveBeenCalledWith("a")
  })

  it("holds calls inside the window and fires the latest one on the trailing edge", () => {
    const fn = vi.fn()
    const throttled = throttle(fn, 100)
    throttled(1)
    throttled(2)
    throttled(3)
    expect(fn).toHaveBeenCalledTimes(1)
    vi.advanceTimersByTime(100)
    expect(fn.mock.calls).toEqual([[1], [3]])
  })

  it("does not fire a trailing call when nothing was held back", () => {
    const fn = vi.fn()
    throttle(fn, 100)(1)
    vi.advanceTimersByTime(500)
    expect(fn).toHaveBeenCalledTimes(1)
  })

  it("leads again once the window has passed", () => {
    const fn = vi.fn()
    const throttled = throttle(fn, 100)
    throttled(1)
    vi.advanceTimersByTime(150)
    throttled(2)
    expect(fn.mock.calls).toEqual([[1], [2]])
  })

  it("reads time from the injected clock", () => {
    let t = 1000
    const fn = vi.fn()
    const throttled = throttle(fn, 100, () => t)
    throttled(1)
    t = 1200
    throttled(2)
    expect(fn.mock.calls).toEqual([[1], [2]])
  })
})
