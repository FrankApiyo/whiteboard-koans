import type { Live } from "../../js/live"

export interface Pushed {
  event: string
  payload: object
  onReply?: (reply: unknown) => void
}

export interface FakeLive extends Live {
  pushed: Pushed[]
  emit(event: string, payload: unknown): void
  listenerCount(event: string): number
}

export function createFakeLive(): FakeLive {
  const pushed: Pushed[] = []
  const listeners = new Map<number, { event: string; cb: (payload: unknown) => void }>()
  let nextRef = 0

  return {
    pushed,
    pushEvent(event, payload, onReply) {
      pushed.push({ event, payload, onReply })
    },
    handleEvent(event, cb) {
      const ref = nextRef++
      listeners.set(ref, { event, cb })
      return ref
    },
    removeHandleEvent(ref) {
      listeners.delete(ref as number)
    },
    emit(event, payload) {
      for (const listener of [...listeners.values()]) {
        if (listener.event === event) listener.cb(payload)
      }
    },
    listenerCount(event) {
      return [...listeners.values()].filter((l) => l.event === event).length
    },
  }
}
