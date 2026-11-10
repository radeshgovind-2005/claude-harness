# claude-harness

A Claude Code plugin marketplace with one plugin: **dev-harness**.

dev-harness sets up and runs software projects the way experienced Claude Code users do. Before anything gets built, it works out what you're making, who it's for, and what matters most. It then scaffolds memory files and guardrails that suit the kind of project: a prototype, a product, or an assignment. Changes get reviewed by a fresh-context skeptic, and every correction is kept as a lesson so the mistake doesn't come back.

> **Status: v0.3.0.** `help`, `discover`, `new`, `add` and `lesson` work, with the `dev-harness:skeptic` agent. The other skills arrive milestone by milestone; see [CHANGELOG.md](CHANGELOG.md) and the roadmap below.

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

Every profile blocks force push, `--no-verify`, reading `.env`, `rm -rf /`, `curl | sh`, and edits to hooks, secrets and lockfiles. What lands in the project: `CLAUDE.md` (a router under 100 lines), `docs/` (intent, architecture, conventions, workflow, lessons, agent guide), `.claude/hooks/` with `harness.conf`, `.claude/settings.json`, and a CI workflow that tests the hooks.

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
| 0.4.0 | `explore`, `lens`, `goal` |
| 0.5.0 | `showcase`, `architect` / `designer` / `tester` agents |
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
