import { render, type RenderResult } from "@testing-library/svelte"
import Board from "../../svelte/Board.svelte"
import type { BoardProps, Person } from "../../js/types"
import { placeCanvas } from "./canvas"
import { createFakeLive, type FakeLive } from "./fake_live"
import { rect } from "./fixtures"

export const ada: Person = { tab: "tab-ada", name: "Ada", color: "#e03131" }
export const lin: Person = { tab: "tab-lin", name: "Lin", color: "#1971c2" }

export type BoardHarness = RenderResult<typeof Board> & {
  live: FakeLive
  props: BoardProps
  canvas: HTMLCanvasElement
}

export function renderBoard(overrides: Partial<Omit<BoardProps, "live">> = {}): BoardHarness {
  // >>> 14
  __blank("14: render Board, place its canvas");
  // <<< 14
}
