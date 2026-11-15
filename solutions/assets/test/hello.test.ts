import { describe, expect, it } from "vitest"
import { greet } from "../js/hello"

describe("hello", () => {
  it("greets by name", () => {
    expect(greet("Ada")).toBe("Hello, Ada!")
  })
})
