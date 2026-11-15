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
  // >>> answer 14: render Board, place its canvas
  const live = createFakeLive()
  const props: BoardProps = { shapes: [rect()], sync_id: 1, me: ada, people: [ada, lin], live, ...overrides }
  const view = render(Board, props)
  const canvas = view.container.querySelector("canvas")
  if (!canvas) throw new Error("Board rendered no canvas")
  placeCanvas(canvas)
  return { ...view, live, props, canvas }
  // <<<
}
