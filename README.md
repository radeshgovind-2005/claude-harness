# claude-harness

A Claude Code plugin marketplace with one plugin: **dev-harness**.

dev-harness sets up and runs software projects the way experienced Claude Code users do. Before anything gets built, it works out what you're making, who it's for, and what matters most. It then scaffolds memory files and guardrails that suit the kind of project: a prototype, a product, or an assignment. Changes get reviewed by a fresh-context skeptic, and every correction is kept as a lesson so the mistake doesn't come back.

> **Status: v0.5.0.** `help`, `discover`, `new`, `add`, `lesson`, `explore`, `lens`, `goal` and `showcase` work, with the agents `skeptic`, `lens-reviewer`, `architect`, `designer` and `tester`. What is left is v1.0.0 polish; see [CHANGELOG.md](CHANGELOG.md) and the roadmap below.

## Use

In any project folder:

```
/dev-harness:new a CLI that tracks my reading list
```

`new` runs `discover` first: Claude reflects back what it thinks the work is about, asks only what is missing, proposes 2–3 directions (one bold), and saves the decision to `docs/intent.md`. Then you pick a profile and it scaffolds the project. It never overwrites a file you already have.

| Profile | For | `main` | Check on stop | Push asks |
|---|---|---|---|---|
| prototype | spikes, demos, learning | allowed | off | no |
| product | real users or a team | blocked | typecheck + lint | yes |
| assignment | graded or course work | allowed | tests | no |

Every profile blocks force push, `--no-verify`, reading `.env`, `rm -rf /`, `curl | sh`, and edits to hooks, secrets and lockfiles. Shell commands that look like they change the guardrails (a redirect, `sed -i`, `curl -o`, `patch`, `git checkout`, and similar) ask you first; that is a best-effort list, not a sandbox. What lands in the project: `CLAUDE.md` (a router under 100 lines), `docs/` (intent, architecture, conventions, workflow, lessons, agent guide), `.claude/hooks/` with `harness.conf`, `.claude/settings.json`, and a CI workflow that tests the hooks.

## Add one part, record lessons, review

`/dev-harness:add <part>` adds one piece to a project you already have. It never overwrites.

| Part | Adds |
|---|---|
| `memory` | `CLAUDE.md` router, `docs/INDEX.md`, architecture, conventions, lessons, progress, experiments. It routes to files that `workflows` and `reviewer` add, and says so. `docs/intent.md` comes from `discover` |
| `lessons` | `docs/lessons.md` |
| `reviewer` | `docs/agents/INDEX.md`, the guide to the skeptic |
| `workflows` | `docs/workflow.md`, `docs/agents/first-workflow.md` |
| `rules` | `.claude/rules/` |
| `guardrails` | hooks, `harness.conf`, `.claude/settings.json`, CI (needs a profile) |
| `all` | all of the above; guardrails go in last |

`/dev-harness:lesson <what went wrong>` records a correction in `docs/lessons.md`. A similar lesson is updated instead of duplicated, a lesson about discovery is tagged `[discover]` so the next `discover` asks better questions, and a rule only moves into `CLAUDE.md` if you say yes.

`dev-harness:skeptic` is a plugin agent that tries to disprove a change. Give it only the goal and the diff. It reads, searches and runs your checks, and reports `STATUS`, issues with `file:line` and a failing scenario, and `NOT CHECKED`. It has no edit tools. It does have `Bash`, which Claude Code cannot restrict to read-only commands for a plugin agent, so "never edits" is only partly enforced: the tool list removes Edit and Write, and its instructions forbid shell writes. Your guardrail hooks also run on its calls but protect only hooks, settings, secrets and `main`, not your source files. Check `git status` after a review.

## Loops and review: `explore`, `lens`, `goal`

`/dev-harness:explore <what to improve>`: make a number better, one change at a time. You agree a metric (a command that prints a number), a direction and an optional target. For each variant a script measures, **keeps it only if it beats the best so far**, or restores the tree, and logs the row in `docs/experiments.md`. It stops at the target or after 2 variants in a row with no gain. Claude proposes and implements; the number decides.

`/dev-harness:lens [target]`: three fresh-context reviewers look at the work from outside: **UX** (the person who uses it), **DX** (the next developer) and **AX** (an AI agent working in the project). You get one ranked list with evidence. The AX reviewer is given script-checked facts (`ax-check.sh`: router under 100 lines, every route exists, hooks executable, placeholders left). It changes nothing.

`/dev-harness:goal <what must be true>`: keep working until a command exits 0. A Stop hook runs the check each time Claude tries to finish, sends it back with the failure, and ends the loop on success or when the **rounds and minutes** budget is used up, after one final-report turn. A checkpoint goes to `docs/progress.md` every round.

How `goal` differs from Claude Code's built-in `/goal`: the built-in one lets a small model judge from the conversation whether your condition is met, and a turn limit is only a request to that judge. Here the judge is your command's exit code and the budget is counted by the hook. There is **no token budget**: hooks get no token count (use `--max-budget-usd` for headless runs). The hook lives in the session where `goal` ran and is not re-registered on resume.

## Show it off and ask the right reviewer: `showcase` and the role agents

`/dev-harness:showcase [audience]` finds the most impressive part of the work and drafts a demo, a README section and talking points that match `docs/intent.md`. "Impressive" means it matters to whoever receives the work **and** it demonstrably works. It shortlists three candidates, picks one and says why the others lost, then **runs the demo steps** and labels every claim `VERIFIED` (a command ran), `READ` (`file:line`) or `UNVERIFIED`. Unverified claims stay out of the README text and are listed under `DO NOT CLAIM`. A script (`showcase-facts.sh`) supplies the facts: history, most-changed files, tests, measured gains from `docs/experiments.md`. It proposes only; the README is written after you say yes, and an existing section is never overwritten.

Five reviewers, one question each, so you pick one instead of sending the same question to several:

| Agent | Asks | Looks at | Its evidence |
|---|---|---|---|
| `skeptic` | Is this change wrong? | a diff | a failing scenario, the project's own checks |
| `lens-reviewer` | What does this person hit? | a target, one angle (UX, DX, AX) | commands run as that person |
| `architect` | Is the structure right, and what does each option cost? | modules and boundaries | counted imports and fan-in, 2-3 options, one recommendation |
| `designer` | Is the interface well made? | a UI's source and screenshots | computed contrast, missing states and focus; `NOT A UI` if there is none |
| `tester` | Would the tests catch a break? | the tests of some code | mutants made in a temporary copy, and which no test caught |

Like the skeptic, none of them has edit tools, and none can be stopped from writing through `Bash`; check `git status` after a review. Call them as `dev-harness:architect` and so on.

## Install

In Claude Code:

```
/plugin marketplace add radeshgovind-2005/claude-harness
/plugin install dev-harness@claude-harness
```

Then run `/dev-harness:help`.

Or from a shell:

```bash
claude plugin marketplace add radeshgovind-2005/claude-harness
```

```bash
claude plugin install dev-harness@claude-harness
```

Updates: `claude plugin update dev-harness@claude-harness`. Third-party marketplaces don't auto-update by default.

## Design in one paragraph

Skills and agents live in the plugin and work in every project. Strict hooks, like blocking edits on `main` or running checks before Claude stops, are copied **into** a project only when you pick a profile with `new` or `add`. The plugin itself ships no hooks, so it never blocks you in a project that didn't opt in. Rules that must never break are hooks, not lines in CLAUDE.md. Local hooks stop mistakes, not deliberate bypass, so also turn on branch protection and required CI on your Git host.

## Roadmap

| Version | Adds |
|---|---|
| 0.1.0 | Marketplace, plugin skeleton, `help` (done) |
| 0.2.0 | `discover`, `new`, profiles, guardrail hooks copied into projects (done) |
| 0.3.0 | `add`, `skeptic` agent, `lesson`, memory files (done) |
| 0.4.0 | `explore`, `lens`, `goal` (done) |
| 0.5.0 | `showcase`, `architect` / `designer` / `tester` agents (done) |
| 1.0.0 | Full docs, examples, full test pass |

The full design is in [BRIEF.md](BRIEF.md).

## Develop or fork

```bash
bash tests/validate.sh
```

```bash
claude --plugin-dir ./plugins/dev-harness
```

The first command validates both manifests, the layout rules, and runs `claude plugin validate`. The second loads the plugin from source for a session; run `/reload-plugins` after edits.

To publish your fork, change `owner` in `.claude-plugin/marketplace.json` and the URLs in `plugin.json`. Keep the plugin name `dev-harness`.

## License

MIT. See [LICENSE](LICENSE).
