import type { BoardState } from "./board_state.svelte"
import type { Shape } from "./types"

export function applyProps(
  state: BoardState,
  props: { sync_id: number; shapes: Shape[] },
): void {
  // >>> 13
  return __blank("13: replace everything when sync_id changes", undefined);
  // <<< 13
}
