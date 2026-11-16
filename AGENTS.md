Whiteboard koans: a course whose blanks, filled, are the Easel app (Phoenix + live_svelte).
`source/` is the only authored copy; `mix koans.gen` writes the learner tree and `solutions/` from it, so never edit those by hand.
`verify/` proves the course (`MIX_TEST_PARTITION=verify mix test verify/<file>`); the README's "For maintainers" section lists the checks.
