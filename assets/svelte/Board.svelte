<script lang="ts">
  import { onMount, untrack } from "svelte"
  import Canvas from "./Canvas.svelte"
  import CursorLayer from "./CursorLayer.svelte"
  import PeopleList from "./PeopleList.svelte"
  import Toolbar from "./Toolbar.svelte"
  import { BoardState } from "../js/board_state.svelte"
  import { listenCursors, type Cursors } from "../js/cursors"
  import { listen } from "../js/inbox"
  import { makeCursorSender, sendAdd, sendDelete, sendMove } from "../js/outbox"
  import { applyProps } from "../js/resync"
  import type { Commit } from "../js/tools"
  import { assertNever, type BoardProps, type Shape } from "../js/types"

  let { shapes, sync_id, me, people, live }: BoardProps = $props()

  // Props seed these once; later shapes arrive through applyProps and the live events.
  const board: BoardState =
    // >>> 06
    __blank("06: seed the board state once");
    // <<< 06
  const sendCursor = untrack(() => makeCursorSender(live))
  let cursors = $state.raw<Cursors>(new Map())

  // Shapes in props change only on a resync, so only sync_id is tracked.
  $effect(() => {
    const next = sync_id
    untrack(() => applyProps(board, { sync_id: next, shapes: $state.snapshot(shapes) }))
  })

  onMount(() => {
    const stopShapes = listen(live, board)
    const stopCursors = listenCursors(live, (update) => (cursors = update(cursors)))
    return () => {
      stopShapes()
      stopCursors()
      sendCursor.cancel()
    }
  })

  function commit(change: Commit, before?: Shape) {
    switch (change.kind) {
      case "add":
        return sendAdd(live, board, change.shape)
      case "move":
        return sendMove(live, board, change.id, change.x, change.y, before)
      default:
        return assertNever(change)
    }
  }

  function deleteSelected() {
    if (board.selectedId) sendDelete(live, board, board.selectedId)
  }
</script>

<div class="board">
  <!-- >>> 06 -->
  {__blank("06: the toolbar", "")}
  <!-- <<< 06 -->
  <div class="main">
    <div class="stage">
      <!-- >>> 06 -->
      {__blank("06: the canvas", "")}
      <!-- <<< 06 -->
      <CursorLayer {cursors} {people} />
    </div>
    <!-- >>> 06 -->
    {__blank("06: the people list", "")}
    <!-- <<< 06 -->
  </div>
</div>

<style>
  .board {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .main {
    display: grid;
    grid-template-columns: 1fr 10rem;
    gap: 1rem;
    align-items: start;
  }

  .stage {
    position: relative;
    border: 1px solid #dee2e6;
    border-radius: 0.5rem;
  }
</style>
