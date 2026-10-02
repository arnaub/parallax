---
name: create-pr
description: Open a pull request for the current branch via gh CLI, after gating on format/credo/tests and a readability review. Manual only — invoke explicitly, never auto-triggered.
disable-model-invocation: true
---

1. Check `mix format --check-formatted`, `mix credo --strict`, and
   `mix test` all pass. If any fail, stop and report — don't open the PR.
2. Run the `readability-reviewer` subagent on the diff (e.g.
   `git diff main...HEAD`). If it reports issues, stop and show them;
   don't open the PR until they're resolved.
3. If the diff is larger than ~400 changed lines, warn the human and
   suggest how to split it before continuing.
4. Title: `[#issue-number] Short imperative summary`. Branches are named
   `issue-number-slug` (see `AGENTS.md`) — parse the leading number; ask
   the human for it if it isn't derivable, and skip it if they say there
   isn't one.
5. Description, exactly two sections, nothing else:

   ```
   ## Why
   1-3 sentences: the problem or need, link to the issue or plan.

   ## What
   Up to 5 bullets: the changes a reviewer should know about.
   ```

   No file-by-file listing, no restating the diff.
6. Commits should already follow the short Conventional Commits
   convention in `docs/coding-standards.md` (`type: imperative summary`).
   If they don't, fix them before opening the PR rather than papering
   over it in the description.
7. Show the human the title and description and wait for approval before
   running `gh pr create`.
