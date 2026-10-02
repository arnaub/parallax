---
name: new-context
description: Create a Phoenix context (schema, changeset, public API, tests) following the reference module in docs/architecture.md. Use when an approved plan calls for a new bounded context.
---

Follow the reference context module listed in `docs/architecture.md`
(marked `pending` until the first one is approved — if it's still
pending, ask which existing module, if any, should set the pattern).
Build: the Ecto schema, changeset(s), a small public API module, and
tests (see `write-tests`).

Apply `docs/coding-standards.md` throughout — small functions, no logic
leaking into the schema or into callers.

If this is the *first* context being built, flag it to the human: once
approved, it becomes the reference in `docs/architecture.md` and that doc
should be updated to point at it.
