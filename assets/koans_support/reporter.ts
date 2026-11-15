import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs"
import path from "node:path"
import type { Reporter, SerializedError, TestModule } from "vitest/node"
import { renderFooter, type FooterFailure } from "./footer.ts"
import { koanLines, moduleRecords, type KoanRecord, type UnhandledError } from "./records.ts"

export interface KoanReporterOptions {
  root: string
  koansDir: string
  tree: string
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

function strayKey(moduleId: string | undefined, name: string | undefined): string {
  return `${moduleId ?? ""}\0${name ?? ""}`
}

function testKeys(modules: TestModule[]): Set<string> {
  return new Set(
    modules.flatMap((module) =>
      [...module.children.allTests()].map((testCase) => strayKey(module.moduleId, testCase.name)),
    ),
  )
}

function byTest(errors: UnhandledError[]): Map<string, UnhandledError[]> {
  return errors.reduce((map, error) => {
    const key = strayKey(error.VITEST_TEST_PATH, error.VITEST_TEST_NAME)
    return new Map(map).set(key, [...(map.get(key) ?? []), error])
  }, new Map<string, UnhandledError[]>())
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

function writeResults(dir: string, records: KoanRecord[]): void {
  mkdirSync(dir, { recursive: true })
  const lines = records.map((record) => `${JSON.stringify(record)}\n`).join("")
  writeFileSync(path.join(dir, "ts.jsonl"), lines)
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
    const { root, koansDir, tree } = this.#options
    const ran = [...this.#modules, ...modules.filter((module) => !this.#modules.includes(module))]
    const strays = byTest(unhandledErrors as UnhandledError[])
    const known = testKeys(ran)
    const context = {
      root,
      tree: path.resolve(root, tree),
      strays: (moduleId: string, name: string) => strays.get(strayKey(moduleId, name)) ?? [],
    }
    const records = ran.flatMap((module) => moduleRecords(module, context))

    for (const [key, errors] of strays) {
      if (known.has(key)) continue
      for (const error of errors) {
        process.stderr.write(`Unhandled error: ${error.name ?? "Error"}: ${error.message}\n`)
      }
    }

    const resultsDir = process.env.KOANS_RESULTS
    if (resultsDir) return writeResults(path.resolve(root, resultsDir), records)

    const footer = renderFooter({
      passed: records.filter((record) => record.status === "ok").length,
      total: countKoans(path.resolve(root, koansDir)),
      ran: records.length,
      failure: earliestFailure(records),
      scope: "typescript",
    })
    process.stdout.write(`\n${footer}\n`)
  }
}
