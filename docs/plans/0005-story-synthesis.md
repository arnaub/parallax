# 0005 — Story synthesis

Issue: [#11](https://github.com/arnaub/parallax/issues/11)
Branch: `11-story-synthesis`

## Summary

A detail page per Story (`/stories/:id`) showing an LLM-generated,
versioned synthesis: how the situation started, where it stands now,
2-4 named perspectives specific to that story, how each outlet's
coverage aligns with one of them (or none), and why it matters.
Generated incrementally — each version builds on the previous one plus
only the newly-attached Coverage, not a resample of the whole history —
as part of the existing daily clustering job. See the issue for the
full decision log from `grill-me`.

Outlet attribution is a real foreign key, validated before storage —
not trusted LLM text. Gemini proposes an `outlet_id` per framing; a
framing is only persisted if that id is actually one of the outlets
whose Coverage was fed into this call. There is no way to end up with a
framing attributed to an outlet that doesn't exist or wasn't part of
this Story's input.

## Schema

**`story_syntheses`** (new table) — one row per generated version, never
updated in place.
- `story_id` (references `stories`, `on_delete: :delete_all` — a
  synthesis has no meaning without its Story, unlike Coverage)
- `started` (text, required) — how the situation began
- `current_state` (text, required) — where it stands now
- `implications` (text, required) — why it matters
- `timestamps` — `inserted_at` doubles as "generated at"; this is what
  the next version's "only new Coverage since then" query uses as its
  cutoff

Index: `(story_id, inserted_at)`, so fetching a Story's latest version
is a cheap, direct query.

**`story_synthesis_perspectives`** (new table) — the 2-4 viewpoints this
specific synthesis version identified, e.g. "Government" / "Tenants'
unions" for the housing crisis.
- `synthesis_id` (references `story_syntheses`, `on_delete: :delete_all`)
- `label` (string, required)
- `description` (text, required) — one sentence on what this
  perspective argues

**`story_synthesis_outlet_framings`** (new table) — replaces a JSONB
blob with real references.
- `synthesis_id` (references `story_syntheses`, `on_delete: :delete_all`)
- `outlet_id` (references `outlets`, `on_delete: :delete_all`) — a real
  FK into `Feeds`' `Outlet`, same cross-context reference pattern
  `Coverage.story_id` already uses
- `perspective_id` (references `story_synthesis_perspectives`,
  nullable, `on_delete: :nilify_all`) — null means this outlet's
  coverage doesn't clearly align with any of the defined perspectives
  (plain reporting, not taking a side)
- `framing` (text, required) — what's distinct about how this outlet
  covers it

## Public API additions

**`Parallax.Feeds`**
- `list_coverage_by_story(story_id, opts \\ [])` — a Story's linked
  Coverage, oldest first, Outlet preloaded. `opts[:since]` filters to
  `inserted_at > since` for the incremental case; omitted, returns
  everything (used only for a Story's first-ever synthesis).

**`Parallax.Stories`**
- `get_story!/1` — for the detail LiveView.
- `latest_synthesis/1` — a Story's newest `Synthesis` row, or `nil`.
- `synthesize_stories_with_new_coverage/0` — the second phase of the
  daily job (see Scheduler below). For each Story whose
  `last_coverage_at` is newer than its latest synthesis (or has none
  yet), builds and stores a new version. Same failure-isolation
  philosophy as clustering: one Story's failure is logged and skipped,
  retried next run.

Finding "Stories needing synthesis" is a `Stories`-internal query
(Story joined against a "latest synthesis per story" subquery,
comparing timestamps) — not threaded through `cluster_unclustered_coverage/0`'s
return value, which stays unchanged so its existing tests don't need to
change.

## Supporting module: `Parallax.Stories.Synthesizer`

Mirrors `Matcher`'s role: builds the prompt, calls `Gemini` (the
existing client, same model/retry/pacing — no changes needed there,
just a new response schema), interprets the result.

- **Input selection** (the main piece of new logic):
  - Story has a previous synthesis → `Feeds.list_coverage_by_story(id, since: previous.inserted_at)`. Only the delta.
  - Story has none yet → `Feeds.list_coverage_by_story(id)`, then
    capped in Elixir to the most recent 3 per outlet (~20-25 items
    total) before prompting. Needed because a Story backfilled with a
    large existing batch (e.g. today's 62-article housing-crisis
    Story) can't reasonably go into one prompt; after this first
    version, the incremental path takes over and this never recurs for
    that Story.
- **Prompt** includes the previous synthesis's full content (started,
  current state, implications, perspectives, framings) if any, and
  instructs Gemini to produce an *updated* synthesis incorporating the
  new Coverage — not regenerate from scratch. Each Coverage item fed in
  is labeled with its real `outlet_id`, and the prompt tells Gemini to
  reference outlets only by that id. Explicit instruction to stick to
  what's reported, not speculate beyond it, for "why it matters".
- **Response schema**: `started`, `current_state`, `implications` as
  strings; `perspectives` as an array of `{label, description}`;
  `outlet_framings` as an array of `{outlet_id, perspective_label,
  framing}` — `perspective_label` nullable, matched against the
  `perspectives` array in the same response (not a DB id yet, since
  perspectives are being created in this same call).
- **Storing the result** (one transaction): insert the `Synthesis` row,
  insert its `Perspective` rows and build a `label -> id` map, then
  insert `OutletFraming` rows — dropping any whose `outlet_id` isn't in
  the known candidate set for this call, and resolving
  `perspective_label` through the map (`nil` if absent or unmatched).

## Scheduler

`Stories.Scheduler`'s existing daily tick gains a second step: after
`cluster_unclustered_coverage/0` completes, it calls
`synthesize_stories_with_new_coverage/0`. One daily cadence, same
pacing/interval config already in place — no new scheduler.

## LiveView

- **`ParallaxWeb.StoryLive`** (`/stories/:id`), new route. Loads the
  Story and its latest synthesis (preloading `perspectives` and
  `outlet_framings` with their `outlet`). Renders started/current
  state/implications as text, and outlet framings grouped under their
  perspective's label (an "unaligned" group for `perspective_id: nil`
  framings). If no synthesis exists yet, falls back to the Story's
  `description` with a note that the full breakdown is pending.
- **`DashboardLive`**: `story_card/1` wraps the title in a link to
  `~p"/stories/#{story.id}"`.

## Tests needed

- `Feeds.list_coverage_by_story/2`: returns only that Story's Coverage;
  `:since` filters correctly.
- `Synthesizer`: interprets a stubbed Gemini response into Synthesis +
  Perspectives + OutletFramings; **drops a framing whose `outlet_id`
  wasn't among the candidates fed into the call**; resolves
  `perspective_label` to the right `perspective_id`, and to `nil` when
  absent or unmatched; builds the capped per-outlet sample correctly
  for a first-ever synthesis; builds the since-filtered input correctly
  for an incremental one.
- `Stories.synthesize_stories_with_new_coverage/0`: a Story with new
  Coverage since its last synthesis gets a new version; a Story with no
  new Coverage is skipped; one Story's Gemini failure doesn't stop the
  others.
- `StoryLive`: renders started/current state/implications and outlet
  framings grouped by perspective from a real synthesis; falls back to
  `description` when none exists; 404s (or redirects) for an unknown
  id.
- `DashboardLiveTest`: story cards link to the right detail route.

## Docs to update once this lands

- `docs/architecture.md`: extend Data flow to describe the synthesis
  phase and `StoryLive`.
- `docs/glossary.md`: move "Story synthesis" from Pending to Defined.

## Open risks

- Outlet framing quality depends entirely on Gemini's judgment and
  can't be verified beyond "does the schema parse" in automated tests —
  same caveat as matching/relevance quality, evaluated against real
  data after merging.
- The incremental approach means a Story's synthesis is only as good as
  its first version plus each day's delta — if an early version
  mischaracterizes something, that error can persist across later
  versions unless the delta content happens to correct it. Accepted
  tradeoff for now; the stored version history (even unused by the UI
  yet) means this is at least inspectable later.
- "Most recent 3 per outlet" for first-ever synthesis is a guess, same
  kind of guess the ~50-candidate cap was for matching — revisit if it
  turns out wrong in practice.
- Perspectives are regenerated fresh each version, by label text, not a
  stable identity across versions (e.g. "Government" one day could
  become "PSOE" the next) — fine for now since only the latest version
  is ever displayed, but worth resolving before any future "see how
  this evolved" history view is built on top of these rows.

## Verification

- `mix test` covers the cases above.
- Run the daily job manually (`mix stories.cluster` already exists; may
  need a small on-demand mix task or just call
  `Stories.synthesize_stories_with_new_coverage/0` directly in
  `iex -S mix`) against the real local data already seeded, including
  the 62-article housing-crisis Story, to confirm the capped first-run
  sampling behaves reasonably.
- `mix phx.server`, click through from the dashboard to a Story's
  detail page, confirm all four sections render.
- `mix format --check-formatted` and `mix credo --strict` clean.
