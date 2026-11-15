import { expect, test } from "@playwright/test"
import {
  click,
  cursorOf,
  draw,
  drag,
  expectSameShapes,
  hover,
  people,
  person,
  pickTool,
  shapes,
  twoPeopleOnOneBoard,
  type Visitor,
} from "./board"

let visitors: Visitor[] = []

test.beforeEach(async ({ browser }) => {
  visitors = await twoPeopleOnOneBoard(browser)
})

test.afterEach(async () => {
  await Promise.all(visitors.map((visitor) => visitor.context.close()))
})

async function drawOneOfEach(ada: Visitor, lin: Visitor): Promise<string[]> {
  await draw(ada.page, "Rectangle", [{ x: 100, y: 100 }, { x: 400, y: 300 }])
  await expectSameShapes(ada.page, lin.page, 1)
  await draw(ada.page, "Ellipse", [{ x: 600, y: 100 }, { x: 900, y: 350 }])
  await expectSameShapes(ada.page, lin.page, 2)
  await draw(ada.page, "Line", [{ x: 100, y: 600 }, { x: 500, y: 800 }])
  await expectSameShapes(ada.page, lin.page, 3)
  await draw(ada.page, "Pen", [
    { x: 1000, y: 500 },
    { x: 1100, y: 650 },
    { x: 1250, y: 550 },
    { x: 1400, y: 700 },
  ])
  return expectSameShapes(ada.page, lin.page, 4)
}

test("a rectangle, an ellipse, a line and a pen stroke drawn by one person appear for the other", async () => {
  const [ada, lin] = visitors
  const described = await drawOneOfEach(ada, lin)

  expect(described).toEqual([
    expect.stringMatching(/^rectangle \d+ by \d+ at /),
    expect.stringMatching(/^ellipse \d+ by \d+ at /),
    expect.stringMatching(/^line from /),
    expect.stringMatching(/^pen stroke of \d+ points from /),
  ])
})

test("a shape dragged by one person moves for the other", async () => {
  const [ada, lin] = visitors
  await draw(ada.page, "Rectangle", [{ x: 200, y: 200 }, { x: 500, y: 400 }])
  const [before] = await expectSameShapes(ada.page, lin.page, 1)

  await pickTool(lin.page, "Select")
  await drag(lin.page, [{ x: 350, y: 300 }, { x: 750, y: 600 }])
  await expect(shapes(lin.page)).not.toHaveText([before])

  const [after] = await expectSameShapes(lin.page, ada.page, 1)
  expect(after).toMatch(/^rectangle \d+ by \d+ at /)
})

test("a shape deleted by one person disappears for the other", async () => {
  const [ada, lin] = visitors
  await draw(ada.page, "Rectangle", [{ x: 100, y: 100 }, { x: 400, y: 300 }])
  await draw(ada.page, "Ellipse", [{ x: 800, y: 400 }, { x: 1200, y: 700 }])
  await expectSameShapes(ada.page, lin.page, 2)

  await pickTool(ada.page, "Select")
  await click(ada.page, { x: 1000, y: 550 })
  const deleteButton = ada.page.getByRole("button", { name: "Delete" })
  await expect(deleteButton).toBeEnabled()
  await deleteButton.click()

  const [left] = await expectSameShapes(ada.page, lin.page, 1)
  expect(left).toMatch(/^rectangle /)
})

test("one person's pointer shows as a cursor with their name and colour for the other", async () => {
  const [ada, lin] = visitors
  const adaColor = await person(ada.page, "Ada").locator("[data-color]").getAttribute("data-color")
  expect(adaColor).toMatch(/^#[0-9a-f]{6}$/i)

  await hover(ada.page, { x: 800, y: 500 })

  const cursor = cursorOf(lin.page, "Ada")
  await expect(cursor).toBeVisible()
  await expect(cursor).toHaveText("Ada")
  await expect(cursor).toHaveAttribute("style", new RegExp(`--cursor-color: ${adaColor}`, "i"))
  await expect(cursorOf(ada.page, "Ada")).toHaveCount(0)
})

test("the people list shows both people, marks yourself, and drops whoever leaves", async () => {
  const [ada, lin] = visitors
  await expect(person(ada.page, "Ada")).toHaveText("Ada (you)")
  await expect(person(ada.page, "Lin")).toHaveText("Lin")
  await expect(person(lin.page, "Ada")).toHaveText("Ada")
  await expect(person(lin.page, "Lin")).toHaveText("Lin (you)")

  await hover(lin.page, { x: 800, y: 500 })
  await expect(cursorOf(ada.page, "Lin")).toBeVisible()

  await lin.context.close()

  await expect(people(ada.page)).toHaveCount(1)
  await expect(people(ada.page)).toHaveText(["Ada (you)"])
  await expect(cursorOf(ada.page, "Lin")).toHaveCount(0)
})

test("every shape is still there after a reload", async () => {
  const [ada, lin] = visitors
  const described = await drawOneOfEach(ada, lin)

  // The board saves in a 500 ms window after a change; waiting past it matches the manual check.
  await ada.page.waitForTimeout(1_000)
  await ada.page.reload()

  await expect(shapes(ada.page)).toHaveText(described)
  await expect(people(ada.page)).toHaveCount(2)
})
