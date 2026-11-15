export function throttle<Args extends unknown[]>(
  fn: (...args: Args) => void,
  ms: number,
  now: () => number = Date.now,
): (...args: Args) => void {
  let lastRun = -Infinity
  let held: Args | null = null
  let timer: ReturnType<typeof setTimeout> | null = null

  function run(args: Args): void {
    lastRun = now()
    fn(...args)
  }

  return (...args) => {
    const wait = ms - (now() - lastRun)
    if (wait <= 0) return run(args)

    held = args
    timer ??= setTimeout(() => {
      timer = null
      if (held) run(held)
      held = null
    }, wait)
  }
}
