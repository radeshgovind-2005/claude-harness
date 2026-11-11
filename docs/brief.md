# dev-harness — Build Brief

Give this file to Claude Code before the build prompt. It holds every decision from the planning conversation. If anything here conflicts with current official Claude Code docs, follow the docs and report the conflict.

> **Amended 2026-11-10 (build planning):** the GitHub owner is `radeshgovind-2005` (with a hyphen). The `radeshgovind2005` account does not exist. The install commands below use the corrected owner. See "Decisions after planning" at the end.

## 1. Goal

Build dev-harness: a Claude Code plugin that sets up and runs software projects the way experienced users do. The user installs it once, then in any project runs one command, describes the idea, and gets a full, tested setup. Nothing gets forgotten.

It must work for many kinds of work: a prototype, a proof of concept, an assignment, or a real job. Friends must be able to install and fork it.

- Owner: Radesh Govind (GitHub: radeshgovind-2005)
- Marketplace repo: radeshgovind-2005/claude-harness (public)
- Plugin name: dev-harness (permanent slug, never rename)
- Commands invoke as /dev-harness:<name>
- Scope: Claude Code only (no AGENTS.md support for now)
- License: MIT

Install for any user:

```
/plugin marketplace add radeshgovind-2005/claude-harness
/plugin install dev-harness@claude-harness
```

## 2. Mental model: three layers

| Layer | Who builds it | What it is |
|---|---|---|
| Generic harness | Anthropic | Claude Code: agent loop, tools, permissions, subagents, workflows |
| Practice layer | This plugin | How to work well on any project: intent, memory, guardrails, review, lessons, loops |
| Domain layer | The user, per project | Domain facts, domain checks, domain tools. The plugin teaches how to build it, but does not ship domains |

Build only what stays valuable as models improve: user intent, project facts, real checks. Avoid long instructions on how to code and workarounds for current model weaknesses.

## 3. Core philosophy (shapes every feature)

1. Intent first. Building is the easy part. The value is in understanding the context, who the work is for, what they care about, and where to push. Discover before building.
2. Reflect before acting. Show your understanding back to the user before you build. The user is not always precise. Interpret the intention, not only the literal words.
3. Brainstorm together. Propose 2 to 3 directions, including one bold option. The user picks and adjusts.
4. Bold, but measured. Try a variant, measure it, keep what improves, revert what gets worse, and try again. Never commit to one idea without evaluation.
5. Code enforces, text advises. A rule that must never break is a hook, not a line in CLAUDE.md.
6. Never grade your own work. A fresh-context reviewer checks the work.
7. Anchor on real signals. A test that ran beats an agent that agrees. Agents checking agents are worthless without one check that cannot be argued with.
8. Every mistake becomes a lesson. Then prune lessons that stop helping. This includes lessons about the discovery process itself.
9. Fail loud. Report skipped steps, missing results, and uncertainty. Never say "done" for unverified work.

## 4. Plugin standards (verify against official docs)

Read first: https://code.claude.com/docs/en/plugins-reference, the marketplace docs, and https://code.claude.com/docs/en/workflows.

- Marketplace manifest: .claude-plugin/marketplace.json at repo root.
- Plugin manifest: plugins/dev-harness/.claude-plugin/plugin.json.
- Component folders (skills/, agents/, hooks/) sit at the plugin root, never inside .claude-plugin/.
- Prefer skills/<name>/SKILL.md over the legacy commands/ folder.
- Use kebab-case for all files and folders.
- Plugin hooks go in hooks/hooks.json, same format as settings.json hooks.
- Test locally with claude --plugin-dir <path> before every tag.

Important design decision: a plugin stays on in every project where it is enabled. So:

| Type | Lives in |
|---|---|
| Skills, agents (reusable everywhere) | The plugin |
| Strict hooks and project settings | Copied INTO each project by new or add, based on the chosen profile |

The plugin itself ships only safe, universal hooks (if any). Strict rules like "block edits on main" must never fire in projects that did not opt in.

## 5. Skills (commands)

| Skill | Purpose | Key behavior |
|---|---|---|
| help | Show how to use everything | Lists each skill, when to use it, one example each |
| discover | Understand the project before building | See section 6. No code allowed during discover |
| new | Full project setup | Runs discover, asks the profile, scaffolds files into the project. Never overwrites |
| add <part> | Add one part to an existing project | Parts: guardrails, reviewer, lessons, memory, workflows, rules, all |
| explore | Experiment loop | Define a metric, try a variant, measure, keep or revert, log to docs/experiments.md. Stop on success or 2 rounds with no progress |
| lens | Multi-angle review | Reviews the work for UX (user), DX (developer), and AX (agent experience) |
| goal | Goal loop / autopilot | Works toward a stated success check, with a turn and token budget. Checkpoint report each step. Stops near budget |
| showcase | Find what to show off | Finds the most impressive, valuable part. Proposes a demo, README section, and talking points that match docs/intent.md |
| lesson | Self-update loop | Records a correction in docs/lessons.md. Updates a similar lesson instead of duplicating. Proposes moving universal lessons to CLAUDE.md, asks first |

## 6. The discover skill (most important feature)

Discover is a conversation, not a fixed questionnaire. The user often does not know yet what matters most. Explore it together.

1. Context dump. The user gives anything: idea, paper, brief, assignment text, links, files.
2. Infer. Claude works out: who the user is, who receives the work, their profile and interests, what is being delivered, the potential, and the areas worth pushing.
3. Reflect back. "Here is what I think this is about." The user corrects it. Ask only what is still missing.
4. Brainstorm. 2 to 3 directions with trade-offs, including one bold option.
5. Decide. The user picks and adjusts style, focus, and what to push hardest.
6. Save. Write docs/intent.md. Every later session reads it.

When discover misses something, /lesson records it, so the next discover asks better questions. Optional: a hook that blocks code edits while discover runs (idea from the brainstorm-mode plugin).

## 7. Agents

| Agent | Job | Rule |
|---|---|---|
| skeptic | Try to disprove that a change is correct | Fresh context. Gets only the goal and the diff. Never edits. Fixed report: STATUS, issues with file:line and scenario, NOT CHECKED |
| architect | Structure and design trade-offs | Fixed output format |
| designer | UI, UX, visual quality | Fixed output format |
| tester | Find missing tests, check that tests can fail | Fixed output format |

Roles as skills or agents is an idea borrowed from multi-agent "studio" repos. Keep roles few and sharp.

## 8. Memory files (written into each project)

| File | Purpose |
|---|---|
| CLAUDE.md | Router, under 100 lines: critical rules, working principles, commands, routing table, verification checklist, self-update |
| docs/intent.md | Output of discover: who, why, what matters, chosen direction |
| docs/lessons.md | Past mistakes and the rule each created. Newest first |
| docs/progress.md | Handoff notes so a new session can resume: done, verified, not verified, next |
| docs/experiments.md | Log from the explore loop: variant, metric, result, kept or reverted |
| docs/INDEX.md, architecture.md, conventions.md, workflow.md, agents/INDEX.md | Routed docs, read only when needed |

Router rule: link routed docs with backtick paths, not @ imports. @ imports load at every session start and defeat the router.

## 9. Working principles (go into each project's CLAUDE.md)

1. Think first. State assumptions. If unclear, ask. Do not guess.
2. Keep it simple. Minimum code for the task. No speculative features. (Prototype profile: relaxed.)
3. Change surgically. Read the file, callers, and shared utilities first. Change only what the task needs. Match existing conventions.
4. Surface conflicts. If two patterns disagree, do not blend them. Pick one, say why, flag the other.
5. Test intent. A test must fail if the business logic breaks.
6. Fail loud. Report skipped steps, missing results, uncertainty.

Source: the Karpathy-style 4 rules plus selected additions from a community 12-rule version. Rejected from that version: token budgets written as text (Claude cannot count its own tokens; enforce budgets outside the session) and "use the model only for judgment" (app architecture, not coding behavior).

## 10. Guardrails (already built and tested in claude-harness.zip)

| File | Event | Blocks |
|---|---|---|
| protect-paths.sh | PreToolUse Edit/Write | .env* (except examples), keys, lockfiles, .claude/hooks/, .claude/settings.json, any edit on main/master |
| guard-bash.sh | PreToolUse Bash | --no-verify, force push, push to main, rm -rf /, curl \| sh, reading .env, changing hooksPath, commit on main. Asks before reset --hard, git clean -f, DROP/TRUNCATE |
| format.sh | PostToolUse | Never blocks. Runs the project formatter if present |
| verify.sh | Stop | Runs VERIFY_CMD. On failure, exit 2 so Claude must fix. Loop guard via stop_hook_active |
| test-hooks.sh | Manual / CI | 28 checks, all passing |

Also built: settings.json permissions (allow / ask / deny), install.sh (never overwrites), CI workflow, skeptic agent, /lesson command, docs templates, README. Reuse these files; adapt paths to the plugin layout.

Local hooks stop mistakes, not deliberate bypass. Recommend branch protection and required CI on the Git host.

## 11. Profiles (chosen in new)

| Setting | prototype | product | assignment |
|---|---|---|---|
| Edits on main | Allowed | Blocked | Allowed |
| verify.sh on stop | Off | On | On (tests) |
| Skeptic review | Optional | Required | Recommended |
| Ask before git push | No | Yes | No |
| Plan mode for >3 files | Suggested | Required | Suggested |
| Explain steps for learning | No | No | Yes |
| Force push, .env, rm -rf / | Blocked | Blocked | Blocked |

Safety blocks stay in every profile.

## 12. Ideas borrowed from the ecosystem

| Idea | Source | Use in dev-harness |
|---|---|---|
| Brainstorm before build | Superpowers plugin (very popular). Do not rebuild it; dev-harness differentiates on intent and discovery | discover |
| Experiment loop | Karpathy's auto-research | explore |
| Autonomous loop until done | Ralph Loop plugin | goal, with a budget |
| Hook-enforced brainstorm | brainstorm-mode plugin | Optional discover lock |
| Goal loop, persistent memory, token-efficiency, roles as skills | Chinese open-source harness work (e.g. shareAI-lab/learn-claude-code), memory repos like claude-mem | goal, progress.md, budget awareness, role agents |
| Fake-edge test, fresh verifier, fan-in count, anchors | "Graph engineering" article | docs/workflow.md, skeptic, fail loud, verify.sh |
| Update CLAUDE.md after every mistake | Boris Cherny and the Claude Code team | lesson |
| Dynamic workflows | Claude Code docs. Trigger: "use a workflow" or ultracode (the old workflow keyword is outdated) | docs/agents/first-workflow.md |

## 13. Corrections already made (do not repeat these mistakes)

| Wrong idea seen online | Correct approach |
|---|---|
| Prompts can "physically forbid" actions | Only hooks, settings deny rules, and server-side CI enforce anything |
| An LLM gatekeeper before every command | Deterministic scripts for path and command checks. Faster and reliable |
| Agent-signed receipts prove work | If the agent can sign, it is still self-approval. Use CI required checks |
| Local pre-commit hook is enough | Claude can use --no-verify. Block it in a hook, and enforce on the server |
| "95% deterministic convergence" and similar metrics | Made-up. LLM output is not deterministic. Measure real outcomes |
| Auto-write every lesson into CLAUDE.md | Causes bloat. Write to docs/lessons.md; ask before promoting |
| Role-play openers ("You are a Lead Architect") | Add nothing. Use concrete imperative rules |
| A contract JSON for every task | Too heavy for small fixes. Scale process to task size |
| Long CLAUDE.md (200+ lines) | Router under 100 lines; details in routed docs and path-scoped rules |
| Strict hooks inside the plugin | They fire in every project. Copy them into opted-in projects only |

## 14. Milestones (one annotated git tag each)

| Tag | Content |
|---|---|
| v0.1.0 | Marketplace + plugin skeleton + help |
| v0.2.0 | discover, new, profiles, guardrail hooks copied into projects |
| v0.3.0 | add, skeptic, lesson, memory files |
| v0.4.0 | explore, lens, goal |
| v0.5.0 | showcase, role agents |
| v1.0.0 | README, docs, examples, full test pass, polish |

Per milestone: plan, build, test (hook tests, JSON validation, load with --plugin-dir, try each new skill), skeptic review of the diff, update CHANGELOG.md, commit, tag, write a checkpoint in docs/progress.md.

Rules: work on a branch, small commits, fail loud. Ask before pushing to GitHub, creating releases, or deleting files.

## 15. How to start in Claude Code

1. Unzip claude-harness.zip into an empty folder. Save this brief there as BRIEF.md.
2. Open Claude Code in that folder. Use plan mode.
3. Paste: "Read BRIEF.md fully, then the official plugin docs. Build dev-harness exactly as the brief says, milestone by milestone, v0.1.0 to v1.0.0. Show me the v0.1.0 plan first."
4. Approve the plan. Let it run. Review each checkpoint and tag.

## Decisions after planning (2026-11-10)

Checked against the official plugin docs:

1. **Owner.** `radeshgovind-2005`, not `radeshgovind2005`, which does not exist.
2. **Versions.** Claude Code resolves plugin versions from the `version` field in `plugin.json`, not from git tags. Each milestone bumps `version` in `plugin.json` only, not in the marketplace entry. Annotated `vX.Y.Z` tags are kept for history.
3. **Plugin agents.** They ignore `hooks` and `permissionMode` in frontmatter, so the skeptic's "never edits" rule is enforced through its `tools` list.
4. **Scripts.** Skills call bundled scripts with `bash "${CLAUDE_PLUGIN_ROOT}/scripts/..."`. They do not use `` !`cmd` `` injection, because a setting can disable it.
5. **Reserved names.** Plugin names starting with `claude-` are reserved. The plugin is `dev-harness`, so that rule doesn't apply. The marketplace name `claude-harness` is checked with `claude plugin validate`.
6. **Guardrail sources.** The zip's files live outside the repo, at `~/Downloads/claude-harness/`. From v0.2.0 they are copied into `plugins/dev-harness/templates/`.

## 16. Stateful work: task cards (added 2026-11-11, v1.1.0)

State lives in files, not in the conversation. A session is disposable; a task card is not. Any session or person can pick up one card with a small, clean context, and long work prefers handoff, `/clear` and resume over compaction.

| Piece | What it is | Enforced by |
|---|---|---|
| Task card `docs/tasks/NNN-slug.md` | Goal, Done when (a real check), Scope (globs), Read first (3-5 files), Decisions (decision and reason), Status (open, in-progress, blocked, done), Verified / Not verified, Next, Owner, Depends | `tasks.sh check` (fields, statuses, dependencies, INDEX) |
| `docs/tasks/INDEX.md` | one row per card: id, title, status, owner, depends | written by `tasks.sh index`; `check` fails on drift |
| Not parallel | two not-done cards whose scopes overlap with no dependency between them | `tasks.sh overlap` (glob intersection on patterns, not files) |
| Active card | per worktree, in a gitignored `.claude/active-task` | `tasks.sh active` |
| One worktree per card | `git worktree` plus branch `task/<id>` | `tasks.sh worktree` refuses an overlap or an unfinished dependency |
| `split`, `handoff`, `resume` | break a goal into cards; write the state into the card before `/clear`; load only what one card needs | skills (text) calling the script (code) |
| SessionStart hook | injects the active card and the newest 5 lessons | `task-context.sh`, copied into projects with guardrails |
| PreCompact hook | tells the compaction to keep the card's goal, decisions and status, and appends a timestamped note with a git snapshot | `task-compact.sh`; it never blocks compaction |

Checked against the hooks docs: PreCompact stdout becomes instructions for the compaction summary, and exit 2 blocks compaction (so the hook always exits 0). A Stop hook cannot remind Claude without continuing the turn (`additionalContext` continues the conversation; `systemMessage` reaches only the user), so there is no Stop reminder: the "update your card" rule is text in the template `CLAUDE.md`.

## 17. Self-evolving harness: forge, promote, packs (added 2026-11-11, v1.2.0)

The template is only the starting point. As a project grows, the harness proposes its own new parts. It is open to new ideas, but every part follows one strict form; soft, half-finished parts are not allowed, and code holds the bar.

| The need | Part |
|---|---|
| A rule that must never break | hook |
| A repeatable procedure or loop | skill |
| Independent judgment or review | agent (fresh context, read-only) |
| Facts for one folder or file type | path-scoped rule |
| A one-time task | nothing |

| Piece | What it is | Enforced by |
|---|---|---|
| Part spec (`skills/forge/part-spec.md`) | Purpose, Which type and why, Trigger, Inputs and outputs, Method or loop, Unacceptable, Success check, Tests, Budget; frontmatter `name`, `type`, `status` (experimental, proven), `uses` | `forge.sh check`: every field filled, files fit the type, tests pass, and a test fails when the part's files are emptied |
| `forge` skill | proposes a part (from discover, a lesson seen twice, a misfiring hook, or a request), writes it in `.claude/forge/<name>/` after a yes, checks it, installs after a second yes; fixes a hook test-first | the yes is the user's; `install` is not pre-approved and `guard-bash.sh` asks |
| Registry `docs/parts.md` | part, type, status, uses, installed, spec link | written by `forge.sh`; `list` fails on drift |
| `promote` skill | a proven part (3 real uses) goes to a local marketplace clone on `promote/<part>`, generalized, with its tests; a PR only after a yes | `forge.sh promote` refuses an unproven part, a dirty clone, an existing branch |
| `dev-harness-perf` | a second plugin and the reference example: `perf-loop` (skill), `profiler` (agent), `perf-guard` (hook part), each with a filled spec that passes `forge.sh check` | `tests/perf-test.sh`; `explore.sh` (Runs, Noise, Correctness, Evidence) |

Checked against the docs: a plugin can depend on another (`dependencies`), and a link inside a plugin that points elsewhere in the same marketplace is copied into the cache on install, so the pack reuses `explore.sh` instead of duplicating it (a local-folder marketplace skips such links).

