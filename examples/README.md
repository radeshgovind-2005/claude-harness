# Examples

Real output from dev-harness, captured from headless runs on small throwaway projects. The output was not written by hand: each file starts with a header (plugin version, date, the command, how it was run, the project), then the output, with absolute paths shortened. Where a line was removed, the file says so. Two things to know: `claude -p` prints only Claude's final message, so a report can refer to earlier steps you do not see; and the agent examples (10, 11, 12) went through a parent session that was asked to return the report verbatim, so each is the parent's reply and not the agent's raw output (the file says so).

Read them as "what does it look like", not as proof that it works on your project. They are single runs on toy projects, and a headless run cannot answer prompts or approve tools, so every confirmation was given in the prompt. Two of them are about this repository itself, captured while 1.0.0 was being built.

| Example | Skill or agent | What it shows |
|---|---|---|
| [01-new-product.md](01-new-product.md) | `new` | what lands in a project, what Claude reports as not done, `ax-check.sh` on the result |
| [02-discover-scripted.md](02-discover-scripted.md) | `discover` | reflect back, questions, three directions, the decision, `docs/intent.md`. Scripted answers, not a real conversation |
| [03-explore.md](03-explore.md) | `explore` | a measured variant kept by the script; the log and the commit |
| [04-goal-met.md](04-goal-met.md) | `goal` | a failing test suite fixed, the Stop hook confirming it |
| [05-goal-edge-cases.md](05-goal-edge-cases.md) | `goal` | the session limit after repeated blocks, and what `--continue` does to a goal |
| [06-assignment-profile.md](06-assignment-profile.md) | `new`, guardrails | the assignment profile, and its Stop hook blocking a deliberate break |
| [07-showcase.md](07-showcase.md) | `showcase` | an unreproducible claim kept out of the pitch |
| [08-lens-this-repository.md](08-lens-this-repository.md) | `lens` | three reviewers on this repository: a ranked list with evidence |
| [09-showcase-this-repository.md](09-showcase-this-repository.md) | `showcase` | the pick that became the README's "Does it get in my way?" |
| [10-tester.md](10-tester.md) | `tester` | mutants in a temporary copy, and the tests that missed them |
| [11-architect.md](11-architect.md) | `architect` | structure facts, options with costs, a recommendation |
| [12-designer.md](12-designer.md) | `designer` | accessibility and contrast findings from source, with computed ratios |
| [13-task-cards.md](13-task-cards.md) | `split`, `resume`, `handoff`, task hooks | three cards from an intent, a no-tools session that knows the active card (SessionStart), a handoff, the PreCompact note in the card, and an overlap FAIL that one dependency does not fix |

The `skeptic` is not here because its report is the same kind of list as `lens` and `tester`; `docs/progress.md` records each time it found something.
