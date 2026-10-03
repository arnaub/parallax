# Architecture

Parallax is a Phoenix 1.7 / LiveView 1.0 app backed by Postgres (Ecto).

## Contexts

Each Phoenix context is a bounded module (`lib/parallax/<context>/`) with a
small public API; LiveViews and controllers call into contexts, never into
schemas or Ecto directly.

- **`Parallax.Feeds`** — Outlets and the Coverage ingested from their
  RSS/Atom feeds. The first context built, and the reference for how later
  contexts should be shaped — see Reference modules below.
- **`Parallax.Stories`** — screens Coverage for significant news and groups
  what passes into long-running Stories, using an LLM (see ADR 0002).
  Reads/writes Coverage only through `Feeds`' public API
  (`list_unclustered_coverage/0`, `assign_story/2`, `mark_irrelevant/1`)
  — it never queries the `coverage` table directly, same rule `Feeds`
  itself follows.

## Data flow

`Parallax.Feeds.Poller` (a supervised GenServer) polls every Outlet hourly.
`Parallax.Feeds.Fetcher` is the only module that knows about HTTP or feed
XML — it fetches a feed URL and parses it into plain item maps, stripping
any embedded HTML and decoding common entities from the summary so every
consumer gets clean text. `Feeds` itself turns those into Coverage rows,
deduped per outlet on a computed `dedup_key` (the feed item's guid,
falling back to its URL). `ParallaxWeb.DashboardLive` is the only current
reader: it calls `Feeds.list_coverage/1` for the latest 30 rows (newest
`published_at`, falling back to `inserted_at` when a feed omitted the
date) and renders them — no personalized ranking yet, no live updates
after the page loads.

`Parallax.Stories.Scheduler` (a separate supervised GenServer, on its own
daily interval — independent of the hourly `Feeds.Poller`) runs
`Stories.cluster_unclustered_coverage/0`. For each unscreened Coverage
item, it asks Gemini (`Stories.Matcher` + `Stories.Gemini`) to judge
whether it's significant news at all, and if so, to either match it to
one of the ~50 most recently-active Stories or start a new one — all in
one call. Items are processed sequentially, paced below the API's rate
limit, since every call hits the same endpoint. Nothing reads Stories
yet — that starts with the Story synthesis feature.

## Reference modules

`new-context` and `liveview-component` are meant to point at a real example
instead of embedding a template.

| Role | Reference module | Status |
|---|---|---|
| Context | `Parallax.Feeds` (`lib/parallax/feeds.ex`) | done |
| LiveView | `ParallaxWeb.DashboardLive` (`lib/parallax_web/live/dashboard_live.ex`) | done |
| Function component | — | pending |

## Conventions

- One context per bounded domain concept (e.g. feeds, interests, reading).
- A context owns its Ecto schemas; nothing outside the context queries
  those schemas directly.
- LiveViews and components hold no business logic — see
  `docs/coding-standards.md`.
