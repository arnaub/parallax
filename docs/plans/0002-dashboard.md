# 0002 — Dashboard

Issue: [#3](https://github.com/arnaub/parallax/issues/3)
Branch: `3-dashboard`

## Summary

The first LiveView: a reverse-chronological feed of the latest 30
Coverage rows, replacing the default Phoenix welcome page at `/`. No
personalized ranking (Interests doesn't exist yet), no live updates, no
pagination — a static, bounded page per the "finite, not endless
scrolling" goal. See the issue for the full decision log from
`grill-me`.

This is the first LiveView built, so once approved it fills the pending
LiveView row in `docs/architecture.md`.

## Contexts affected

- **`Parallax.Feeds`** (existing) — `list_coverage/0` is replaced by
  `list_coverage/1`, taking a `:limit` option and fixing the sort order
  (see below). No schema changes.

## `Feeds.list_coverage/1` change

Current implementation orders by `published_at desc`, which in Postgres
puts `NULL` values *first* — wrong, since a handful of real feed items
have no `published_at` and would wrongly sort as "newest". Per the
grill-me decision, sort by `published_at`, falling back to `inserted_at`
when it's null:

```elixir
def list_coverage(opts \\ []) do
  limit = Keyword.get(opts, :limit, 30)

  Coverage
  |> order_by(desc: coalesce(c.published_at, c.inserted_at))
  |> limit(^limit)
  |> Repo.all()
end
```

(Exact Ecto syntax for referencing `c` in `order_by` without a named
binding to be resolved at implementation time — likely needs
`from c in Coverage, order_by: ...` instead of the pipe form shown.)

## New LiveView

- **`ParallaxWeb.DashboardLive`** (`lib/parallax_web/live/dashboard_live.ex`
  + colocated `dashboard_live.html.heex`):
  - `mount/3` calls `Feeds.list_coverage(limit: 30)` once, assigns the
    list. No `handle_event` callbacks needed — the page is fully static
    per load (no live updates, no "load more").
  - Template: empty-state message when the list is empty ("No coverage
    yet — wait for the next scheduled poll, or run `mix feeds.poll`.");
    otherwise one `<.coverage_card>` per item.
  - `coverage_card/1`, a small function component defined in the same
    file (used only here, so it doesn't belong in the shared
    `core_components.ex`): renders title (linking out to the original
    article, `target="_blank"`), outlet name, published date, summary.
    No language badge — outlet name alone signals origin for v1.

## Router

- `lib/parallax_web/router.ex`: replace `get "/", PageController, :home`
  with `live "/", DashboardLive, :index`.

## Dead code removed

The default Phoenix welcome page is fully replaced, so its scaffold
becomes unused and should be deleted rather than left behind:
- `lib/parallax_web/controllers/page_controller.ex`
- `lib/parallax_web/controllers/page_html.ex`
- `lib/parallax_web/controllers/page_html/home.html.heex`
- `test/parallax_web/controllers/page_controller_test.exs`

## Tests needed

- `Feeds.list_coverage/1`: respects `:limit`; falls back to
  `inserted_at` ordering when `published_at` is null; defaults to 30
  when no option given.
- `ParallaxWeb.DashboardLive` (`Phoenix.LiveViewTest`): renders the
  empty-state message with no Coverage; renders up to 30 items newest
  first; each item shows title (as a link to its URL), outlet name,
  published date, and summary.

## Docs to update once this lands

- `docs/architecture.md` — fill in the Reference modules table
  (LiveView → `ParallaxWeb.DashboardLive`) and extend Data flow to cover
  how the dashboard reads Coverage.

## Open risks

- Coverage titles/summaries come from untrusted external feeds. HEEx
  auto-escapes interpolated text by default, so this is safe as long as
  the template never reaches for `raw/1` on feed content — worth calling
  out explicitly since it'd be an easy mistake to introduce later.
- The NacióDigital double-escaped-entity quirk found during RSS
  ingestion testing (e.g. `L&apos;ocupació`) becomes visible to a human
  for the first time here. Not fixed in this feature (outlet-side data
  quality, not ingestion or display logic) — just noting it'll be seen.
- No custom visual design pass — uses the existing Tailwind/
  CoreComponents conventions from the generated scaffold as-is. If more
  visual polish is wanted, that's a separate follow-up, not blocking
  this plan.

## Verification

- `mix test` covers the cases above.
- `mix phx.server`, open `http://localhost:4000`, confirm the feed
  renders with real seeded/polled Coverage, links open the original
  articles, and the empty state shows correctly against a fresh/empty
  `coverage` table.
- `mix format --check-formatted` and `mix credo --strict` clean.
