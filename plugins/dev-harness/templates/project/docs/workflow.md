# Workflow

Read this before multi-step work, commits, or PRs.

## Plan → Execute → Verify

1. **Plan.** For changes to more than 3 files, or unclear tasks, use plan mode. Show the plan. Wait for approval.
2. **Execute.** Work on a branch or git worktree. Product profile: never on `main` (a hook blocks it). Other profiles: `main` is allowed, but branch for risky changes.
3. **Verify.** Run the Verification checklist in `CLAUDE.md`.

## Find Fake Edges (before you plan steps)

For each step, ask: does this step need the output of the step before it?

- **Yes** → keep the order.
- **No** → the steps are independent. Run them in parallel (subagents or a workflow).

## Checkpoints (multi-step tasks)

After each significant step, write:

- **Done:** what changed
- **Verified:** what you checked, and how
- **Next:** what is left

Do not continue from a state you cannot describe. If you lose track, stop and restate.

## Git

- Branch name: `<type>/<short-description>` (types: feat, fix, refactor, docs, chore).
- Small commits. One logical change per commit.
- Commit message: imperative mood, e.g. "Add retry to payment client".
- Product profile: push the branch and open a PR; never push to `main`. Other profiles: follow the user's habit.

## Parallel Work

- Use one git worktree per parallel task: `git worktree add ../<repo>-<task> -b <type>/<task>`.
- Two tasks that write the same file are NOT independent. Run them in order.

## Long or parallel work (task cards)

State lives in files, not in the conversation. A session is disposable; a card in `docs/tasks/` is not.

- **Split** a goal into cards with `/dev-harness:split`. Cards whose scopes overlap are not parallel unless one depends on the other; `tasks.sh check` enforces it.
- **One card per session.** `/dev-harness:resume <id>` loads only what that card needs and makes it the active card; the SessionStart hook brings it back after `/clear` or a compaction.
- **Parallel:** `tasks.sh worktree <id>` gives each card its own branch and worktree. Two sessions never share a scope.
- **Hand off, then clear.** Before you stop, `/dev-harness:handoff` writes decisions, status, what is verified and the next step into the card. A fresh session with the card beats a long compacted one.
