# Changelog

All notable changes to the `dev-harness` plugin. Versions match `version` in
`plugins/dev-harness/.claude-plugin/plugin.json`, which is what Claude Code uses
to detect updates.

## 0.3.0 — 2026-11-10

### Added
- `/dev-harness:add <part>`: add one part to an existing project. Parts: `guardrails`, `reviewer`, `lessons`, `memory`, `workflows`, `rules`, `all`. It reuses `scaffold.sh`, never overwrites, and detects the project's profile from `harness.conf` or `CLAUDE.md`.
- `scaffold.sh files --part NAME` (`memory`, `lessons`, `reviewer`, `workflows`, `rules`). `--profile` is required only for the default and for `memory`. `--part` with the `guardrails` phase is an error. The `guardrails` phase now also adds `.claude/settings.local.json` to `.gitignore`.
- `dev-harness:skeptic`, a plugin agent: tries to disprove a change from only the goal and the diff, and reports `STATUS`, issues with `file:line` and a scenario, and `NOT CHECKED`. Its tools are `Read, Grep, Glob, Bash`, so it has no edit tools. `Bash` can still write; see Known limits.
- `/dev-harness:lesson`: records a correction in `docs/lessons.md`, updates a similar lesson instead of duplicating it, tags lessons about discovery `[discover]`, and asks before promoting a rule to `CLAUDE.md`.
- Templates `docs/progress.md` (handoff checkpoints) and `docs/experiments.md` (baseline and variants), routed from the `CLAUDE.md` router and `docs/INDEX.md`.

### Changed
- `discover` reads `[discover]`-tagged lessons first and says which lesson shaped a question.
- The `CLAUDE.md` checklist and `docs/agents/INDEX.md` name `dev-harness:skeptic`; the Self-Update rule points to `/dev-harness:lesson` and to `docs/progress.md`.
- `help` shows `add`, `lesson` and `skeptic` as available.

### Known limits
- The skeptic's "never edits" is enforced by its tool list, which removes Edit and Write. Plugin agents cannot restrict `Bash` to read-only commands, so a skeptic could still write through the shell. The agent is told not to. In projects with the guardrails, the project's `guard-bash.sh` and `protect-paths.sh` also run on subagent tool calls.

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
