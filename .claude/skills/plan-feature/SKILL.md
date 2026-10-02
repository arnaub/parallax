---
name: plan-feature
description: Turn a grilled feature (decisions from grill-me) into a written plan in docs/plans/. Never writes code. Stops for human approval.
---

Write a plan to `docs/plans/NNNN-feature-slug.md` (next available number)
covering: files to touch, contexts affected (see `docs/architecture.md`),
tests needed, and open risks.

Reference `docs/architecture.md` for context boundaries and reference
modules, and `docs/coding-standards.md` for conventions — don't restate
either, point to them.

Never write application code in this skill. Stop once the plan is written
and ask the human to approve it before any implementation starts.
