import { moveTo } from "./geometry"
import { PALETTE, type Color, type Shape, type Tool } from "./types"

function byId(shapes: Iterable<Shape>): ReadonlyMap<string, Shape> {
  return new Map([...shapes].map((s) => [s.id, s]))
}

const zRank = (s: Shape): number => s.z ?? Number.MAX_SAFE_INTEGER

export class BoardState {
  shapes = $state.raw<ReadonlyMap<string, Shape>>(new Map())
  selectedId = $state<string | null>(null)
  tool = $state<Tool>("select")
  color = $state<Color>(PALETTE[0])
  draggingId = $state<string | null>(null)
  syncId = $state(0)

  constructor(shapes: Iterable<Shape>, syncId: number) {
    this.shapes = byId(shapes)
    this.syncId = syncId
  }

  upsert(shape: Shape): void {
    // >>> 04
    __blank("04: add or replace one");
    // <<< 04
  }

  remove(id: string): void {
    // >>> 04
    __blank("04: remove by id");
    // <<< 04
  }

  moveShape(id: string, x: number, y: number): void {
    // >>> 04
    __blank("04: move by id");
    // <<< 04
  }

  replaceAll(shapes: Iterable<Shape>, syncId: number): void {
    // >>> 04
    __blank("04: replace them all");
    // <<< 04
  }

  ordered(): Shape[] {
    // >>> 04
    __blank("04: sort by z");
    // <<< 04
  }

  snapshot(): Shape[] {
    // >>> 04
    __blank("04: copy the shapes");
    // <<< 04
  }
}
