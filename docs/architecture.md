# Architecture

Parallax is a Phoenix 1.7 / LiveView 1.0 app backed by Postgres (Ecto).

## Contexts

None yet. Each Phoenix context is a bounded module (`lib/parallax/<context>/`)
with a small public API; LiveViews and controllers call into contexts, never
into schemas or Ecto directly. The first context we build and get approved
becomes the pattern every later context follows — see Reference modules
below.

## Data flow

Pending — documented once the first context (likely feed ingestion) exists
end-to-end: where RSS polling runs, how articles become persisted rows, how
the dashboard reads them.

## Reference modules

Pending. `new-context` and `liveview-component` are meant to point at a real
example instead of embedding a template. Until one exists they describe the
expected shape in words; update this table and the skills as soon as the
first context/LiveView is approved.

| Role | Reference module | Status |
|---|---|---|
| Context | — | pending |
| LiveView | — | pending |
| Function component | — | pending |

## Conventions

- One context per bounded domain concept (e.g. feeds, interests, reading).
- A context owns its Ecto schemas; nothing outside the context queries
  those schemas directly.
- LiveViews and components hold no business logic — see
  `docs/coding-standards.md`.
