const WIDTH = 80

export interface FooterWrite {
  path: string
  line: number
  where: string
}

export interface FooterFailure {
  path: string
  line: number
  meditation: string
  diff: string | null
  write: FooterWrite | null
}

export interface FooterInput {
  passed: number
  total: number
  ran: number
  failure: FooterFailure | null
  scope: "typescript"
}

const NOUN = "TypeScript koans"

function separator(title: string): string {
  const padded = ` ${title} `
  const fill = WIDTH - [...padded].length
  const left = Math.floor(fill / 2)
  return "-".repeat(left) + padded + "-".repeat(fill - left)
}

function locations(failure: FooterFailure): string {
  if (failure.write === null) return `Meditate on ${failure.path}:${failure.line}`

  const { path, line, where } = failure.write
  return (
    `Write:          ${path}:${line}  (${where})\n` +
    `Exercised by:   ${failure.path}:${failure.line}`
  )
}

function failureBody(passed: number, total: number, failure: FooterFailure): string {
  const diff = failure.diff === null ? "" : `${failure.diff}\n`
  const meditation = failure.meditation
    .split("\n")
    .map((line) => `    ${line}`)
    .join("\n")

  return (
    diff +
    separator("The master says") +
    `\n${locations(failure)}\n${meditation}\n` +
    `${passed} of ${total} ${NOUN} answered.`
  )
}

export function renderFooter({ passed, total, ran, failure }: FooterInput): string {
  if (failure !== null) return failureBody(passed, total, failure)
  if (ran === 0) return "No koan at that line: put the cursor inside a koan, or run the file."
  if (ran >= total && passed === total) {
    return `All ${total} ${NOUN} pass. Run mix koans for the whole course.`
  }
  return `${passed} of ${total} ${NOUN} answered. Run the whole suite for the rest.`
}
