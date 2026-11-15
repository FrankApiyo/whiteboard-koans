import { expect, type Browser, type BrowserContext, type Locator, type Page } from "@playwright/test"

const BOARD_WIDTH = 1600
const BOARD_HEIGHT = 1000

export interface Visitor {
  context: BrowserContext
  page: Page
  name: string
}

export interface BoardPoint {
  x: number
  y: number
}

export type DrawingTool = "Rectangle" | "Ellipse" | "Line" | "Pen"

export async function visit(browser: Browser, name: string, path: string): Promise<Visitor> {
  const context = await browser.newContext()
  const page = await context.newPage()
  await page.goto(path)
  await expect(page).toHaveURL(/\/name$/)
  await page.getByLabel("Display name").fill(name)
  await page.getByRole("button", { name: "Continue" }).click()
  return { context, page, name }
}

export async function createBoard(visitor: Visitor, title: string): Promise<string> {
  const { page } = visitor
  await page.getByLabel("Board title").fill(title)
  await page.getByRole("button", { name: "Create board" }).click()
  await expect(page).toHaveURL(/\/b\/[^/]+$/)
  await expect(whiteboard(page)).toBeVisible()
  return new URL(page.url()).pathname
}

export async function joinBoard(browser: Browser, name: string, boardPath: string): Promise<Visitor> {
  const visitor = await visit(browser, name, boardPath)
  await expect(visitor.page).toHaveURL(boardPath)
  await expect(whiteboard(visitor.page)).toBeVisible()
  return visitor
}

export async function twoPeopleOnOneBoard(browser: Browser): Promise<[Visitor, Visitor]> {
  const ada = await visit(browser, "Ada", "/")
  const boardPath = await createBoard(ada, `Shared ${Date.now()}`)
  const lin = await joinBoard(browser, "Lin", boardPath)
  await expect(people(ada.page)).toHaveCount(2)
  await expect(people(lin.page)).toHaveCount(2)
  return [ada, lin]
}

export function whiteboard(page: Page): Locator {
  return page.getByRole("group", { name: "Whiteboard" })
}

// The describe() list is canvas fallback content, never rendered, so role queries skip it.
export function shapes(page: Page): Locator {
  return whiteboard(page).locator("canvas li")
}

export function people(page: Page): Locator {
  return page.getByRole("list", { name: "People on this board" }).getByRole("listitem")
}

export function person(page: Page, name: string): Locator {
  return people(page).filter({ hasText: name })
}

export function colorOf(page: Page, name: string): Promise<string | null> {
  return person(page, name).locator("[data-color]").getAttribute("data-color")
}

// Each sign-in draws a random palette colour, so signing in again can change it.
export async function signInAgain(visitor: Visitor, boardPath: string): Promise<void> {
  const { page } = visitor
  await page.goto("/name")
  await page.getByLabel("Display name").fill(visitor.name)
  await page.getByRole("button", { name: "Continue" }).click()
  await page.goto(boardPath)
  await expect(people(page)).toHaveCount(2)
}

export function cursorOf(page: Page, name: string): Locator {
  return page.locator(".cursor", { hasText: name })
}

export async function pickTool(page: Page, tool: DrawingTool | "Select"): Promise<void> {
  const button = page.getByRole("group", { name: "Drawing tools" }).getByRole("button", { name: tool })
  await button.click()
  await expect(button).toHaveAttribute("aria-pressed", "true")
}

async function toPage(page: Page, point: BoardPoint): Promise<BoardPoint> {
  const box = await whiteboard(page).locator("canvas").boundingBox()
  if (!box) throw new Error("The whiteboard canvas is not on screen")
  return {
    x: box.x + (point.x / BOARD_WIDTH) * box.width,
    y: box.y + (point.y / BOARD_HEIGHT) * box.height,
  }
}

export async function hover(page: Page, point: BoardPoint): Promise<void> {
  const at = await toPage(page, point)
  await page.mouse.move(at.x, at.y, { steps: 4 })
}

export async function drag(page: Page, path: readonly BoardPoint[]): Promise<void> {
  const [start, ...rest] = path
  await hover(page, start)
  await page.mouse.down()
  for (const point of rest) {
    const at = await toPage(page, point)
    await page.mouse.move(at.x, at.y, { steps: 6 })
  }
  await page.mouse.up()
}

export async function click(page: Page, point: BoardPoint): Promise<void> {
  await hover(page, point)
  await page.mouse.down()
  await page.mouse.up()
}

export async function draw(page: Page, tool: DrawingTool, path: readonly BoardPoint[]): Promise<void> {
  await pickTool(page, tool)
  await drag(page, path)
}

export async function expectSameShapes(from: Page, to: Page, count: number): Promise<string[]> {
  await expect(shapes(from)).toHaveCount(count)
  const described = await shapes(from).allTextContents()
  await expect(shapes(to)).toHaveText(described)
  return described
}
