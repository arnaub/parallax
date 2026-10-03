# Glossary

Domain terms used across Parallax. Add a term here when a feature that
needs it goes through `grill-me`/`plan-feature` — don't invent terms ahead
of the feature that needs them.

## Defined

- **Story** — an ongoing real-world situation (e.g. an armed conflict, a
  political crisis), independent of any one outlet or moment in time. A
  Story can accumulate Coverage over weeks or months, with quiet periods
  in between — it's not a single day's news event.
- **Coverage** — one outlet's article reporting on a Story. A Story
  typically has Coverage from several outlets and languages, which is
  what lets Parallax show differences in how it's told.
- **Dashboard** — the main view: the most relevant Stories and a summary
  of what happened, ranked by the user's Interests.
- **Interests** — the signals that drive relevance: topics, outlets, and
  keywords the user sets explicitly, refined by what they actually read.
- **Outlet** — a news source Parallax ingests from: a name, homepage,
  RSS/Atom feed URL, and language. Every piece of Coverage belongs to one
  Outlet.

## Pending

Defined only once the related feature is planned, not before:

- What a finished/finite reading session means in product terms
- Preference learning — what signals feed it, how they decay or update
- Story synthesis — the evolving multi-perspective explanation of a
  Story (origin, current state, each side's framing, implications),
  built from its Coverage. A separate feature from Story grouping.
- Story hierarchy — parent/child relationships between Stories, e.g. a
  broad "AI" Story with narrower ones like "AI and the economy"
  underneath it. A separate feature from Story grouping; related to the
  topic-tags idea already considered and deferred during grouping.
- Story relationships — non-hierarchical links between otherwise
  separate Stories (e.g. climate change and AI). Depends on Stories
  existing first; a separate future feature.
- Outlet leaning analysis — aggregating an outlet's perspective
  alignment across many Stories' syntheses (real `outlet_id`/
  `perspective_id` foreign keys, not re-analyzed text) to surface
  patterns in how an outlet tends to frame conflicts. Depends on Story
  synthesis existing first and running across enough Stories to be
  meaningful; a separate future feature.
- Any term needed for notifications, digests, or search
