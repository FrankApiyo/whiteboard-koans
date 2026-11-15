export {}

declare global {
  const __: any
  function __blank(tag: string): never
  function __blank<T>(tag: string, fallback: T): T
}
