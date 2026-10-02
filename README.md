# Parallax

A personal news reader, built feature by feature, in the open.

Parallax pulls news from multiple outlets via RSS and groups coverage of
the same ongoing situation — a conflict, a political crisis, a
slow-moving story — together. It's deliberately not built for
immediacy: no race to be first, no real-time pressure. The goal is the
understanding you'd get from reading twenty articles across a week,
from outlets with different perspectives and in different languages,
without having to read all twenty. Finite and intentional by design —
read what matters, then stop.

**Status:** RSS ingestion and the dashboard are live; story grouping
(linking coverage of the same situation across outlets/languages) is in
progress. See `docs/plans/` for what's approved and in progress.

## Stack

Elixir, Phoenix, LiveView, Postgres.

## Running it locally

```
mix setup      # install deps, create + migrate the DB, build assets
mix phx.server # http://localhost:4000
```

Run the test suite with `mix test`.

## Working on this project

This repo is built with an explicit, documented workflow for human and
AI-assisted contributions alike — see [AGENTS.md](AGENTS.md) for the
rules, commands, and pointers into `docs/`.

## License

MIT — see [LICENSE](LICENSE).
