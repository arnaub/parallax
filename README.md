# Parallax

A personal news reader, built feature by feature, in the open.

Parallax pulls news from multiple outlets via RSS, surfaces what's most
relevant to you on one dashboard, and — its whole point — shows how
different outlets cover the *same* story side by side, so you see the
nuance instead of a single framing. It's meant to replace idle social
media scrolling with something finite and intentional: read what
matters, then stop.

**Status:** early scaffolding — no features yet. See `docs/plans/` for
what's approved and in progress.

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
