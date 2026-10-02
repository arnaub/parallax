# Coding standards

This is the source of truth for how code is written in Parallax. AGENTS.md
files and skills point here; they never restate these rules.

## The bar

A developer who has never seen the code should understand any single
function in about two minutes, without AI help. If a function needs a
walkthrough, it is doing too much — split it.

## Functions and modules

- Small functions, one responsibility each. Extract a named function
  instead of adding another branch or another level of nesting.
- Modules have one responsibility. A context exposes a small, intentional
  public API; everything else is private.
- LiveViews and components hold no business logic — they call into
  contexts and render. See `docs/architecture.md` for where logic lives.
- Prefer pattern matching in function heads and guard clauses over nested
  `if`/`case`. Prefer pipelines over nested function calls.
- Mechanical limits (nesting depth, cyclomatic complexity, ABC size,
  function arity) are enforced by Credo — see `.credo.exs`. Treat a Credo
  failure as a signal to restructure, not to silence the check.

## Naming

- Names say what something is or does; no abbreviations, no Hungarian
  notation. A reader should not need to open the definition to guess.
- Predicate functions and booleans read as a question: `due?`, `read?`.
- Match the domain language in `docs/glossary.md`. If a feature needs a
  term that isn't there yet, add it when the feature is planned.

## Comments

- Default to zero comments. Good names, small functions, and tests should
  make the code self-explanatory; reach for a rename or a split before
  reaching for a comment.
- Write one only for a genuinely critical situation that code cannot
  express: a legal/business rule that looks wrong but isn't, a workaround
  for a specific external bug or constraint, or a non-obvious invariant
  that would cause a real bug if a future reader assumed otherwise. If
  removing the comment wouldn't confuse that reader, don't write it.
- Comments explain *why*, never *what* — never restate what the next
  line already says.
- No comments written for AI agents, no commented-out code, no restating
  the diff or the ticket. Context for agents lives in AGENTS.md, `docs/`,
  and skills — not inline.

## Formatting

- `mix format` is the final word on layout; don't hand-format around it.
- Line length is 80 (`.formatter.exs`).

## Commits

- [Conventional Commits](https://www.conventionalcommits.org/), kept
  short: `type: imperative summary`, e.g. `feat: add news table`,
  `fix: dedupe feed entries`, `refactor: extract digest builder`.
- Types in use: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`.
- One line is enough. Only add a body when the *why* isn't obvious from
  the summary and the diff (e.g. a non-obvious workaround).

## Tests

- Tests describe behaviour, not implementation. Name them after what the
  system does, not how.
- Cover edge cases explicitly rather than relying on a single happy-path
  example. See the `write-tests` skill.

## Enforcement

- `mix format` and `mix credo --strict` run automatically after every
  edit to an `.ex`/`.exs` file (`.claude/hooks/format-and-lint.sh`) — fix
  issues as they appear, don't let them accumulate.
- Everything mechanical lives in `.credo.exs`. Everything that needs
  judgment (naming, responsibility boundaries, the two-minute bar) is
  checked by the `readability-reviewer` subagent before a PR opens.
