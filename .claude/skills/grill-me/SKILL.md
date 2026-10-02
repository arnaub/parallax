---
name: grill-me
description: Interview the user about a feature one question at a time until no ambiguity remains, then summarize decisions. Use before planning any new feature.
---

Ask one question at a time about the feature: rules, edge cases, scope
boundaries, failure modes, and anything implied but unstated. Don't batch
questions, and don't move to the next one until the current one is
answered. Keep going until there's no real ambiguity left about what to
build.

End with a short, structured summary of the decisions made, in plain
language, as a record the user can sanity-check before `plan-feature`
turns it into a plan.

Don't propose a plan or touch any code here — that's `plan-feature`'s job.
