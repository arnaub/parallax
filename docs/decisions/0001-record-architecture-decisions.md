# 1. Record architecture decisions

Date: 2026-10-02

## Status

Accepted

## Context

We need a way to record architecturally significant decisions made in this
project — the ones that are expensive to reverse, or where a future
contributor (human or agent) needs the reasoning, not just the outcome.
Without a record, decisions live only in chat history and get
re-litigated.

## Decision

We use Architecture Decision Records (ADRs), one per decision, stored in
`docs/decisions/` as `NNNN-short-title.md`, numbered sequentially and never
renumbered or deleted. Each ADR is short: Status, Context, Decision,
Consequences. This is ADR 1, following the format proposed by Michael
Nygard.

## Consequences

- A significant decision (new dependency, context boundary, data model
  choice, notable tradeoff) gets an ADR before or right after it's made.
- Superseding a decision means writing a new ADR that references the old
  one and marking the old one's status `Superseded by NNNN` — not editing
  or deleting it.
- Small or easily reversible choices don't need an ADR; use judgment.
