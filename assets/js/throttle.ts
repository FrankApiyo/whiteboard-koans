export type Throttled<Args extends unknown[]> = ((...args: Args) => void) & {
  cancel(): void
}

export function throttle<Args extends unknown[]>(
  fn: (...args: Args) => void,
  ms: number,
  now: () => number = Date.now,
): Throttled<Args> {
  let lastRun = -Infinity
  let held: Args | null = null
  let timer: ReturnType<typeof setTimeout> | null = null

  function cancel(): void {
    // >>> 11
    __blank("11: clear the timer and the held call");
    // <<< 11
  }

  function run(args: Args): void {
    cancel()
    lastRun = now()
    fn(...args)
  }

  function throttled(...args: Args): void {
    // >>> 11
    __blank("11: run now, or hold the latest call for the window's end");
    // <<< 11
  }

  return Object.assign(throttled, { cancel })
}
