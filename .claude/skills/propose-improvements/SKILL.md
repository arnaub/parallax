---
name: propose-improvements
description: Cross closed bug issues with the PRs that fixed and introduced them, plus recurring review comments, to propose process/tooling improvements. Manual only — invoke explicitly, never auto-triggered.
disable-model-invocation: true
---

Cross closed bug issues with the PRs that fixed them (and, where
identifiable, the PR that introduced the bug), plus recurring comments
from merged PR reviews. Group findings by root cause and affected
module/context.

Ignore any pattern with fewer than 3 cases — not enough signal to act on.

For each surviving group, classify the remedy as one of: a new/adjusted
Credo check, an AGENTS.md line, a docs update, a new skill, a `simplify`
pass, or removing an unused skill.

Write a report to `docs/reports/NNNN-topic.md` with the evidence
(issue/PR links, comment excerpts) behind each group, and draft the
strongest candidate's actual change as an example.

Never edit skills or docs directly — this skill only proposes; a human
applies the change.
