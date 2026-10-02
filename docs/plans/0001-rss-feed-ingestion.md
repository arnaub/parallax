# 0001 — RSS feed ingestion

Issue: [#1](https://github.com/arnaub/parallax/issues/1)
Branch: `1-rss-feed-ingestion`

## Summary

A `Feeds` context that stores Outlets, polls their RSS/Atom feeds hourly,
and stores new items as Coverage. Backend only — no UI. This is the
first context built, so once approved it becomes the reference module
in `docs/architecture.md`.

See the issue for the full decision log from `grill-me`. This plan only
adds the concrete shape.

## Contexts affected

- **New:** `Parallax.Feeds` (first context in the app).

## Dependencies to add

- `:req` — HTTP client for fetching feed XML.
- `:sweet_xml` — thin, actively maintained wrapper over OTP's built-in
  `:xmerl` for querying XML. Chosen over the three RSS/Atom-specific
  parsers on Hex: `elixir_feed_parser` and `feeder` are both unmaintained
  since 2018/2019, and `fast_rss` (actively maintained) is a Rust NIF —
  a native dependency we'd rather avoid for a project anyone should be
  able to clone and build with just Elixir installed. `Feeds.Fetcher`
  extracts title/link/guid/pubDate/description from RSS `<item>` and
  Atom `<entry>` elements itself; it's the only module that knows this,
  so swapping the approach later doesn't touch the rest of `Feeds`.

## Schema

**`outlets`**
- `name` (string, required)
- `homepage_url` (string, required)
- `feed_url` (string, required, unique)
- `language` (string, required — e.g. `"en"`, `"es"`, `"ca"`)

**`coverage`**
- `outlet_id` (references `outlets`, required)
- `dedup_key` (string, required) — computed as the feed item's `guid`,
  falling back to its `link`/URL when the feed has no guid. This is what
  the unique index (`outlet_id`, `dedup_key`) is on, so one column
  carries the "guid, fallback to link" dedup rule instead of two partial
  indexes.
- `url` (string, required) — the article link, always stored regardless
  of what became the dedup key.
- `title` (string, required)
- `summary` (text, nullable) — whatever the feed's description/excerpt
  provides; no full-article scraping in v1.
- `published_at` (utc_datetime, nullable — some feeds omit it)

No `story_id` yet — that belongs to the later Story-clustering feature
and would be an unused column here. Adding it now would be designing for
a feature that doesn't exist.

## Public API (`Parallax.Feeds`)

- `list_outlets/0`
- `create_outlet/1` — used by `priv/repo/seeds.exs`
- `poll_outlet/1` — fetches + parses one outlet, upserts new Coverage
  (`on_conflict: :nothing`, `conflict_target: [:outlet_id, :dedup_key]`),
  returns `{:ok, new_count}` or `{:error, reason}`
- `poll_all_outlets/0` — fetches every outlet concurrently
  (`Task.async_stream/3`, capped concurrency, each outlet isolated so one
  failure doesn't stop the rest), logs failures, returns a summary
- `list_coverage/0` — newest first; mainly for tests/IEx until the
  dashboard feature reads it

## Supporting modules

- `Parallax.Feeds.Fetcher` — the only module that knows about HTTP/XML:
  fetches a feed URL via `:req` and parses it into a plain list of
  `%{guid:, url:, title:, summary:, published_at:}` maps (or
  `{:error, reason}`). Keeps `Feeds` itself free of fetching/parsing
  detail.
- `Parallax.Feeds.Poller` — supervised GenServer. On `init/1`, schedules
  the first poll a full interval (1h) out via `Process.send_after/3` (no
  immediate poll on boot); `handle_info(:poll, state)` calls
  `Feeds.poll_all_outlets/0` and reschedules. Started in
  `Parallax.Application`'s children, but only when
  `Application.get_env(:parallax, :start_feeds_poller, true)` is true —
  `config/test.exs` sets it `false` so tests never make real HTTP calls;
  `:dev`/`:prod` leave the default.
- `Mix.Tasks.Feeds.Poll` — `mix feeds.poll`, starts the app and calls
  `Feeds.poll_all_outlets/0` once, printing a summary. For triggering a
  fetch on demand while developing, since the poller itself waits a full
  interval before its first run.

## Tests needed

- `Feeds` changesets: required fields, `feed_url` uniqueness on Outlet.
- `poll_outlet/1`: stores new Coverage from a stubbed feed response;
  polling the same feed twice doesn't create duplicates (dedup_key
  collision); a feed with no guids dedupes on URL instead.
- `poll_all_outlets/0`: one outlet's fetch failing (stubbed 500 /
  malformed XML) doesn't stop the others from being stored — assert on
  the per-outlet results.
- Stub HTTP with `Req.Test` (ships with `:req`) — no new test/mocking
  dependency needed, matching the earlier "decide mocking later" call.
- `Poller`: light smoke test that it starts as a GenServer and does not
  fetch anything synchronously on `init/1` (no real/stubbed HTTP call
  expected immediately).
- No automated test for the mix task; manual verification is enough.

## Docs to update once this lands

- `docs/architecture.md` — fill in the Reference modules table (Context →
  `Parallax.Feeds`) and the Data flow section.
- `docs/glossary.md` — move **Outlet** from Pending to Defined.

## Open risks

- Our own RSS/Atom extraction in `Fetcher` needs to tolerate real-world
  quirks (CDATA sections, namespaced elements, missing optional fields)
  across outlets we don't control — expect to harden it against actual
  feed responses rather than a single clean fixture.
- Real-world feeds vary in date formats and sometimes block default
  User-Agents — `Fetcher` may need a custom UA header and tolerant date
  parsing.
- Concurrency cap for `Task.async_stream/3` is a guess (start at 5);
  revisit once the real outlet count is known.
- If an outlet changes an item's guid on republish, it reappears as "new"
  Coverage — accepted as a v1 tradeoff, not solved here.

## Verification

- `mix test` covers the cases above.
- `mix feeds.poll` against the real seeded outlets, then
  `Parallax.Feeds.list_coverage/0` in `iex -S mix` to eyeball results.
- `mix format --check-formatted` and `mix credo --strict` clean.
