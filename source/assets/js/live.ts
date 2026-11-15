export interface Live {
  pushEvent(event: string, payload: object, onReply?: (reply: unknown) => void): void
  handleEvent(event: string, callback: (payload: unknown) => void): unknown
  removeHandleEvent(ref: unknown): void
}
