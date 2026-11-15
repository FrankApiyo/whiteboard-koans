import { existsSync, readdirSync, readFileSync } from "node:fs"
import path from "node:path"

const BLANK_DIRS = ["js", "svelte", "test", "koans/drills"]
const SOURCE_FILE = /\.(ts|js|svelte)$/

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

function lineOf(file: string, needle: string): number | null {
  const index = readFileSync(file, "utf8")
    .split("\n")
    .findIndex((text) => text.includes(needle))

  return index === -1 ? null : index + 1
}

export function locateTag(tag: string, treeAssets: string): { path: string; line: number } | null {
  const needle = `__blank(${JSON.stringify(tag)}`

  for (const file of BLANK_DIRS.flatMap((dir) => sourceFiles(path.join(treeAssets, dir)))) {
    const line = lineOf(file, needle)
    if (line !== null) return { path: file, line }
  }

  return null
}
