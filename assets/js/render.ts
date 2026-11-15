import { assertNever, BOARD_HEIGHT, BOARD_WIDTH, type Shape } from "./types"
import { bounds } from "./geometry"

export type Ctx = Pick<
  CanvasRenderingContext2D,
  | "strokeStyle"
  | "lineWidth"
  | "lineCap"
  | "lineJoin"
  | "clearRect"
  | "strokeRect"
  | "beginPath"
  | "ellipse"
  | "moveTo"
  | "lineTo"
  | "stroke"
  | "save"
  | "restore"
  | "setLineDash"
  | "setTransform"
>

const STROKE_WIDTH = 3
const SELECTION_PADDING = 6

export function fitCanvas(canvas: HTMLCanvasElement, ctx: Ctx, dpr: number): void {
  // >>> 05
  __blank("05: size the canvas");
  // <<< 05
}

export function drawShape(ctx: Ctx, s: Shape): void {
  // >>> 05
  __blank("05: draw each kind");
  // <<< 05
}

function drawSelection(ctx: Ctx, shapes: readonly Shape[], selectedId: string | null): void {
  const selected = shapes.find((s) => s.id === selectedId)
  if (!selected) return
  const { x, y, w, h } = bounds(selected)
  ctx.save()
  ctx.strokeStyle = "#868e96"
  ctx.lineWidth = 1
  ctx.setLineDash([6, 4])
  ctx.strokeRect(
    x - SELECTION_PADDING,
    y - SELECTION_PADDING,
    w + 2 * SELECTION_PADDING,
    h + 2 * SELECTION_PADDING,
  )
  ctx.restore()
}

export function drawBoard(ctx: Ctx, shapes: readonly Shape[], selectedId: string | null): void {
  // >>> 05
  __blank("05: clear then draw");
  // <<< 05
  drawSelection(ctx, shapes, selectedId)
}
