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
  // >>> answer 05: size the canvas
  canvas.width = BOARD_WIDTH * dpr
  canvas.height = BOARD_HEIGHT * dpr
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
  // <<<
}

export function drawShape(ctx: Ctx, s: Shape): void {
  // >>> answer 05: draw each kind
  ctx.strokeStyle = s.color
  ctx.lineWidth = STROKE_WIDTH
  ctx.lineCap = "round"
  ctx.lineJoin = "round"

  switch (s.kind) {
    case "rect":
      ctx.strokeRect(s.x, s.y, s.w, s.h)
      return
    case "ellipse":
      ctx.beginPath()
      ctx.ellipse(s.x + s.w / 2, s.y + s.h / 2, s.w / 2, s.h / 2, 0, 0, Math.PI * 2)
      ctx.stroke()
      return
    case "line":
      ctx.beginPath()
      ctx.moveTo(s.x, s.y)
      ctx.lineTo(s.x + s.dx, s.y + s.dy)
      ctx.stroke()
      return
    case "pen":
      ctx.beginPath()
      ctx.moveTo(s.x, s.y)
      for (const [dx, dy] of s.points) ctx.lineTo(s.x + dx, s.y + dy)
      ctx.stroke()
      return
    default:
      assertNever(s)
  }
  // <<<
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
  // >>> answer 05: clear then draw
  ctx.clearRect(0, 0, BOARD_WIDTH, BOARD_HEIGHT)
  for (const shape of shapes) drawShape(ctx, shape)
  // <<<
  drawSelection(ctx, shapes, selectedId)
}
