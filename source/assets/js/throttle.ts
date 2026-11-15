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
    // >>> answer 11: clear the timer and the held call
    if (timer) clearTimeout(timer)
    timer = null
    held = null
    // <<<
  }

  function run(args: Args): void {
    cancel()
    lastRun = now()
    fn(...args)
  }

  function throttled(...args: Args): void {
    // >>> answer 11: run now, or hold the latest call for the window's end
    const wait = ms - (now() - lastRun)
    if (wait <= 0) return run(args)

    held = args
    timer ??= setTimeout(() => {
      timer = null
      if (held) run(held)
    }, wait)
    // <<<
  }

  return Object.assign(throttled, { cancel })
}
