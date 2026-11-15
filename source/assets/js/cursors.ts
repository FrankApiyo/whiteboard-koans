import type { Live } from "./live"
import { isCursorPayload } from "./payloads"
import type { CursorPayload, Person } from "./types"

export type Cursors = ReadonlyMap<string, CursorPayload>

export function upsertCursor(cursors: Cursors, payload: CursorPayload): Cursors {
  return new Map(cursors).set(payload.tab, payload)
}

export function pruneCursors(cursors: Cursors, people: readonly Person[]): Cursors {
  const present = new Set(people.map((person) => person.tab))
  return new Map([...cursors].filter(([tab]) => present.has(tab)))
}

export function listenCursors(
  live: Live,
  set: (update: (cursors: Cursors) => Cursors) => void,
): () => void {
  const ref = live.handleEvent("cursor:moved", (payload) => {
    if (isCursorPayload(payload)) set((cursors) => upsertCursor(cursors, payload))
  })
  return () => live.removeHandleEvent(ref)
}
