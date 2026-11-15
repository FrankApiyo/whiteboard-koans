import type { BoardState } from "./board_state.svelte"
import type { Live } from "./live"
import { isDeletePayload, isMovePayload, isShape } from "./payloads"

const EVENTS = ["shape:added", "shape:moved", "shape:deleted"]

export function applyIncoming(state: BoardState, event: string, payload: unknown): void {
  // >>> 10
  __blank("10: apply each event by id, skipping the dragged shape");
  // <<< 10
}

export function listen(live: Live, state: BoardState): () => void {
  // >>> 10
  return __blank("10: handle the three shape events, and stop", () => {});
  // <<< 10
}
