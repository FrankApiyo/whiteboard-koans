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
  {#each TOOLS as { tool, label } (tool)}
    <button
      type="button"
      class="btn btn-sm"
      class:btn-primary={board.tool === tool}
      aria-pressed={board.tool === tool}
      onclick={() => (board.tool = tool)}
    >
      {label}
    </button>
  {/each}

  <ColorPicker colors={PALETTE} value={board.color} onpick={(color) => (board.color = color)} />

  <button
    type="button"
    class="btn btn-sm btn-error"
    disabled={board.selectedId === null}
    onclick={ondelete}
  >
    Delete
  </button>
</div>

<style>
  .toolbar {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 0.5rem;
  }
</style>
