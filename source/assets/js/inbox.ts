import type { BoardState } from "./board_state.svelte"
import type { Live } from "./live"
import { isDeletePayload, isMovePayload, isShape } from "./payloads"

const EVENTS = ["shape:added", "shape:moved", "shape:deleted"]

export function applyIncoming(state: BoardState, event: string, payload: unknown): void {
  switch (event) {
    case "shape:added":
      if (isShape(payload) && payload.id !== state.draggingId) state.upsert(payload)
      return
    case "shape:moved":
      if (isMovePayload(payload) && payload.id !== state.draggingId) {
        state.moveShape(payload.id, payload.x, payload.y)
      }
      return
    case "shape:deleted":
      if (isDeletePayload(payload) && payload.id !== state.draggingId) state.remove(payload.id)
      return
  }
}

export function listen(live: Live, state: BoardState): () => void {
  const refs = EVENTS.map((event) =>
    live.handleEvent(event, (payload) => applyIncoming(state, event, payload)),
  )
  return () => refs.forEach((ref) => live.removeHandleEvent(ref))
}
