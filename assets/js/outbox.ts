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
    if (isReply(reply) && reply.ok) return
    const restored = isReply(reply) && !reply.ok ? reply.shape : before
    if (restored) state.upsert(restored)
    else state.remove(id)
  }
}

export function sendAdd(live: Live, state: BoardState, shape: Shape): void {
  state.upsert(shape)
  live.pushEvent("shape:add", shape, onReply(state, shape.id, null))
}

export function sendMove(live: Live, state: BoardState, id: string, x: number, y: number): void {
  const before = state.shapes.get(id) ?? null
  state.moveShape(id, x, y)
  live.pushEvent("shape:move", { id, x, y }, onReply(state, id, before))
}

export function sendDelete(live: Live, state: BoardState, id: string): void {
  const before = state.shapes.get(id) ?? null
  state.remove(id)
  live.pushEvent("shape:delete", { id }, onReply(state, id, before))
}

export function makeCursorSender(live: Live, ms = 50): Throttled<[Point]> {
  return throttle(
    (p: Point) => live.pushEvent("cursor:move", { x: Math.round(p.x), y: Math.round(p.y) }),
    ms,
  )
}
