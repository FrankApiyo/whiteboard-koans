defmodule Koans.Ch00.AboutKoansTest do
  use Koans

  @moduledoc ~S"""
  Files this chapter touches
    - lib/easel/hello.ex: Easel.Hello.greet/1

  The Elixir half of the course. Elixir code blanks live in lib/ and test/support/ and work as
  in the Phoenix course: replace the __(...) line with code and keep the marker lines.

      # >>> 07
      __("07: list boards newest first")
      # <<< 07

  Every tag starts with its chapter, in both languages, so one :vimgrep lists a chapter's
  blanks everywhere (:copen shows them):

      :vimgrep /__("07\|__blank("07/ lib/** assets/**

  An Elixir footer names the function a blank belongs to, where TypeScript names the tag:

      Write:          lib/easel/hello.ex:9  (Easel.Hello.greet/1)
      Exercised by:   test/koans/00_about_koans_test.exs:46

  Some blanks have a default, as in __("11: subscribe", :ok) or __blank("10: listen", () => {}).
  Until you fill one it returns the default, so the app keeps working, and it fails only koans
  of its own chapter, with the same footer.

  Run mix phx.server once and open localhost:4000. The name page works from the start; the
  board pages show a blank on Phoenix's debug page, which is the course talking, not a crash.
  After 08 you can create a board and open it, after 10 what you draw stays after a reload, and
  after 12 two windows draw together and list each other. Stop the server and go on.

  API you'll use
    - String.split/3: String.split("07: list boards", ": ", parts: 2) is ["07", "list boards"]

  Picture: none for this chapter; the lesson is on lessons/index.html too.
  """

  koan "A blank's tag starts with its chapter number, which is what :vimgrep /__(\"07\\|__blank(\"07/ finds." do
    [chapter, tag] = String.split("07: list boards newest first", ": ", parts: 2)
    assert chapter == "07"
    assert tag == "list boards newest first"
  end

  koan "Implement Easel.Hello.greet/1 in lib/easel/hello.ex so it returns \"Hello, \" then the name and \"!\". 1. Run :vimgrep /__(\"00/ lib/** to find the blank. 2. Interpolate the name into a string with \#{} on the blank's line, and keep the marker lines." do
    assert Easel.Hello.greet("Ada") == "Hello, Ada!"
  end
end
