/*
Files this chapter touches
  - assets/js/hello.ts: greet

About these koans. Easel is a shared whiteboard, and the koans build it in two languages:
TypeScript and Svelte koans in assets/koans/ run under Vitest, Elixir koans in test/koans/
run under ExUnit. One command runs both:

    mix koans

It stops at the earliest koan you have not answered, TypeScript before Elixir within a
chapter, and prints a footer for it. A value blank is a bare __ inside a koan. A code blank
is a __blank("NN: tag") line in assets/js/, assets/svelte/ or assets/koans/drills/, between
two marker lines that name its chapter: replace that line with your code and keep the
markers. Its footer names two places:

    Write:          assets/js/hello.ts:3  (00: greet)
    Exercised by:   assets/koans/00_about_koans.test.ts:35

Write: is where your code goes, with the blank's tag. Exercised by: is the koan that ran it.

Before any koan runs, svelte-check reads every .ts and .svelte file. A type error stops the
run and names its file and line, as a compile error does in Elixir: fix it, then run again.
npm test runs only the TypeScript koans, and mix test only the Elixir ones.

API you'll use
  - template literals: `${count} shapes` puts the value of count into the string

Picture: none for this chapter; the lesson is on lessons/index.html too.
*/
import { expect } from "vitest"
import { test } from "@koans/runtime"
import { greet } from "../js/hello"

test("Implement greet in assets/js/hello.ts so it returns Hello, the name and an exclamation mark. 1. Open the file on the Write: line. 2. Replace the __blank line with a return of a template literal, and keep the marker lines.", () => {
  expect(greet("Ada")).toBe("Hello, Ada!")
})
