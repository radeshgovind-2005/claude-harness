# Task cards

State lives in files, not in the conversation. One card per piece of work, in `docs/tasks/NNN-slug.md`, in the form of `_template.md`. A session is disposable; a card is not: any session or person can pick up one card with a small, clean context.

- **Split** a goal into cards: `/dev-harness:split`. Two cards whose `scope` globs overlap are not parallel unless one `depends` on the other; `tasks.sh check` fails until that is fixed.
- **Pick up** a card: `/dev-harness:resume <id>` (sets it as the active card for this worktree). Parallel work: `tasks.sh worktree <id>` gives the card its own branch and worktree.
- **Hand off** before you stop or `/clear`: `/dev-harness:handoff` updates the card (decisions, status, verified, next). Prefer handoff, `/clear`, resume over a long compacted session.

The table below is written by `tasks.sh index`; do not edit it by hand (`tasks.sh check` fails when it drifts from the cards).

<!-- tasks:index:start -->
| id | title | status | owner | depends |
|---|---|---|---|---|
<!-- tasks:index:end -->
