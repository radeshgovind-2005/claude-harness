# Project

- Name: <project-name> — <one-line purpose>
- Stack: <language>, <framework>, <database>
- Stage: <prototype | production>

## Critical Rules

- IMPORTANT: Never commit secrets. Use env vars. Write the variable name, never the value.
- IMPORTANT: Never work on `main`. Use a branch or a git worktree.
- YOU MUST complete the Verification checklist before you say a task is done.
- <one project-specific must-follow rule>

## Working Principles

1. **Think first.** State your assumptions. If the task is unclear, ask. Do not guess.
2. **Keep it simple.** Write the minimum code for the task. No speculative features. No abstractions for single-use code. (Stage = prototype: relax this rule.)
3. **Change surgically.** Before you edit, read the file, its callers, and shared utilities. Change only what the task needs. Match existing conventions, even if you prefer another style. Raise concerns separately.
4. **Surface conflicts.** If two patterns in the code disagree, do not blend them. Use the more recent or better-tested one, say why, and flag the other.
5. **Test intent.** A test must fail if the business logic breaks. A test that cannot fail is wrong.
6. **Fail loud.** Report skipped steps, skipped tests, missing results, and uncertainty. Never say "done" for work you did not verify.

## Commands

- Install: `<cmd>`
- Dev server: `<cmd>`
- Test (all): `<cmd>`
- Test (one file): `<cmd> <path>`
- Lint / format: `<cmd>`
- Typecheck: `<cmd>`

## Routing

Read the file for your task before you start. Do not read all files.

| If the task is…                       | Read first                  |
|---------------------------------------|-----------------------------|
| New feature or structure change       | `docs/architecture.md`      |
| Naming, style, patterns               | `docs/conventions.md`       |
| Multi-step task, plan, branch, PR     | `docs/workflow.md`          |
| Bug or repeat problem                 | `docs/lessons.md`           |
| Subagents, parallel or wide work      | `docs/agents/INDEX.md`      |
| Not sure                              | `docs/INDEX.md`             |

Folder-specific rules load automatically from `.claude/rules/`.

## Verification (Definition of Done)

- [ ] Typecheck passes
- [ ] Tests for changed code pass (name the tests you ran)
- [ ] Lint is clean
- [ ] Edge cases the user asked about are checked
- [ ] Non-trivial change: the `skeptic` subagent reviewed the diff
- [ ] Final report: what changed, what is verified, what is NOT verified

## Self-Update

- When the user corrects you, add one entry to `docs/lessons.md` (or the user runs `/lesson`).
- If a lesson applies to every task, propose to move it into this file. Ask first.
- Keep this file under 100 lines. Propose to delete rules that no longer prevent mistakes.
