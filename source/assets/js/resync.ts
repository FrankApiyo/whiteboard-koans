import type { BoardState } from "./board_state.svelte"
import type { Shape } from "./types"

export function applyProps(
  state: BoardState,
  props: { sync_id: number; shapes: Shape[] },
): void {
  // >>> answer 13: replace everything when sync_id changes | default: undefined
  if (props.sync_id !== state.syncId) state.replaceAll(props.shapes, props.sync_id)
  // <<<
}
