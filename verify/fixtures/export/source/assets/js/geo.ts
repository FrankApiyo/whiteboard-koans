export interface Rect {
  w: number
  h: number
}

export function area(r: Rect): number {
  // >>> answer 02: area
  return r.w * r.h
  // <<<
}

export function label(r: Rect): string {
  // >>> answer 03: label | default: ""
  return `${r.w} by ${r.h}`
  // <<<
}
