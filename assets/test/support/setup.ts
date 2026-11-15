export interface CanvasCall {
  name: string
  args: unknown[]
}

export type RecordingContext = CanvasRenderingContext2D & { calls: CanvasCall[] }

const contexts = new WeakMap<HTMLCanvasElement, RecordingContext>()

export function recordingContext(canvas: HTMLCanvasElement): RecordingContext {
  const calls: CanvasCall[] = []
  const fields: Record<string | symbol, unknown> = { calls, canvas }

  return new Proxy(fields, {
    get(target, key) {
      if (key in target) return target[key]
      if (typeof key === "symbol" || key === "then") return undefined
      return (...args: unknown[]) => {
        calls.push({ name: key, args })
      }
    },
    set(target, key, value) {
      target[key] = value
      return true
    },
  }) as unknown as RecordingContext
}

function getContext(this: HTMLCanvasElement, kind: string): RecordingContext | null {
  if (kind !== "2d") return null

  const existing = contexts.get(this)
  if (existing) return existing

  const created = recordingContext(this)
  contexts.set(this, created)
  return created
}

HTMLCanvasElement.prototype.getContext = getContext as HTMLCanvasElement["getContext"]
Element.prototype.setPointerCapture ??= () => {}
Element.prototype.releasePointerCapture ??= () => {}
Element.prototype.hasPointerCapture ??= () => false
