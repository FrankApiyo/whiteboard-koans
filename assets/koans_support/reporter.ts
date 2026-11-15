import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs"
import path from "node:path"
import type { Reporter, SerializedError, TestCase, TestModule } from "vitest/node"
import { classify, type Classification, type KoanError, type Write } from "./classify.ts"
import { renderFooter, type FooterFailure } from "./footer.ts"
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

export interface KoanReporterOptions {
  koansDir: string
  tree: string
}

export function koanLines(source: string): number[] {
  return source.split("\n").flatMap((text, index) => (KOAN_LINE.test(text) ? [index + 1] : []))
}

function koanFiles(dir: string): string[] {
  if (!existsSync(dir)) return []

  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(dir, entry.name)
    if (entry.isDirectory()) return koanFiles(full)
    return entry.name.endsWith(".test.ts") ? [full] : []
  })
}

export function countKoans(dir: string): number {
  return koanFiles(dir).reduce(
    (sum, file) => sum + koanLines(readFileSync(file, "utf8")).length,
    0,
  )
}

function chapter(file: string): string {
  return /^(\d+)/.exec(path.basename(file))?.[1] ?? "00"
}

function errorChain(error: SerializedError | undefined): SerializedError[] {
  return error ? [error, ...errorChain(error.cause)] : []
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

interface ModuleContext {
  moduleId: string
  file: string
  source: string
  lines: number[]
  tree: string
}

function caseRecord(testCase: TestCase, index: number, context: ModuleContext): KoanRecord | null {
  const result = testCase.result()
  if (result.state === "skipped" || result.state === "pending") return null

  const error = result.state === "failed" ? result.errors[0] : undefined
  const line = context.lines[index] ?? 0
  const verdict = classify({
    error: error ? koanError(error, context.moduleId) : null,
    koanSource: context.source,
    koanLine: line,
    exercises: testCase.meta().exercises ?? [],
    tree: context.tree,
  })

  return {
    kind: "ts",
    chapter: chapter(context.file),
    file: context.file,
    line,
    order: index + 1,
    status: verdict.status,
    meditation: testCase.name,
    at: verdict.at,
    tag: verdict.tag,
    write: verdict.write,
    diff: diffFor(verdict, error),
  }
}

function loadFailure(module: TestModule, context: ModuleContext): KoanRecord[] {
  const [error] = module.errors()
  if (error === undefined) return []

  const line = context.lines[0] ?? 1
  return [
    {
      kind: "ts",
      chapter: chapter(context.file),
      file: context.file,
      line,
      order: 1,
      status: "fail",
      meditation: "",
      at: lineIn(error, context.moduleId) ?? line,
      tag: null,
      write: null,
      diff: error.message,
    },
  ]
}

function moduleRecords(module: TestModule, tree: string): KoanRecord[] {
  const source = existsSync(module.moduleId) ? readFileSync(module.moduleId, "utf8") : ""
  const context: ModuleContext = {
    moduleId: module.moduleId,
    file: path.relative(process.cwd(), module.moduleId),
    source,
    lines: koanLines(source),
    tree,
  }
  const tests = [...module.children.allTests()]

  if (tests.length === 0) return loadFailure(module, context)
  return tests.flatMap((testCase, index) => caseRecord(testCase, index, context) ?? [])
}

function byFileAndLine(a: KoanRecord, b: KoanRecord): number {
  if (a.file !== b.file) return a.file < b.file ? -1 : 1
  return a.line - b.line
}

function earliestFailure(records: KoanRecord[]): FooterFailure | null {
  const [first] = records.filter((record) => record.status !== "ok").sort(byFileAndLine)
  if (first === undefined) return null

  return {
    path: first.file,
    line: first.at,
    meditation: first.meditation,
    diff: first.diff,
    write: first.write,
  }
}

export class KoanReporter implements Reporter {
  readonly #options: KoanReporterOptions
  #modules: TestModule[] = []

  constructor(options: KoanReporterOptions) {
    this.#options = options
  }

  onTestRunStart(): void {
    this.#modules = []
  }

  onTestModuleEnd(module: TestModule): void {
    this.#modules = [...this.#modules, module]
  }

  onTestRunEnd(
    modules: ReadonlyArray<TestModule>,
    unhandledErrors: ReadonlyArray<SerializedError>,
  ): void {
    const tree = path.relative(process.cwd(), path.resolve(this.#options.tree))
    const unseen = modules.filter((module) => !this.#modules.includes(module))
    const records = [...this.#modules, ...unseen].flatMap((module) => moduleRecords(module, tree))

    for (const error of unhandledErrors) {
      process.stderr.write(`Unhandled error: ${error.name ?? "Error"}: ${error.message}\n`)
    }

    const resultsDir = process.env.KOANS_RESULTS
    if (resultsDir) return writeResults(resultsDir, records)

    const footer = renderFooter({
      passed: records.filter((record) => record.status === "ok").length,
      total: countKoans(this.#options.koansDir),
      ran: records.length,
      failure: earliestFailure(records),
      scope: "typescript",
    })
    process.stdout.write(`\n${footer}\n`)
  }
}

function writeResults(dir: string, records: KoanRecord[]): void {
  mkdirSync(dir, { recursive: true })
  const lines = records.map((record) => `${JSON.stringify(record)}\n`).join("")
  writeFileSync(path.join(dir, "ts.jsonl"), lines)
}
