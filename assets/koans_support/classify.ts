import { locateTag } from "./locate.ts"

export interface KoanError {
  name: string
  tag?: string
  line?: number
}

export interface ClassifyInput {
  error: KoanError | null
  koanSource: string
  koanLine: number
  exercises: string[]
  tree: string
}

export interface Write {
  path: string
  line: number
  where: string
}

export interface Classification {
  status: "ok" | "blank" | "fail"
  at: number
  tag: string | null
  write: Write | null
}

const STRING_LITERAL = /"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|`(?:[^`\\]|\\.)*`/g
const TEMPLATE_EXPRESSION = /\$\{([^}]*)\}/g
const LINE_COMMENT = /\/\/.*$/
const BARE_DUNDER = /(?<![\w$])__(?![\w$])/

function literalAsCode(literal: string): string {
  if (!literal.startsWith("`")) return '""'
  return [...literal.matchAll(TEMPLATE_EXPRESSION)].map((match) => match[1]).join(" ")
}

function holdsValueBlank(source: string, line: number): boolean {
  const text = source.split("\n")[line - 1] ?? ""
  const code = text.replace(STRING_LITERAL, literalAsCode).replace(LINE_COMMENT, "")
  return BARE_DUNDER.test(code)
}

function writeFor(tag: string, tree: string): Write | null {
  const found = locateTag(tag, tree)
  return found && { ...found, where: tag }
}

function remainingBlank(exercises: string[], tree: string): Write | null {
  for (const tag of exercises) {
    const write = writeFor(tag, tree)
    if (write) return write
  }
  return null
}

export function classify(input: ClassifyInput): Classification {
  const { error, koanSource, koanLine, exercises, tree } = input
  const failingLine = error?.line ?? koanLine

  if (error === null) return { status: "ok", at: koanLine, tag: null, write: null }

  if (error.name === "KoanBlank" && error.tag !== undefined) {
    const write = writeFor(error.tag, tree)
    return { status: "blank", at: write ? koanLine : failingLine, tag: error.tag, write }
  }

  if (error.line !== undefined && holdsValueBlank(koanSource, error.line)) {
    return { status: "blank", at: error.line, tag: null, write: null }
  }

  const write = remainingBlank(exercises, tree)
  if (write) return { status: "blank", at: koanLine, tag: write.where, write }

  return { status: "fail", at: failingLine, tag: null, write: null }
}
