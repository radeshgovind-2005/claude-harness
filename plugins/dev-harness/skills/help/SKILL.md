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

Only `help` works in this version. Once they ship:

- New project or new idea: `/dev-harness:new` (v0.2.0). It runs `discover` first, then scaffolds.
- Existing project: `/dev-harness:discover` (v0.2.0), then `/dev-harness:add all` (v0.3.0).

## Skills

| Skill | Use it when | Example | Status |
|---|---|---|---|
| `help` | You want this guide | `/dev-harness:help discover` | available |
| `discover` | Before building anything: work out who it is for, what matters, where to push. Writes `docs/intent.md`. No code | `/dev-harness:discover here is the assignment text: …` | planned v0.2.0 |
| `new` | Full setup of a project: discover, pick a profile (prototype / product / assignment), scaffold files. Never overwrites | `/dev-harness:new a CLI that tracks my reading list` | planned v0.2.0 |
| `add <part>` | Add one part to an existing project: guardrails, reviewer, lessons, memory, workflows, rules, all | `/dev-harness:add guardrails` | planned v0.3.0 |
| `lesson` | You corrected Claude; record it in `docs/lessons.md` so it does not repeat | `/dev-harness:lesson ran tests in the wrong folder` | planned v0.3.0 |
| `explore` | You want to try variants against a metric: keep what improves, revert what doesn't. Logs `docs/experiments.md` | `/dev-harness:explore cut p95 latency of /search` | planned v0.4.0 |
| `lens` | Review the work from three angles: user (UX), developer (DX), agent (AX) | `/dev-harness:lens the onboarding flow` | planned v0.4.0 |
| `goal` | Work toward a success check on autopilot, with a turn budget and a checkpoint each step | `/dev-harness:goal all tests in tests/api pass` | planned v0.4.0 |
| `showcase` | Find the most impressive part and turn it into a demo, README section, talking points | `/dev-harness:showcase` | planned v0.5.0 |

## Agents

| Agent | Use it when | Status |
|---|---|---|
| `skeptic` | After a non-trivial change: tries to disprove it. Gets only the goal and the diff; never edits | planned v0.3.0 |
| `architect` | Structure and design trade-offs | planned v0.5.0 |
| `designer` | UI, UX, visual quality | planned v0.5.0 |
| `tester` | Missing tests; checks tests can actually fail | planned v0.5.0 |

## How it works (from v0.2.0)

- Skills and agents live in the plugin and work in every project.
- Strict hooks (block edits on `main`, run checks on stop) will be copied **into** a project only when you choose a profile in `new` or `add`. The plugin itself ships no hooks.
- Safety blocks (force push, reading `.env`, `rm -rf /`) will be on in every profile.
- Local hooks stop mistakes, not deliberate bypass. Use branch protection and required CI on your Git host too.

Source and issues: https://github.com/radeshgovind-2005/claude-harness
