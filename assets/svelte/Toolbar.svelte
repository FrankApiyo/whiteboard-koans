<script lang="ts">
  import ColorPicker from "./ColorPicker.svelte"
  import type { BoardState } from "../js/board_state.svelte"
  import { PALETTE, type Tool } from "../js/types"

  interface Props {
    state: BoardState
    ondelete: () => void
  }

  let { state: board, ondelete }: Props = $props()

  const TOOLS: { tool: Tool; label: string }[] = [
    { tool: "select", label: "Select" },
    { tool: "rect", label: "Rectangle" },
    { tool: "ellipse", label: "Ellipse" },
    { tool: "line", label: "Line" },
    { tool: "pen", label: "Pen" },
  ]
</script>

<div class="toolbar" role="group" aria-label="Drawing tools">
  <!-- >>> 04 -->
  {__blank("04: a button per tool", "")}
  <!-- <<< 04 -->

  <ColorPicker colors={PALETTE} value={board.color} onpick={(color) => (board.color = color)} />

  <!-- >>> 04 -->
  {__blank("04: a delete button", "")}
  <!-- <<< 04 -->
</div>

<style>
  .toolbar {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 0.5rem;
  }
</style>
