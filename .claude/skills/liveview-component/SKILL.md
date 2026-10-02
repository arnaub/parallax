---
name: liveview-component
description: Create a LiveView or function component, following the reference LiveView in docs/architecture.md. Business logic stays in contexts; minimal assigns.
---

Follow the reference LiveView/component listed in `docs/architecture.md`
(marked `pending` until the first one is approved). The LiveView or
component calls into a context's public API and renders — it holds no
business logic itself (see `docs/coding-standards.md`).

Keep assigns minimal: only what the template needs, computed once rather
than recomputed on every render.

If this is the first LiveView/component being built, flag it to the
human: once approved, it becomes the reference in `docs/architecture.md`.
