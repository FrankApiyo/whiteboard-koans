/*
Files this chapter touches
  - assets/js/guards.ts: isRecord, isFiniteNumber, isString, isColor
  - assets/js/types.ts: PALETTE, Color, Tool (given; read them)

TypeScript basics. TypeScript is JavaScript plus types that the compiler checks and then erases,
so a type never changes what runs. Annotate a binding (const width: number = 1600) or let the
compiler infer it: let title = "Easel" is a string, but const title = "Easel" has the literal
type "Easel", as it can't change. A type alias names a type: Tool is the union of five literal
types "select" | "rect" | "ellipse" | "line" | "pen". An interface names an object's shape;
z?: number is an optional field that reads as undefined when missing, and "z" in shape is false
then. readonly forbids writes, but only at compile time: Object.freeze(x) is the run-time lock and
Object.isFrozen(x) asks for it. Record<Tool, string> holds one string per tool, and
(value: unknown) => boolean is a function type. Array entries widen to string like a let, so
types.ts writes PALETTE, the 8 strings "#e03131", "#f08c00", ... "#c2255c", with as const: each
entry keeps its literal type and the array becomes readonly. (typeof PALETTE)[number] is Color,
their union. In a type, typeof X is the type of the value X; in code, typeof is a run-time check.

Data from the server arrives as unknown, which you can't read until a type guard narrows it. A
guard returns a boolean, and its return type says what true proves:

    function isPoint(value: unknown): value is Point {
      return isRecord(value) && isFiniteNumber(value.x) && isFiniteNumber(value.y)
    }

typeof answers with a string such as "number", "string" or "object", and "object" covers null
and arrays too; NaN and Infinity are a "number". The koans build shapes with rect() from
assets/test/support/fixtures.ts, and rect({ z: 3 }) overrides one field.

    Write:          assets/js/guards.ts:17  (01: string check)
    Exercised by:   assets/koans/01_typescript_basics.test.ts:62

API you'll use
  - typeof: typeof 3 is "number", typeof null is "object"
  - === and !==: compare with these; == converts types first, so 0 == "" is true
  - Array.isArray: Array.isArray([]) is true, Array.isArray({}) is false
  - Number.isFinite: Number.isFinite(1) is true, Number.isFinite(Number.NaN) is false
  - .some: ["a", "b"].some((s) => s === "b") is true; PALETTE.includes(value) won't compile
    for an unknown value, because includes takes a Color, while .some can compare anything
  - Object.keys: Object.keys({ a: 1, b: 2 }) is ["a", "b"]
  - Object.freeze and Object.isFrozen: Object.isFrozen(Object.freeze([1])) is true
  - JSON.parse: JSON.parse('{"x": 1}') is { x: 1 }, typed any

Picture: none for this chapter; the lesson is on lessons/index.html too.
*/
import { expect } from "vitest"
import { test } from "@koans/runtime"
import { isColor, isFiniteNumber, isRecord, isString } from "../js/guards"
import { BOARD_WIDTH, PALETTE, type Color, type Tool } from "../js/types"
import { rect } from "../test/support/fixtures"

test("An annotation is erased before the code runs, so typeof sees only the value, and it reports null and arrays as object.", () => {
  const width: number = BOARD_WIDTH
  const title = "Easel"
  expect(typeof width).toBe(__)
  expect(typeof title).toBe(__)
  expect(typeof null).toBe(__)
  expect(typeof [1, 2]).toBe(__)
  expect(Array.isArray([1, 2])).toBe(__)
})

test("Implement isString in assets/js/guards.ts so it is true for strings only: return one typeof comparison.", () => {
  expect(isString("")).toBe(true)
  expect(isString("pen")).toBe(true)
  expect(isString(1)).toBe(false)
  expect(isString(undefined)).toBe(false)
})

test("Implement isRecord so it is true for a plain object and false for null, an array or anything else. Its return type, value is Record<string, unknown>, lets a caller read any field as unknown once it returns true.", () => {
  expect(isRecord({ x: 1 })).toBe(true)
  expect(isRecord({})).toBe(true)
  expect(isRecord(null)).toBe(false)
  expect(isRecord([])).toBe(false)
  expect(isRecord("x")).toBe(false)
})

test("PALETTE holds eight strings, and its first entry can be stored as a Color.", () => {
  const first: Color = PALETTE[0]
  expect(first).toBe(__)
  expect(PALETTE.length).toBe(__)
})

test("Implement isColor so it is true for the eight palette strings and nothing else. A value that passes can be stored as a Color with no cast.", () => {
  for (const color of PALETTE) expect(isColor(color)).toBe(true)
  expect(isColor("#000000")).toBe(false)
  expect(isColor("#E03131")).toBe(false)
  expect(isColor(undefined)).toBe(false)
})

test("NaN and Infinity are numbers to typeof, so a coordinate check needs more than typeof.", () => {
  expect(typeof Number.NaN).toBe(__)
  expect(Number.isFinite(Infinity)).toBe(__)
  expect(Number.isFinite(1600)).toBe(__)
})

test("Implement isFiniteNumber so it is true for ordinary numbers only. NaN, Infinity and a numeric string are not coordinates.", () => {
  expect(isFiniteNumber(3)).toBe(true)
  expect(isFiniteNumber(0)).toBe(true)
  expect(isFiniteNumber(-2.5)).toBe(true)
  expect(isFiniteNumber(Number.NaN)).toBe(false)
  expect(isFiniteNumber(Infinity)).toBe(false)
  expect(isFiniteNumber("3")).toBe(false)
})

test("A Record keyed by a union needs an entry for every member, and a variable of the union type indexes it safely.", () => {
  const keys: Record<Tool, string> = { select: "v", rect: "r", ellipse: "o", line: "l", pen: "p" }
  const tool: Tool = "ellipse"
  expect(keys[tool]).toBe(__)
  expect(Object.keys(keys).length).toBe(__)
})

test("An optional field may be missing: it reads as undefined, and the in operator tells missing from present.", () => {
  const flat = rect()
  const stacked = rect({ z: 3 })
  expect(flat.z).toBe(__)
  expect("z" in flat).toBe(__)
  expect(stacked.z).toBe(__)
})

test("readonly and as const are rules for the compiler: nothing freezes the palette at run time.", () => {
  expect(Object.isFrozen(PALETTE)).toBe(__)
  expect(Object.isFrozen(Object.freeze(["#e03131"]))).toBe(__)
})

test("A function is a value with a type of its own, so all four guards fit one array of functions from unknown to boolean.", () => {
  const guards: ((value: unknown) => boolean)[] = [isRecord, isFiniteNumber, isString, isColor]
  expect(guards.filter((guard) => guard("#e03131")).length).toBe(__)
  expect(guards.filter((guard) => guard({})).length).toBe(__)
})

test("JSON.parse returns any, so type its result unknown: a field can then be read only after a guard has checked it.", () => {
  const payload: unknown = JSON.parse('{"x": 40, "y": "50"}')
  const x = isRecord(payload) && isFiniteNumber(payload.x) ? payload.x : 0
  const y = isRecord(payload) && isFiniteNumber(payload.y) ? payload.y : 0
  expect(x).toBe(__)
  expect(y).toBe(__)
})
