# Changelog

All notable changes to the `dev-harness` plugin. Versions match `version` in
`plugins/dev-harness/.claude-plugin/plugin.json`, which is what Claude Code uses
to detect updates.

## 0.4.0 — 2026-11-10

### Added
- `/dev-harness:explore`: an experiment loop. Agree a metric (a command that prints a number), then one change per variant: `scripts/explore.sh` measures it, decides keep or revert from the number, commits kept variants, restores the tree for reverted ones, and logs every row in `docs/experiments.md`. It stops at the target or after 2 variants in a row with no improvement. It works on an `explore/<slug>` branch and refuses to keep or revert on `main`. 56 tests.
- `/dev-harness:lens`: reviews a target from three angles in fresh context (UX: the person who uses it, DX: the next developer, AX: an AI agent working in the project) with three `dev-harness:lens-reviewer` agents started in one message. It checks the fan-in, merges duplicates, ranks, and changes nothing. `scripts/ax-check.sh` gives the AX reviewer script-checked facts (router length, routed paths exist, hooks executable, placeholders, profile, intent status). 33 tests.
- `/dev-harness:goal`: a goal loop judged by a command, not a model. A Stop hook (`goal-stop.sh`) runs the success check each time Claude tries to finish, sends it back with the failure and asks for a checkpoint in `docs/progress.md`, and ends the loop on success or when the budget of rounds and minutes is used up, each time after one final-report turn. State lives in `~/.claude/dev-harness/goals/<session>.json`. 54 tests.
- `scripts/lib.sh`: `run_limited`, a watchdog that kills a command and its process group (macOS has no `timeout`).

### Changed
- `validate.sh`: the lens reviewer has no edit tools, `goal` may declare a frontmatter hook (state-gated), counts Skills (8), Agents (2), Hooks (0).
- The `docs/experiments.md` template has `Direction` and `Target` lines that `explore.sh` reads.
- CI runs the explore, lens and goal tests.

### Known limits
- **`goal` is not the built-in `/goal`.** The built-in one lets a small model judge the conversation. This one runs your command. Use it when the goal can be a command.
- **No token budget.** Hooks receive no token count and the transcript format is not documented, so only rounds and minutes are enforced. A "round" is one time Claude ends its turn, not one tool call. For headless runs use `--max-budget-usd`.
- **The `goal` hook lives in the session that ran the skill.** After `--continue` or a resume it is not registered again; `goal.sh status` may show a stale active goal and `goal.sh stop` clears it. The hook stays registered after the goal ends but does nothing.
- **`goal` state is not tamper-proof.** It is outside the project, but a shell command can edit it. A damaged state file ends the loop (fail open) with a message.
- **Claude Code ends a turn after 8 consecutive stop-hook blocks with no tool call.** A loop that does real work resets the count.
- **The `lens` reviewers, like the skeptic, have no edit tools but their `Bash` can write.** The skill runs `git status --short` afterwards and reports changes.
- **`explore` trusts the metric command.** It cannot tell a metric that has been gamed from a real gain; the skill forbids changing the measurement, and the report lists what is not verified. Noise needs `--runs`.

## 0.3.0 — 2026-11-10

### Added
- `/dev-harness:add <part>`: add one part to an existing project. Parts: `guardrails`, `reviewer`, `lessons`, `memory`, `workflows`, `rules`, `all`. It reuses `scaffold.sh`, never overwrites, and detects the project's profile from `harness.conf` or `CLAUDE.md`.
- `scaffold.sh files --part NAME` (`memory`, `lessons`, `reviewer`, `workflows`, `rules`). `--profile` is required only for the default and for `memory`. An empty `--part` value, or `--part` with the `guardrails` phase, is an error. The `guardrails` phase now also adds `.claude/settings.local.json` to `.gitignore`.
- `dev-harness:skeptic`, a plugin agent: tries to disprove a change from only the goal and the diff, and reports `STATUS`, issues with `file:line` and a scenario, and `NOT CHECKED`. Its tools are `Read, Grep, Glob, Bash`, so it has no edit tools. `Bash` can still write; see Known limits.
- `/dev-harness:lesson`: records a correction in `docs/lessons.md`, updates a similar lesson instead of duplicating it, tags lessons about discovery `[discover]`, and asks before promoting a rule to `CLAUDE.md`.
- Templates `docs/progress.md` (handoff checkpoints) and `docs/experiments.md` (baseline and variants), routed from the `CLAUDE.md` router and `docs/INDEX.md`.

### Changed
- `discover` reads `[discover]`-tagged lessons first and says which lesson shaped a question.
- The `CLAUDE.md` checklist and `docs/agents/INDEX.md` name `dev-harness:skeptic`; the Self-Update rule points to `/dev-harness:lesson` and to `docs/progress.md`.
- `help` shows `add`, `lesson` and `skeptic` as available.

### Known limits
- The skeptic's "never edits" is only partly enforced. Its tool list removes Edit and Write, but plugin agents cannot restrict `Bash` to read-only commands, so a skeptic could still write through the shell (`echo x > src/a.ts`). The agent is told not to, and in a live test it refused an explicit instruction to. In projects with the guardrails, `guard-bash.sh` and `protect-paths.sh` also run on subagent tool calls, but they guard only hooks, settings, secrets, lockfiles and `main`, not ordinary source files. Test runs can leave caches (for example `__pycache__`). Check `git status` after a review.
- `--part memory` writes a router and `docs/INDEX.md` that point at files owned by `workflows` and `reviewer`. The script prints a `note` naming each missing file and the part that adds it.

## 0.2.0 — 2026-11-10

### Added
- `/dev-harness:discover`: a conversation that infers who the work is for and what matters, reflects it back, proposes 2–3 directions (one bold), and saves `docs/intent.md`. While `docs/intent.md` says `status: discovering`, a skill hook blocks edits to every other file (in the session where discover was invoked).
- `/dev-harness:new`: discover, then the profile (prototype / product / assignment), then scaffolding. Content files are written first and guardrails last, because hooks take effect immediately.
- `scripts/scaffold.sh`: a no-overwrite copier with two phases (`files`, `guardrails`) and `--dry-run`. An existing `.claude/settings.json` is merged (union) only with `--merge-settings`, after the diff is shown.
- Project templates: a `CLAUDE.md` router with the profile's rules rendered in, the routed docs, the guardrail hooks, `.claude/rules/` and the `dev-harness-hooks` CI workflow.
- Profiles: `harness.conf` (`BLOCK_MAIN`, `VERIFY_CMD`), read by the hooks and protected from edits. A missing conf falls back to safe defaults.
- `tests/scaffold-test.sh`: 136 checks, run in CI. The project's `test-hooks.sh` grows from 28 to 138 checks, covering both `BLOCK_MAIN` settings, the no-conf default, odd conf values (CRLF, `true`, spaces) and common command variants.
- Project CI also checks that the hooks are registered in `settings.json` and that a product `harness.conf` keeps `BLOCK_MAIN` on.

### Changed
- Hooks from claude-harness.zip: the main/master checks (edits, commits, push to main) now follow `BLOCK_MAIN`. `verify.sh` reads `VERIFY_CMD` from the conf.
- `validate.sh`: ignores `templates/` (it is never loaded), allows frontmatter hooks only for `discover`, and checks that `claude plugin details` reports Hooks (0).
- Hardened after the skeptic review:
  - The conf parser fails closed: only an explicit `BLOCK_MAIN=0` lifts main protection.
  - Protected paths are normalized: `..`, `//`, symlinks, case.
  - The bash guard also catches `git -C`, `+refspec`, `-uf`, `--force-with-lease`, `-c core.hooksPath`, bare `git push` on main, quoted `.env`, `rm -rf ~/` and `/*`, and `bash <(curl …)`.
  - Shell writes to `.claude/hooks/` or `.claude/settings.json` ask the user first.
  - A settings merge that fails leaves the file untouched.
  - `VERIFY_CMD` is written verbatim.
  - Older hooks that ignore `harness.conf` are reported as FAIL.
  - `validate.sh` checks that the top CHANGELOG version equals `plugin.json`.

## 0.1.0 — 2026-11-10

### Added
- Marketplace `claude-harness` (`.claude-plugin/marketplace.json`) listing the `dev-harness` plugin.
- Plugin manifest (`plugins/dev-harness/.claude-plugin/plugin.json`).
- `/dev-harness:help` skill: every skill and agent, when to use it, one example, and its status.
- `tests/validate.sh`: JSON syntax, manifest consistency, layout rules (no hooks in the plugin, kebab-case names), and `claude plugin validate`.
- CI workflow running `tests/validate.sh` with `REQUIRE_CLAUDE=1`.

### Verified
- 20 validation checks pass; 15 broken-input cases each fail as expected.
- Local marketplace install and `/dev-harness:help` tested. Install from GitHub not yet tested (repo not pushed).
