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
  import { BOARD_HEIGHT, BOARD_WIDTH, type Point, type Shape } from "../js/types"

  interface Props {
    state: BoardState
    oncommit: (commit: Commit, before?: Shape) => void
    oncursor?: (point: Point) => void
  }

  let { state: board, oncommit, oncursor }: Props = $props()

  let canvas = $state<HTMLCanvasElement>()
  let tool = $state.raw<ToolState>({ mode: "idle" })
  let dragStart: Shape | undefined
  let dropAt: { id: string; x: number; y: number } | null = null

  const shapes = $derived(board.ordered())
  const drawn = $derived(tool.mode === "drawing" ? [...shapes, tool.draft] : shapes)

  $effect(() => {
    const ctx = canvas?.getContext("2d")
    if (canvas && ctx) fitCanvas(canvas, ctx, window.devicePixelRatio || 1)
  })

  $effect(() => {
    // >>> 05
    return __blank("05: redraw in the next frame", undefined);
    // <<< 05
  })

  type CanvasPointerEvent = PointerEvent & { currentTarget: HTMLCanvasElement }

  function boardPoint(event: CanvasPointerEvent): Point {
    return toBoard(event.clientX, event.clientY, event.currentTarget.getBoundingClientRect())
  }

  function down(event: CanvasPointerEvent) {
    if (!event.isPrimary || event.button !== 0) return
    // >>> 05
    __blank("05: capture and start");
    // <<< 05
    holdGrabbed()
  }

  function holdGrabbed() {
    const grabbed = tool.mode === "dragging" ? tool.id : null
    board.draggingId = grabbed
    dragStart = grabbed ? board.shapes.get(grabbed) : undefined
    if (board.tool === "select") board.selectedId = grabbed
  }

  function move(event: CanvasPointerEvent) {
    if (!event.isPrimary) return
    const point = boardPoint(event)
    dropAt = dragTarget(tool, point)
    if (dropAt) board.moveShape(dropAt.id, dropAt.x, dropAt.y)
    // >>> 05
    __blank("05: follow the pointer");
    // <<< 05
  }

  function up(event: CanvasPointerEvent) {
    // >>> 05
    __blank("05: finish on pointer up");
    // <<< 05
  }

  function cancel(event: PointerEvent) {
    if (event.isPrimary) finish(dropAt && { kind: "move", ...dropAt })
  }

  function finish(commit: Commit | null) {
    const before = dragStart
    tool = { mode: "idle" }
    board.draggingId = null
    dragStart = undefined
    dropAt = null
    if (commit) oncommit(commit, before)
  }
</script>

<div role="group" aria-label="Whiteboard">
  <!-- >>> 05 -->
  {__blank("05: the canvas element", "")}
  <!-- <<< 05 -->
</div>

<style>
  div > :global(canvas) {
    display: block;
    width: 100%;
    height: auto;
    touch-action: none;
    background: white;
    border-radius: 0.5rem;
  }
</style>
