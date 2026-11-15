export interface Rect {
  x: number
  y: number
  w: number
  h: number
}

export function area(r: Rect): number {
  return r.w * r.h
}

export function contains(r: Rect, px: number, py: number): boolean {
  __blank("01: hit test")
}
