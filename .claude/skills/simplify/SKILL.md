---
name: simplify
description: Refactor a file to meet docs/coding-standards.md without changing behaviour. Tests must pass before and after. Use when code works but doesn't meet the readability bar.
---

Refactor the target file(s) to match `docs/coding-standards.md` — extract
functions, rename, remove dead code, reduce nesting — without changing
behaviour.

Run the existing tests before starting and again after finishing. If
nothing covers the code being touched, say so before proceeding rather
than refactoring blind.

Don't add features and don't change the public API unless that's
explicitly the point of the request. Credo and `mix format` passing is a
side effect of simplifying, not the goal itself.
