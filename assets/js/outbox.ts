import type { BoardState } from "./board_state.svelte"
import type { Live } from "./live"
import { isReply } from "./payloads"
import { throttle, type Throttled } from "./throttle"
import type { Point, Shape } from "./types"

export function onReply(
  state: BoardState,
  id: string,
  before: Shape | null,
): (reply: unknown) => void {
  return (reply) => {
    // >>> 09
    __blank("09: keep, restore the server's shape, roll back or remove");
    // <<< 09
  }
}

export function sendAdd(live: Live, state: BoardState, shape: Shape): void {
  // >>> 09
  __blank("09: draw it now, push shape:add");
  // <<< 09
}

export function sendMove(
  live: Live,
  state: BoardState,
  id: string,
  x: number,
  y: number,
  before: Shape | null = state.shapes.get(id) ?? null,
): void {
  // >>> 09
  __blank("09: move it now, push shape:move");
  // <<< 09
}

export function sendDelete(live: Live, state: BoardState, id: string): void {
  // >>> 09
  __blank("09: remove it now, push shape:delete");
  // <<< 09
}

export function makeCursorSender(live: Live, ms = 50): Throttled<[Point]> {
  return throttle(
    (p: Point) => live.pushEvent("cursor:move", { x: Math.round(p.x), y: Math.round(p.y) }),
    ms,
  )
}
