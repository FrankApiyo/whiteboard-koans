<script lang="ts">
  import type { BoardState } from "../js/board_state.svelte"
  import { describe, toBoard } from "../js/geometry"
  import { drawBoard, fitCanvas } from "../js/render"
  import {
    dragTarget,
    pointerDown,
    pointerMove,
    pointerUp,
    type Commit,
    type ToolState,
  } from "../js/tools"
  import { BOARD_HEIGHT, BOARD_WIDTH, type Point } from "../js/types"

  interface Props {
    state: BoardState
    oncommit: (commit: Commit) => void
    oncursor?: (point: Point) => void
  }

  let { state: board, oncommit, oncursor }: Props = $props()

  let canvas = $state<HTMLCanvasElement>()
  let tool = $state.raw<ToolState>({ mode: "idle" })

  const shapes = $derived(board.ordered())
  const drawn = $derived(tool.mode === "drawing" ? [...shapes, tool.draft] : shapes)

  $effect(() => {
    const ctx = canvas?.getContext("2d")
    if (canvas && ctx) fitCanvas(canvas, ctx, window.devicePixelRatio || 1)
  })

  $effect(() => {
    const ctx = canvas?.getContext("2d")
    if (!ctx) return
    const toDraw = drawn
    const selectedId = board.selectedId
    const frame = requestAnimationFrame(() => drawBoard(ctx, toDraw, selectedId))
    return () => cancelAnimationFrame(frame)
  })

  type CanvasPointerEvent = PointerEvent & { currentTarget: HTMLCanvasElement }

  function boardPoint(event: CanvasPointerEvent): Point {
    return toBoard(event.clientX, event.clientY, event.currentTarget.getBoundingClientRect())
  }

  function down(event: CanvasPointerEvent) {
    event.currentTarget.setPointerCapture(event.pointerId)
    const env = { color: board.color, newId: () => crypto.randomUUID(), shapes }
    tool = pointerDown(tool, board.tool, boardPoint(event), env)
    const grabbed = tool.mode === "dragging" ? tool.id : null
    board.draggingId = grabbed
    if (board.tool === "select") board.selectedId = grabbed
  }

  function move(event: CanvasPointerEvent) {
    const point = boardPoint(event)
    oncursor?.(point)
    tool = pointerMove(tool, point)
    const target = dragTarget(tool, point)
    if (target) board.moveShape(target.id, target.x, target.y)
  }

  function up(event: CanvasPointerEvent) {
    const { state: next, commit } = pointerUp(tool, boardPoint(event))
    tool = next
    board.draggingId = null
    if (commit) oncommit(commit)
  }

  function cancel() {
    tool = { mode: "idle" }
    board.draggingId = null
  }
</script>

<canvas
  bind:this={canvas}
  aria-label="Whiteboard"
  style:aspect-ratio="{BOARD_WIDTH} / {BOARD_HEIGHT}"
  onpointerdown={down}
  onpointermove={move}
  onpointerup={up}
  onpointercancel={cancel}
>
  <ul>
    {#each shapes as shape (shape.id)}
      <li>{describe(shape)}</li>
    {/each}
  </ul>
</canvas>

<style>
  canvas {
    display: block;
    width: 100%;
    height: auto;
    touch-action: none;
    background: white;
    border-radius: 0.5rem;
  }
</style>
