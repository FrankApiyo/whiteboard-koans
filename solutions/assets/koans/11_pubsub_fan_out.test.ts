/*
Files this chapter touches
  - assets/js/throttle.ts: cancel, throttled
  - assets/js/outbox.ts: makeCursorSender
  - lib/easel/boards.ex (this chapter's Elixir koans)
  - lib/easel_web/live/board_live.ex (this chapter's Elixir koans)

Every change reaches every viewer. From the Phoenix course (chapter 14, PubSub and Presence):
PubSub sends one message to every process on a topic. Each BoardLive pushes the board's ops
to its browser (chapter 10); cursors go browser to browser the same way, but pointermove
fires far more often than a cursor needs, so the browser throttles its sends.

A throttle runs the first call at once, the leading edge, and holds later calls for a window
of ms milliseconds, keeping only the latest, which runs when the window ends, the trailing
edge, so the last position is never lost. After the window the next call leads again. A
debounce waits for the calls to stop instead, so a pointer moving steadily would never be
sent. This limiter keeps the leading edge only, and a cursor drawn with it stops short:

    function oncePer(fn: () => void, ms: number): () => void {
      let last = -Infinity
      return () => { if (Date.now() - last >= ms) { last = Date.now(); fn() } }
    }

throttle.ts keeps lastRun, held (the latest arguments) and timer; the given run(args) cancels
what waits, stamps lastRun with now(), Date.now by default, and calls fn. makeCursorSender(live,
ms = 50) pushes cursor:move through a throttle, x and y rounded, as the server takes integers
only: one per 50 ms. Board calls its cancel() when it unmounts. The throttle is the client
being polite; the server checks only for integers, and a rate limit there would drop the rest.

    Write:          assets/js/throttle.ts:28  (11: run now, or hold the latest call for the window's end)
    Exercised by:   assets/koans/11_pubsub_fan_out.test.ts:68

API you'll use
  - setTimeout, clearTimeout: const id = setTimeout(ring, 300) calls ring once, 300 ms on;
    clearTimeout(id) stops it first
  - ??=: x ??= y assigns y only while x is null or undefined
  - rest and spread: function log(...words: string[]) gets its arguments as an array, and
    log(...words) spreads one back into arguments
  - Math.round: Math.round(2.5) is 3 and Math.round(2.4) is 2
  - Object.assign: Object.assign(fn, { reset() {} }) is fn with a reset method
  - live.pushEvent: chapter 09
  - vi.useFakeTimers, vi.useRealTimers: fake setTimeout and Date.now until put back;
    vi.advanceTimersByTime(10) moves the clock 10 ms and runs what falls due, and
    vi.advanceTimersToNextTimer() moves it to the next timer and runs that;
    vi.getTimerCount() is how many fake timers wait
  - createFakeLive: given; live.pushed lists each push as { event, payload }

Picture: lessons/svg/11_fan_out.svg
*/
import { expect, vi } from "vitest"
import { test } from "@koans/runtime"
import { makeCursorSender } from "../js/outbox"
import { throttle } from "../js/throttle"
import { createFakeLive, type FakeLive } from "../test/support/fake_live"

const cursorMoves = (live: FakeLive) =>
  live.pushed.filter((p) => p.event === "cursor:move").map((p) => p.payload)

function withFakeTimers(run: () => void): void {
  vi.useFakeTimers()
  try {
    run()
  } finally {
    vi.useRealTimers()
  }
}

test("Implement cancel and throttled, the two halves of a throttle; the given run calls cancel first. 1. cancel clears any waiting timer. 2. throttled works out how much of the window is left since lastRun. 3. When none is left, it runs this call now. 4. Otherwise it holds these arguments and, unless a timer is already waiting, starts one for what is left that runs whatever is held then.", () => {
  withFakeTimers(() => {
    const calls: number[] = []
    const throttled = throttle((n: number) => calls.push(n), 50)
    throttled(1)
    expect(calls).toEqual([1])

    vi.advanceTimersByTime(30)
    throttled(2)
    throttled(3)
    expect(calls).toEqual([1])
    expect(vi.getTimerCount()).toBe(1)
    vi.advanceTimersByTime(19)
    expect(calls).toEqual([1])
    vi.advanceTimersByTime(1)
    expect(calls).toEqual([1, 3])
  })
})

test("A throttle sends no trailing call when nothing was held, and once the window has passed the next call leads again at once.", () => {
  withFakeTimers(() => {
    const calls: string[] = []
    const throttled = throttle((s: string) => calls.push(s), 50)
    throttled("a")
    vi.advanceTimersByTime(500)
    expect(calls).toEqual(["a"])

    throttled("b")
    expect(calls).toEqual(["a", "b"])
    throttled("c")
    vi.advanceTimersByTime(50)
    expect(calls).toEqual(["a", "b", "c"])
  })
})

test("A throttle reads the time from its injected clock, and a call that leads drops anything still held, so a stale position never lands after a newer one.", () => {
  withFakeTimers(() => {
    let t = 0
    const calls: string[] = []
    const throttled = throttle((s: string) => calls.push(s), 50, () => t)
    throttled("first")
    t = 10
    throttled("stale")
    t = 60
    throttled("fresh")
    expect(calls).toEqual(["first", "fresh"])

    vi.advanceTimersByTime(100)
    expect(calls).toEqual(["first", "fresh"])
  })
})

test("cancel, which a throttle's owner calls when it is done, clears any waiting timer, so nothing runs later and the next held call gets a timer of its own.", () => {
  withFakeTimers(() => {
    const calls: number[] = []
    const throttled = throttle((n: number) => calls.push(n), 50)
    throttled(1)
    throttled(2)
    throttled.cancel()
    expect(vi.getTimerCount()).toBe(0)
    vi.advanceTimersByTime(200)
    expect(calls).toEqual([1])

    throttled(3)
    throttled(4)
    vi.advanceTimersByTime(50)
    expect(calls).toEqual([1, 3, 4])
  })
})

test("Implement makeCursorSender so a pointer's moves go out as cursor:move with x and y rounded to whole numbers, through a throttle of ms milliseconds whose cancel drops a held move.", () => {
  withFakeTimers(() => {
    const live = createFakeLive()
    const send = makeCursorSender(live)
    send({ x: 10.4, y: 20.6 })
    send({ x: 11, y: 21 })
    send({ x: 12.5, y: 22.2 })
    expect(cursorMoves(live)).toEqual([{ x: 10, y: 21 }])
    vi.advanceTimersByTime(50)
    expect(cursorMoves(live)).toEqual([{ x: 10, y: 21 }, { x: 13, y: 22 }])

    send({ x: 30, y: 30 })
    send.cancel()
    vi.advanceTimersByTime(100)
    expect(cursorMoves(live)).toHaveLength(2)

    const slow = createFakeLive()
    const sendSlowly = makeCursorSender(slow, 200)
    sendSlowly({ x: 1, y: 1 })
    sendSlowly({ x: 2, y: 2 })
    vi.advanceTimersByTime(199)
    expect(cursorMoves(slow)).toEqual([{ x: 1, y: 1 }])
    vi.advanceTimersByTime(1)
    expect(cursorMoves(slow)).toEqual([{ x: 1, y: 1 }, { x: 2, y: 2 }])
  })
}, { exercises: "11: push cursor moves, throttled" })

test("A held move goes out one window after the move that led, and makeCursorSender's window is the default its signature gives ms.", () => {
  withFakeTimers(() => {
    const live = createFakeLive()
    const send = makeCursorSender(live)
    const start = Date.now()
    send({ x: 1, y: 1 })
    send({ x: 2, y: 2 })
    vi.advanceTimersToNextTimer()
    expect(cursorMoves(live)).toHaveLength(2)
    expect(Date.now() - start).toBe(50)
  })
}, { exercises: "11: push cursor moves, throttled" })
