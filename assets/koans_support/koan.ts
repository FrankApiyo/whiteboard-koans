import { test as vitestTest } from "vitest"

declare module "vitest" {
  interface TaskMeta {
    exercises?: string[]
  }
}

export interface KoanOptions {
  exercises?: string | string[]
}

export function test(
  meditation: string,
  body: () => void | Promise<void>,
  options: KoanOptions = {},
): void {
  const exercises = options.exercises === undefined ? [] : [options.exercises].flat()
  vitestTest(meditation, { meta: { exercises } }, () => body())
}
