import { CODE_MESSAGE } from "./messages.ts"

export class KoanBlank extends Error {
  override name = "KoanBlank"
  readonly tag: string

  constructor(tag: string) {
    super(CODE_MESSAGE)
    this.tag = tag
  }
}

function blank(tag: string, ...fallback: unknown[]): unknown {
  if (fallback.length > 0) return fallback[0]
  throw new KoanBlank(tag)
}

Object.assign(globalThis, { __: Symbol("koan blank"), __blank: blank })
