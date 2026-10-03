# 2. Use an LLM, via Gemini's free tier, to group Coverage into Stories

Date: 2026-10-03

## Status

Accepted

## Context

Parallax needs to group Coverage into Stories — long-running real-world
situations (e.g. an armed conflict) that accumulate Coverage from
different outlets, in different languages, over weeks or months. This
requires judging whether a new piece of Coverage is about the same
situation as an existing Story.

Simple heuristics (title/keyword similarity, URL patterns) don't
reliably work here: the outlet set is explicitly multilingual
(English, Spanish, Catalan), and the same situation is described with
different words, names, and framing across languages. An LLM can make
this judgment in a way keyword matching cannot.

## Decision

- An LLM judges the match, one call per new Coverage item, given a list
  of candidate Stories. The same call also produces a title/description
  for a new Story if there's no match, so a match costs exactly one
  call either way.
- **`gemini-2.5-flash`**, via the standard `generateContent` REST
  endpoint, does the judging. Chosen over:
  - **Claude** (Haiku, even via Batch API's ~50% discount) — real
    non-zero cost, when a free option covers this project's volume
    comfortably.
  - **`gemini-3.5-flash`** / the newer Interactions API — Google's
    current recommended path for new projects, but its free-tier limit
    is unverified and one report puts it as low as 20 requests/day,
    which a single day's polling volume could exhaust. `gemini-2.5-flash`'s
    1,500/day free tier is well-confirmed across multiple sources and
    not deprecated, just "legacy" naming — `generateContent` itself
    remains fully supported.
  - **A local open-weight model (e.g. via Ollama)** — genuinely free
    and keeps data fully local, but noticeably weaker cross-language
    judgment than Gemini/Claude, undermining the main reason an LLM was
    chosen over heuristics in the first place.
  - **Topic tags as a cheaper pre-filter** (narrow candidates by topic
    before matching) — considered for controlling candidate-list size,
    rejected: assigning a tag is itself a fuzzy matching problem with
    the same cross-language difficulty, not a simplification.
- Candidate Stories are capped to the ~50 most recently active (by
  `last_coverage_at`, not absolute age) rather than a time window —
  bounds cost predictably without a same-day-event assumption that
  would break long-running Stories.
- Clustering runs once a day, as its own scheduled job independent of
  the hourly RSS poller — matches the product's deliberately
  non-real-time design, and keeps request volume low and predictable.
- The same Gemini call also screens relevance: only significant news
  (politics/government, conflict/security, economy/business, major
  social issues — any region, not just world/Europe/Spain/Catalonia,
  as long as the event itself is significant) becomes a Story;
  lifestyle, culture, entertainment, and sports Coverage is screened
  out and never re-screened. Folded into the existing matching call for
  zero extra API cost, rather than deferred to a later feature.

## Update — 2026-10-03, after implementation started

Two things changed after this ADR's decisions were made and
implementation began, both found live rather than from documentation:

- **`gemini-2.5-flash` turned out to be unavailable to new API keys** —
  a real 404 from the API ("no longer available to new users"), not
  just "legacy" as research had suggested. Switched to
  **`gemini-3.8-flash`**, still via `generateContent`.
- **The free tier's real rate limit is tight**: a live 429 confirmed
  **5 requests/minute** for this project — far below anything
  secondary sources reported (which ranged from 20/day to 1,500/day).
  Google's own rate-limit docs now say limits aren't published and vary
  per project/region/account, visible only on each account's own AI
  Studio page — so this number is empirically confirmed for this
  project today, not a documented guarantee.
- **503 "model overloaded" turned out non-rare in practice** — 2 of 7
  calls in one short live verification run. Added the same retry
  treatment as 429 (`Stories.Gemini` retries up to twice, honoring the
  API's own `retryDelay` when present).

Response to the rate limit: `Stories` now paces sequential calls (13s
apart, configurable via `:stories_call_interval_ms`) to stay under the
confirmed limit proactively, with `Gemini`'s retry-on-429/503 as a
safety net, not the primary defense. This changes nothing about the
core decision (LLM-based matching, Gemini's free tier) — it's the same
conclusion the original "revisit if free tier proves insufficient"
consequence below anticipated, just exercised sooner than expected.

## Consequences

- `GEMINI_API_KEY` is required in any environment that runs clustering
  for real (not set in CI/test — `Stories.Gemini` is stubbed there).
- Clustering quality depends on Gemini's judgment and can't be unit
  tested beyond "does `Matcher` correctly interpret a given response" —
  actual matching quality can only be evaluated against real data after
  deploying.
- Google's free tier typically permits using submitted content to
  improve their models. The content sent is public news headlines and
  summaries, not sensitive personal data, so this is accepted as
  low-stakes.
- If `gemini-2.5-flash`'s free tier is ever reduced, retired, or proves
  insufficient in practice, revisit this decision — the dependency is
  isolated entirely in `Stories.Gemini`, so switching models or
  providers doesn't touch `Stories.Matcher` or anything else in
  `Stories`.
