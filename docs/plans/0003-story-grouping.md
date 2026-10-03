# 0003 — Story grouping

Issue: [#5](https://github.com/arnaub/parallax/issues/5)
Branch: `5-story-grouping`

## Summary

A `Stories` context that groups Coverage into long-running Stories,
using an LLM (Gemini, free tier) to judge matches across outlets and
languages, and to screen out Coverage that isn't significant news.
Runs as its own daily batch job, independent of the hourly RSS poller.
Backend only — no UI, no synthesized explanation (that's a separate
future feature). See the issue for the full decision log from
`grill-me`, including why the original "same-day event" framing was
wrong and what was deliberately deferred.

**Revised after implementation started** (see ADR 0002's update and the
live verification run): `gemini-2.5-flash` turned out to be unavailable
to new API keys (a live 404, not just "legacy" as research suggested),
and its replacement `gemini-3.8-flash` has a real, low free-tier rate
limit (5 requests/minute, confirmed via a live 429) — tighter than any
secondary source reported. `Gemini` now paces and retries around this.
Separately, testing against real dashboard data surfaced that general
outlet feeds include lifestyle/culture/sports pieces (bullfighting
commentary, concert reviews) that shouldn't become Stories — this plan
now folds in a relevance screen, in the same Gemini call, rather than
deferring it.

## Contexts affected

- **New:** `Parallax.Stories`.
- **`Parallax.Feeds`** (existing) — gains small public functions so
  `Stories` never touches the `coverage` table directly (same context-
  ownership rule `Feeds` itself follows):
  - `list_unclustered_coverage/0` — Coverage where `story_id` is null
    **and** `relevant` is null (i.e. never screened, or screened and
    matched/created but not yet attached — in practice `story_id` and
    `relevant` are set together, so this is equivalent to "never
    screened").
  - `assign_story(coverage, story_id)` — sets `story_id`.
  - `mark_irrelevant(coverage)` — sets `relevant: false`, leaves
    `story_id` null.

## Schema

**`stories`** (new table)
- `title` (string, required)
- `description` (text, required)
- `last_coverage_at` (utc_datetime, required) — denormalized, bumped
  whenever Coverage attaches. This is what lets `Stories` list its own
  "most recently active" candidates with a plain query on its own
  table, instead of joining into `coverage` (which it doesn't own).

**`coverage`** (migration adds two columns)
- `story_id` (nullable, references `stories`, `on_delete: :nilify_all`
  — deleting a Story un-clusters its Coverage rather than destroying
  data)
- `relevant` (nullable boolean) — `null` means not yet screened, `false`
  means Gemini judged it not significant enough to become/join a Story
  (and it's never re-screened), `true` means it passed the screen (a
  `story_id` always accompanies `true`). Without this, an item Gemini
  correctly screens out today would just get re-screened — and
  re-billed against the rate limit — on every future run forever.

## Public API (`Parallax.Stories`)

- `list_stories(opts \\ [])` — newest-active first, optional `:limit`.
  Internally used with `limit: 50` to build the candidate list; also
  usable from tests/IEx unbounded, same pattern as `Feeds.list_coverage/1`.
- `cluster_unclustered_coverage/0` — the daily batch entrypoint.
  Fetches unclustered Coverage from `Feeds`, and for each item
  (**sequentially, paced** — see Concurrency and pacing below): builds
  the candidate list via `list_stories(limit: 50)`, calls `Matcher`,
  then marks it irrelevant, attaches it to the matched Story, or
  creates a new one. Logs and skips on a per-item Gemini failure, same
  failure-isolation philosophy as `Feeds.poll_outlet/1`; a failed item
  stays unclustered and unscreened, retried on the next day's run (an
  *irrelevant* item is not retried — it was successfully screened, just
  screened out).

## Supporting modules

- **`Parallax.Stories.Gemini`** — the only module that knows about the
  Gemini HTTP API. Takes a prompt, returns the raw structured response
  or `{:error, reason}`. Uses `gemini-3.8-flash` via the standard
  `generateContent` REST endpoint — `gemini-2.5-flash` (the plan's
  original choice) turned out to be unavailable to new API keys, found
  live via a real 404. Sets `generationConfig.response_mime_type:
  "application/json"` and a `response_schema` so parsing the decision
  back out is reliable, not regex-on-free-text. On a 429, retries up to
  twice, honoring the API's own `retryDelay` from the error body (a
  safety net — `Stories`' own pacing between calls, see below, is the
  primary defense). Mirrors `Feeds.Fetcher`'s role: isolates the
  external dependency so the rest of `Stories` doesn't know it's Gemini
  specifically, or what its rate limit is.
- **`Parallax.Stories.Matcher`** — builds the prompt from one Coverage
  item + its candidate Stories, calls `Gemini`, and interprets the
  response into one of: `:irrelevant`, `{:match, story_id}`, `{:new,
  title, description}`, or `{:error, reason}`. The prompt asks Gemini to
  first judge whether the item is significant news (politics/
  government, conflict/security, economy/business, or social issues —
  not lifestyle, culture, entertainment, or sports; any region/country
  counts if the event itself is significant) and only then to match or
  propose a title/description — all in the same call, so one Coverage
  item costs exactly **one** Gemini call no matter the outcome.
- **`Parallax.Stories.Scheduler`** — supervised GenServer, same shape
  as `Feeds.Poller`: schedules the first run a full interval (24h) out,
  calls `cluster_unclustered_coverage/0`, reschedules. Started in
  `Parallax.Application`'s children only when
  `Application.get_env(:parallax, :start_stories_scheduler, true)` is
  true — `config/test.exs` sets it `false`.
- **`Mix.Tasks.Stories.Cluster`** — `mix stories.cluster`, triggers one
  run on demand, same purpose as `mix feeds.poll`.

## Concurrency and pacing

Unlike `Feeds.poll_all_outlets/0` (concurrent — independent HTTP
endpoints, no shared limit), `cluster_unclustered_coverage/0` processes
Coverage items **sequentially**, and additionally sleeps a fixed
interval (13s, keeping calls under the confirmed 5/minute free-tier
cap with margin) before each Gemini call. Proactive pacing avoids
bursts of 429s rather than just reacting to them; `Gemini`'s own
retry-on-429 (above) is a safety net on top, not the primary strategy.
The interval is `config :parallax, :stories_call_interval_ms` —
`config/test.exs` sets it to `0` so tests stay fast. No latency
requirement exists for this un-urgent daily job, so the extra time
(minutes, for a realistic daily backlog) costs nothing real.

## Configuration

- `GEMINI_API_KEY` env var, read at call time (no fallback default —
  unlike the DB password, there's no sensible dev default for an API
  key). `Gemini` returns a clear `{:error, :missing_api_key}` up front
  if it's unset, rather than letting every item in a run fail with an
  opaque HTTP error. A local `.env` (gitignored) holds the real key for
  development; `.env.example` documents the variable without a value.
- `config :parallax, :stories_req_options` — same seam as
  `:feeds_req_options`, lets tests stub `Gemini`'s HTTP calls via
  `Req.Test` instead of hitting the network.
- `config :parallax, :stories_call_interval_ms` — the pacing delay
  between sequential Gemini calls; `0` in `config/test.exs`.

## Tests needed

- `Feeds.list_unclustered_coverage/0`, `assign_story/2`, and
  `mark_irrelevant/1`.
- `Stories.list_stories/1`: respects `:limit`; orders by
  `last_coverage_at` descending.
- `Matcher`: interprets a stubbed "irrelevant" response, a "matched
  existing story" response, a "no match, here's a new title/
  description" response, and a malformed/unexpected response as an
  error.
- `Gemini`: retries on a 429 honoring `retryDelay` from the body, falls
  back to a default delay when `retryDelay` is absent, and gives up
  after its retry limit.
- `cluster_unclustered_coverage/0`: a matched item gets attached (its
  Story's `last_coverage_at` bumps); an unmatched item creates a new
  Story; an irrelevant item is marked and never re-screened; one item's
  Gemini failure doesn't stop the rest from processing (same shape as
  the existing `poll_all_outlets/0` isolation test).
- `Scheduler`: light smoke test, same shape as `Feeds.PollerTest`.
- No automated test for the mix task; manual verification is enough.

## Docs to update once this lands

- `docs/glossary.md` — Story's definition (long-running situation, not
  a same-day event) and the Synthesis pending entry already landed in a
  prior PR. This feature adds two more Pending entries: **Story
  hierarchy** (parent/child Stories, e.g. a broad "AI" Story with
  narrower ones like "AI and the economy") and **Story relationships**
  (non-hierarchical links between Stories, e.g. climate change and AI)
  — both raised by the user, deliberately deferred as their own future
  features rather than folded into this one.
- `docs/architecture.md` — add the `Stories` context, extend Data flow
  to describe the daily clustering step and how it relates to `Feeds`.
- ADR 0002 (already written) needs a short update recording the
  mid-implementation model swap and the rate-limit pacing design.

## Open risks

- Gemini's free-tier terms typically include data being usable for
  model training. The content sent is public news headlines/summaries,
  not sensitive personal data, so this is low-stakes, but worth stating
  explicitly since it's a real tradeoff of the "free" choice.
- The ~50-most-recently-active candidate cap means a Story that's been
  completely quiet for a long time, then genuinely resumes, could
  theoretically miss being offered as a candidate if 50+ *other*
  Stories are more recently active. Accepted tradeoff; revisit if it
  turns out to matter in practice.
- The LLM is asked to produce a title/description in the same call
  that judges a match, for cost reasons — means a miscategorized "no
  match" also wastes the title/description generation. Low cost either
  way at this volume, not worth a second call to avoid.
- No test for actual Gemini prompt/response quality (only for how
  `Matcher` interprets stubbed responses) — matching *and* relevance-
  screening quality can only really be evaluated by running it against
  real data after merging.
- Free-tier rate limits and model availability have already changed
  twice during this feature's implementation and aren't reliably
  documented by Google (the rate-limit page says limits vary by
  project/region/account and aren't published). The 5/minute figure
  this plan paces against is empirically confirmed for this project's
  key today, not a documented guarantee — `Stories.Gemini` isolates the
  blast radius if it changes again.
- The relevance screen is a judgment call with real edge cases (is a
  major cultural event with political significance "culture" or
  "social issues"?) — expect to tune the prompt after seeing real
  results, not get it perfect on the first pass.

## Verification

- `mix test` covers the cases above.
- `mix stories.cluster` against real unclustered Coverage from the
  existing seeded outlets, then inspect `Stories.list_stories/0` and a
  few Coverage rows' `story_id` in `iex -S mix` to sanity-check
  clustering quality by eye — including at least one case spanning
  more than one language if the data allows it.
- `mix format --check-formatted` and `mix credo --strict` clean.
