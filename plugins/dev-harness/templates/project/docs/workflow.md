# Workflow

Read this before multi-step work, commits, or PRs.

## Plan → Execute → Verify

1. **Plan.** For changes to more than 3 files, or unclear tasks, use plan mode. Show the plan. Wait for approval.
2. **Execute.** Work on a branch or git worktree. Never on `main`.
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
- Push the branch and open a PR. Never push to `main`.

## Parallel Work

- Use one git worktree per parallel task: `git worktree add ../<repo>-<task> -b <type>/<task>`.
- Two tasks that write the same file are NOT independent. Run them in order.
