---
name: write-tests
description: Write ExUnit tests that describe behaviour, not implementation, covering edge cases explicitly. Use after or alongside implementing a context, LiveView, or fix.
---

Write ExUnit tests named and structured around what the system does, not
how it's implemented — a rename or internal refactor shouldn't break a
test if behaviour didn't change. Cover edge cases explicitly (empty
input, boundary values, failure paths) rather than relying on a single
happy-path example.

No factory or mocking library is set up yet (see `docs/architecture.md`)
— use plain ExUnit and direct Ecto fixtures until that's decided.

Tests must pass before `simplify` or `create-pr` can proceed.
