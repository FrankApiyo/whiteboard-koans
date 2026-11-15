import { moveTo } from "./geometry"
import type { Color, Shape, Tool } from "./types"

function byId(shapes: Iterable<Shape>): ReadonlyMap<string, Shape> {
  return new Map([...shapes].map((s) => [s.id, s]))
}

export class BoardState {
  shapes = $state.raw<ReadonlyMap<string, Shape>>(new Map())
  selectedId = $state<string | null>(null)
  tool = $state<Tool>("select")
  color = $state<Color>("#e03131")
  draggingId = $state<string | null>(null)
  syncId = $state(0)

  constructor(shapes: Iterable<Shape>, syncId: number) {
    this.shapes = byId(shapes)
    this.syncId = syncId
  }

  upsert(shape: Shape): void {
    this.shapes = new Map(this.shapes).set(shape.id, shape)
  }

  remove(id: string): void {
    if (!this.shapes.has(id)) return
    this.shapes = new Map([...this.shapes].filter(([key]) => key !== id))
    if (this.selectedId === id) this.selectedId = null
  }

  moveShape(id: string, x: number, y: number): void {
    const shape = this.shapes.get(id)
    if (shape) this.upsert(moveTo(shape, x, y))
  }

  replaceAll(shapes: Iterable<Shape>, syncId: number): void {
    this.shapes = byId(shapes)
    this.syncId = syncId
  }

  ordered(): Shape[] {
    return [...this.shapes.values()].sort(
      (a, b) => (a.z ?? Infinity) - (b.z ?? Infinity) || 0,
    )
  }

  snapshot(): Shape[] {
    return [...this.shapes.values()]
  }
}
