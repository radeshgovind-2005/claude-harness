# Agents & Delegation

Read this before you spawn subagents or start a workflow.

## Which Tool for Which Task

| Task shape | Use |
|---|---|
| Small task, one file, one bug | Single agent (no delegation) |
| Steps that depend on each other | Single agent + plan mode |
| Exploration, goal not clear yet | Single agent the user steers |
| One side task that would fill the context (search, log reading) | Subagent |
| Independent check of finished work | fresh-context subagent, e.g. `dev-harness:skeptic` |
| Wide, independent work: many files, many angles | Dynamic workflow |

**Test:** if you cannot find two jobs with no data passing between them, do not parallelize.

## Available Subagents

| Name | File | Use for |
|---|---|---|
| `dev-harness:skeptic` | plugin agent (needs the dev-harness plugin installed) | Try to disprove a diff before it is reported as done. Give it only the goal and the diff. It has no edit tools and is told not to write, but its `Bash` can still write: check `git status` after a review |
| `dev-harness:lens-reviewer` | plugin agent, started by `/dev-harness:lens` | Look at the work as the user (UX), the next developer (DX) or an AI agent (AX). Run it through `lens`, which gives each angle its checklist |
| `dev-harness:architect` | plugin agent | Judge structure and design trade-offs before a larger change: boundaries, who depends on whom, 2-3 options with costs, one recommendation. Give it the question and the target |
| `dev-harness:designer` | plugin agent | Judge a user interface: hierarchy, spacing, consistency, states, contrast, focus, responsiveness. Says `NOT A UI` when there is none. Give it the target and screenshots if you have them |
| `dev-harness:tester` | plugin agent | Check the tests can fail: it breaks the logic in a temporary copy and lists the mutants no test caught, plus missing tests. Give it the code and the test command |

All of these have no edit tools and are told not to write, but their `Bash` can still write: check `git status` after a review.

**Which reviewer for what:** `skeptic` asks "is this change wrong?" (a diff). `lens-reviewer` asks "what does this person hit?" (one angle). `architect` asks "is the structure right?". `designer` asks "is the interface well made?". `tester` asks "would the tests catch a break?". Do not send one question to two of them; pick the one whose question it is.

## Rules for Multi-Agent Work

1. **Never let a worker check its own work.** The verifier gets only the goal and the diff or finding, never the worker's conversation.
2. **Isolate writers.** Each agent that edits files works in its own git worktree.
3. **Count the fan-in.** Compare results returned against jobs started. Report every missing result.
4. **Anchor on real signals.** A test that ran and passed beats any agent's opinion.
5. **Start small.** First run on one folder or ≤ 10 items. Check the token cost. Then widen.
6. **Use cheap models for simple stages.** Use the strong model only where judgment matters.

## Workflows

- Trigger: say "use a workflow" or start the prompt with `ultracode`.
- Watch and stop runs: `/workflows`.
- Save a good run: `/workflows` → select the run → `s` → `.claude/workflows/`.
- First run: follow `docs/agents/first-workflow.md`.
