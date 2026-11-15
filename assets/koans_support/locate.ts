import { existsSync, readdirSync, readFileSync } from "node:fs"
import path from "node:path"

const BLANK_DIRS = ["js", "svelte", "test", "koans/drills"]
const SOURCE_FILE = /\.(ts|js|svelte)$/
const STRING_OR_COMMENT =
  /"(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*'|`(?:[^`\\]|\\.)*`|\/\/[^\n]*|\/\*[\s\S]*?\*\/|<!--[\s\S]*?-->/g

function sourceFiles(dir: string): string[] {
  if (!existsSync(dir)) return []

  return readdirSync(dir, { withFileTypes: true })
    .sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0))
    .flatMap((entry) => {
      const full = path.join(dir, entry.name)
      if (entry.isDirectory()) return sourceFiles(full)
      return SOURCE_FILE.test(entry.name) ? [full] : []
    })
}

function withoutComments(source: string): string {
  return source.replace(STRING_OR_COMMENT, (match) =>
    /^["'`]/.test(match) ? match : match.replace(/[^\n]/g, ""),
  )
}

function blankCall(tag: string): RegExp {
  const literal = JSON.stringify(tag).replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
  return new RegExp(`__blank(?:<[^>()]*>)?\\(${literal}`)
}

function lineOf(file: string, call: RegExp): number | null {
  const index = withoutComments(readFileSync(file, "utf8"))
    .split("\n")
    .findIndex((text) => call.test(text))

  return index === -1 ? null : index + 1
}

export function locateTag(tag: string, treeAssets: string): { path: string; line: number } | null {
  const call = blankCall(tag)

  for (const file of BLANK_DIRS.flatMap((dir) => sourceFiles(path.join(treeAssets, dir)))) {
    const line = lineOf(file, call)
    if (line !== null) return { path: file, line }
  }

  return null
}
