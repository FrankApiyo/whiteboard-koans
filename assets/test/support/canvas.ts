import { fireEvent } from "@testing-library/svelte"
import { vi } from "vitest"
import type { RecordingContext } from "./setup"

export interface Placement {
  left: number
  top: number
  width: number
  height: number
}

export const FULL_SIZE: Placement = { left: 0, top: 0, width: 1600, height: 1000 }

export function placeCanvas(canvas: HTMLCanvasElement, placement: Placement = FULL_SIZE): void {
  vi.spyOn(canvas, "getBoundingClientRect").mockReturnValue({
    ...placement,
    x: placement.left,
    y: placement.top,
    right: placement.left + placement.width,
    bottom: placement.top + placement.height,
    toJSON: () => placement,
  })
}

export function recorded(canvas: HTMLCanvasElement): RecordingContext {
  return canvas.getContext("2d") as unknown as RecordingContext
}

export function nextFrame(): Promise<void> {
  return new Promise((resolve) => requestAnimationFrame(() => resolve()))
}

type PointerKind = "pointerDown" | "pointerMove" | "pointerUp" | "pointerCancel"

export interface PointerOptions {
  pointerId?: number
  isPrimary?: boolean
  button?: number
}

export async function pointer(
  canvas: HTMLCanvasElement,
  kind: PointerKind,
  clientX: number,
  clientY: number,
  options: PointerOptions = {},
): Promise<void> {
  await fireEvent[kind](canvas, { clientX, clientY, pointerId: 1, isPrimary: true, button: 0, ...options })
}

export async function drag(canvas: HTMLCanvasElement, from: [number, number], to: [number, number]) {
  await pointer(canvas, "pointerDown", ...from)
  await pointer(canvas, "pointerMove", ...to)
  await pointer(canvas, "pointerUp", ...to)
}
