# 0004 — Dashboard lists Stories instead of raw Coverage

Issue: [#8](https://github.com/arnaub/parallax/issues/8)
Branch: `8-dashboard-lists-stories`

## Summary

Now that Story grouping exists, `DashboardLive` switches from listing
raw per-outlet Coverage to listing Stories — the grouped, screened
situations that are the actual product value. Small, focused change to
an existing feature; see the issue for the scoping decisions.

## Changes

- **`ParallaxWeb.DashboardLive`**: `mount/3` calls
  `Stories.list_stories(limit: 30)` instead of
  `Feeds.list_coverage(limit: 30)`. Same page size, same "finite, no
  live updates" behavior — only the data source and card content
  change.
- **Template / `story_card/1`** replaces `coverage_card/1`: renders
  just the Story's `title` and `description`. No outlet list, no
  link-out (a Story has many outlets, not one — see docs/glossary.md).
  No click-through — there's no Story detail page yet (Story synthesis,
  a separate future feature, will add one).
- **`Stories.list_stories/1`** (existing, from Story grouping) already
  does exactly what's needed — newest-active first, `:limit` option.
  No changes needed there. All Stories show regardless of linked
  Coverage count, per the scoping decision.
- Empty state message updates to reflect Stories instead of Coverage
  (e.g. "No stories yet — wait for the next scheduled poll and
  clustering run, or run `mix feeds.poll` then `mix stories.cluster`.").

## Tests needed

- `DashboardLiveTest`: update existing tests to seed Stories (not raw
  Coverage) and assert on title/description rendering, empty state,
  and ordering (newest-active first).

## Docs to update

- `docs/architecture.md`: Data flow section — `DashboardLive` now reads
  `Stories.list_stories/1`, not `Feeds.list_coverage/1`. Nothing reads
  Coverage directly from the UI anymore.

## Verification

- `mix test`.
- `mix phx.server`, confirm the dashboard renders real Stories from the
  local dev DB (seeded via the real RSS + clustering pipeline, not
  fabricated data).
- `mix format --check-formatted` and `mix credo --strict` clean.
