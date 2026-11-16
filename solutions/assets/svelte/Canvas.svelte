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
  // One gesture at a time: a pen and a palm, or a mouse and a finger, are each primary.
  let activePointer: number | null = null

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
    if (!event.isPrimary || event.button !== 0 || activePointer !== null) return
    event.currentTarget.setPointerCapture(event.pointerId)
    const env = { color: board.color, newId: () => crypto.randomUUID(), shapes }
    tool = pointerDown(tool, board.tool, boardPoint(event), env)
    activePointer = event.pointerId
    holdGrabbed()
  }

  function holdGrabbed() {
    const grabbed = tool.mode === "dragging" ? tool.id : null
    dragStart = grabbed ? board.shapes.get(grabbed) : undefined
    if (board.tool === "select") board.selectedId = grabbed
  }

  function isOther(event: PointerEvent): boolean {
    return !event.isPrimary || (activePointer !== null && event.pointerId !== activePointer)
  }

  function move(event: CanvasPointerEvent) {
    if (isOther(event)) return
    const point = boardPoint(event)
    oncursor?.(point)
    tool = pointerMove(tool, point)
    followDrag(point)
  }

  // A press only becomes a drag once the shape moves, so a click never holds back other
  // people's ops for the shape under it.
  function followDrag(point: Point) {
    dropAt = dragTarget(tool, point)
    if (!dropAt || (!board.draggingId && isAtStart(dropAt))) return
    board.draggingId = dropAt.id
    board.moveShape(dropAt.id, dropAt.x, dropAt.y)
  }

  function isAtStart(at: Point): boolean {
    return dragStart !== undefined && at.x === dragStart.x && at.y === dragStart.y
  }

  function up(event: CanvasPointerEvent) {
    if (isOther(event) || activePointer === null) return
    finish(pointerUp(tool, boardPoint(event)).commit)
  }

  function cancel(event: PointerEvent) {
    if (!isOther(event) && activePointer !== null) finish(null)
  }

  function finish(gesture: Commit | null) {
    const commit: Commit | null =
      gesture ?? (board.draggingId && dropAt ? { kind: "move", ...dropAt } : null)
    const before = dragStart
    tool = { mode: "idle" }
    activePointer = null
    board.draggingId = null
    dragStart = undefined
    dropAt = null
    if (commit) oncommit(commit, before)
  }
</script>

<div role="group" aria-label="Whiteboard">
  <canvas
    bind:this={canvas}
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
