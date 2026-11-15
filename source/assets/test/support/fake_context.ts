import type { Ctx } from "../../js/render"

export type Call = [string, ...unknown[]]
export type FakeContext = Ctx & {
  calls: Call[]
  measureText(text: string): { width: number }
}

const METHODS = [
  "clearRect",
  "strokeRect",
  "fillRect",
  "beginPath",
  "ellipse",
  "moveTo",
  "lineTo",
  "stroke",
  "fill",
  "save",
  "restore",
  "setLineDash",
  "setTransform",
]

export function createFakeContext(): FakeContext {
  const calls: Call[] = []
  const props = new Map<string | symbol, unknown>()

  const handler: ProxyHandler<object> = {
    get(_target, key) {
      if (key === "calls") return calls
      if (key === "measureText") return (text: string) => ({ width: text.length * 8 })
      if (typeof key === "string" && METHODS.includes(key)) {
        return (...args: unknown[]) => calls.push([key, ...args])
      }
      return props.get(key)
    },
    set(_target, key, value) {
      props.set(key, value)
      calls.push([`set:${String(key)}`, value])
      return true
    },
  }

  return new Proxy({}, handler) as FakeContext
}
