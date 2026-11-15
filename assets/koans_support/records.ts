import { existsSync, readFileSync } from "node:fs"
import path from "node:path"
import type { SerializedError, TestCase, TestModule } from "vitest/node"
import { classify, type Classification, type KoanError, type Write } from "./classify.ts"
import { CODE_MESSAGE, VALUE_MESSAGE } from "./messages.ts"

const KOAN_LINE = /^test\("/

export interface KoanRecord {
  kind: "ts"
  chapter: string
  file: string
  line: number
  order: number
  status: "ok" | "blank" | "fail"
  meditation: string
  at: number
  tag: string | null
  write: Write | null
  diff: string | null
}

export interface UnhandledError extends SerializedError {
  VITEST_TEST_PATH?: string
  VITEST_TEST_NAME?: string
}

export interface RecordContext {
  root: string
  tree: string
  strays: (moduleId: string, name: string) => UnhandledError[]
}

interface ModuleContext {
  moduleId: string
  file: string
  source: string
  lines: number[]
  base: RecordContext
}

export function koanLines(source: string): number[] {
  return source.split("\n").flatMap((text, index) => (KOAN_LINE.test(text) ? [index + 1] : []))
}

function chapter(file: string): string {
  return /^(\d+)/.exec(path.basename(file))?.[1] ?? "00"
}

function errorChain(error: SerializedError | undefined): SerializedError[] {
  return error ? [error, ...errorChain(error.cause)] : []
}

function isBlank(error: SerializedError): boolean {
  return errorChain(error).some((link) => link.name === "KoanBlank")
}

function lineIn(error: SerializedError, moduleId: string): number | undefined {
  return error.stacks?.find((frame) => frame.file === moduleId)?.line
}

function koanError(error: SerializedError, moduleId: string): KoanError {
  const blank = errorChain(error).find((link) => link.name === "KoanBlank")
  const tag = typeof blank?.tag === "string" ? blank.tag : undefined
  const name = blank ? "KoanBlank" : (error.name ?? "Error")
  return { name, tag, line: lineIn(error, moduleId) }
}

function failureText(error: SerializedError): string {
  if (typeof error.expected === "string" && typeof error.actual === "string") {
    return `expected: ${error.expected}\nreceived: ${error.actual}`
  }
  return error.message
}

function diffFor(verdict: Classification, error: SerializedError | undefined): string | null {
  if (verdict.status === "ok" || error === undefined) return null
  if (verdict.status === "fail") return failureText(error)
  return verdict.tag === null ? VALUE_MESSAGE : CODE_MESSAGE
}

function fromRoot(root: string, write: Write | null): Write | null {
  return write && { ...write, path: path.relative(root, path.resolve(root, write.path)) }
}

function record(
  context: ModuleContext,
  fields: { line: number; order: number; meditation: string; exercises: string[] },
  error: SerializedError | undefined,
): KoanRecord {
  const verdict = classify({
    error: error ? koanError(error, context.moduleId) : null,
    koanSource: context.source,
    koanLine: fields.line,
    exercises: fields.exercises,
    tree: context.base.tree,
  })

  return {
    kind: "ts",
    chapter: chapter(context.file),
    file: context.file,
    line: fields.line,
    order: fields.order,
    status: verdict.status,
    meditation: fields.meditation,
    at: verdict.at,
    tag: verdict.tag,
    write: fromRoot(context.base.root, verdict.write),
    diff: diffFor(verdict, error),
  }
}

function caseRecord(testCase: TestCase, index: number, context: ModuleContext): KoanRecord[] {
  const result = testCase.result()
  if (result.state === "skipped" || result.state === "pending") return []

  const own = result.state === "failed" ? result.errors : []
  const errors = [...own, ...context.base.strays(context.moduleId, testCase.name)]
  const line = context.lines[index] ?? 0
  const fields = {
    line,
    order: index + 1,
    meditation: testCase.name,
    exercises: testCase.meta().exercises ?? [],
  }

  return [record(context, fields, errors.find(isBlank) ?? errors[0])]
}

function loadFailure(module: TestModule, context: ModuleContext): KoanRecord[] {
  const [error] = module.errors()
  if (error === undefined) return []

  const fields = {
    line: context.lines[0] ?? 1,
    order: 1,
    meditation: `${context.file} did not load.`,
    exercises: [],
  }
  return [record(context, fields, error)]
}

export function moduleRecords(module: TestModule, base: RecordContext): KoanRecord[] {
  const source = existsSync(module.moduleId) ? readFileSync(module.moduleId, "utf8") : ""
  const context: ModuleContext = {
    moduleId: module.moduleId,
    file: path.relative(base.root, module.moduleId),
    source,
    lines: koanLines(source),
    base,
  }
  const tests = [...module.children.allTests()]

  if (tests.length === 0) return loadFailure(module, context)
  return tests.flatMap((testCase, index) => caseRecord(testCase, index, context))
}
