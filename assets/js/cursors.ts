import type { Live } from "./live"
import { isCursorPayload } from "./payloads"
import type { CursorPayload, Person } from "./types"

export type Cursors = ReadonlyMap<string, CursorPayload>

export function upsertCursor(cursors: Cursors, payload: CursorPayload): Cursors {
  // >>> 12
  __blank("12: a new map with this tab's cursor set");
  // <<< 12
}

export function pruneCursors(cursors: Cursors, people: readonly Person[]): Cursors {
  // >>> 12
  __blank("12: keep the cursors of tabs still present");
  // <<< 12
}

export function listenCursors(
  live: Live,
  set: (update: (cursors: Cursors) => Cursors) => void,
): () => void {
  // >>> 12
  return __blank("12: listen for cursor:moved, and stop", () => {});
  // <<< 12
}
