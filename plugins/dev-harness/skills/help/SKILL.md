---
name: help
description: Show how to use dev-harness — every skill and agent, when to use it, and one example each.
argument-hint: "[skill-name]"
disable-model-invocation: true
allowed-tools: Read(/${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json)
---

Show the user how to use dev-harness. Plugin version: read `version` from `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` and state it.

If `$ARGUMENTS` names one skill or agent below, show only that row plus a two-line explanation. Otherwise print the guide below as-is. Keep the status column. Never claim a "planned" skill works; if the user asks for one, say which version it arrives in.

## Start here

- New project or new idea: `/dev-harness:new`. It runs `discover` first, asks for a profile, then scaffolds.
- Existing project: `/dev-harness:discover` to write `docs/intent.md`, then `/dev-harness:new` (it never overwrites your files). To add just one piece, use `/dev-harness:add <part>`.

## Skills

| Skill | Use it when | Example | Status |
|---|---|---|---|
| `help` | You want this guide | `/dev-harness:help discover` | available |
| `discover` | Before building anything: work out who it is for, what matters, where to push. Writes `docs/intent.md`. No code | `/dev-harness:discover here is the assignment text: …` | available |
| `new` | Full setup of a project: discover, pick a profile (prototype / product / assignment), scaffold files. Never overwrites | `/dev-harness:new a CLI that tracks my reading list` | available |
| `add <part>` | Add one part to an existing project: guardrails, reviewer, lessons, memory, workflows, rules, all. Never overwrites | `/dev-harness:add guardrails` | available |
| `lesson` | You corrected Claude; record it in `docs/lessons.md` so it does not repeat. Updates a similar lesson; asks before promoting to `CLAUDE.md`. Lessons about discovery feed the next `discover` | `/dev-harness:lesson ran tests in the wrong folder` | available |
| `explore` | You want to try variants against a metric: keep what improves, revert what doesn't. Logs `docs/experiments.md` | `/dev-harness:explore cut p95 latency of /search` | planned v0.4.0 |
| `lens` | Review the work from three angles: user (UX), developer (DX), agent (AX) | `/dev-harness:lens the onboarding flow` | planned v0.4.0 |
| `goal` | Work toward a success check on autopilot, with a turn budget and a checkpoint each step | `/dev-harness:goal all tests in tests/api pass` | planned v0.4.0 |
| `showcase` | Find the most impressive part and turn it into a demo, README section, talking points | `/dev-harness:showcase` | planned v0.5.0 |

## Agents

| Agent | Use it when | Status |
|---|---|---|
| `skeptic` | After a non-trivial change: tries to disprove it. Gets only the goal and the diff; reads and runs checks, has no edit tools (its `Bash` can still write, so check `git status`). Call it as `dev-harness:skeptic` | available |
| `architect` | Structure and design trade-offs | planned v0.5.0 |
| `designer` | UI, UX, visual quality | planned v0.5.0 |
| `tester` | Missing tests; checks tests can actually fail | planned v0.5.0 |

## Profiles (chosen in `new`)

| | prototype | product | assignment |
|---|---|---|---|
| Edits, commits, pushes on `main` | allowed | blocked | allowed |
| Check when Claude stops (`VERIFY_CMD`) | off | typecheck + lint | tests |
| `git push` asks first | no | yes | no |
| Claude explains each step | no | no | yes |

Force push, `--no-verify`, reading `.env`, `rm -rf /`, `curl | sh` and editing hooks or secrets are blocked in every profile.

## How it works

- Skills and agents live in the plugin and work in every project.
- Strict hooks are copied **into** a project only when you choose a profile in `new`. The plugin itself ships no always-on hooks. `discover` adds one while discovery is open: it blocks code edits until `docs/intent.md` says `status: decided`.
- Profile settings live in `.claude/hooks/harness.conf`. Only you edit it: Claude's file edits there are blocked, and shell commands that change it ask you first.
- Local hooks stop mistakes, not deliberate bypass. Use branch protection and required CI on your Git host too.

Source and issues: https://github.com/radeshgovind-2005/claude-harness
