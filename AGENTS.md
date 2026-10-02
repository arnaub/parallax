# AGENTS.md

Parallax — a personal news reader (Phoenix + LiveView). Domain terms are in
`docs/glossary.md`.

## Commands

- `mix setup` — install deps, create/migrate the DB, build assets
- `mix phx.server` — run the app at localhost:4000
- `mix test` — run the test suite
- `mix format` && `mix credo --strict` — format and lint

## Principles

- Readable by a human in ~2 minutes, no AI needed.
- Comments explain *why*, never *what* — default to none.
- Docs are the single source of truth. This file and skills only point to
  them; they never restate rules.
- Anything mechanical is enforced by tooling, not discipline.
- Agents propose designs, plans, and code; humans approve them.

## Where to look

- `docs/architecture.md` — contexts, data flow, reference modules
- `docs/coding-standards.md` — the full rules behind the principles above
- `docs/glossary.md` — domain terms
- `docs/decisions/` — ADRs
- `docs/plans/` — approved feature plans
- `.claude/skills/` — grill-me, plan-feature, new-context,
  liveview-component, write-tests, simplify, create-pr,
  propose-improvements

## Workflow

Features go through `grill-me` → `plan-feature` (stops for human approval)
→ implementation → `create-pr`. Don't skip planning for non-trivial work.
