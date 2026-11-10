# Changelog

All notable changes to the `dev-harness` plugin. Versions match `version` in
`plugins/dev-harness/.claude-plugin/plugin.json`, which is what Claude Code uses
to detect updates.

## 0.2.0 — 2026-11-10

### Added
- `/dev-harness:discover`: a conversation that infers who the work is for and what matters, reflects it back, proposes 2–3 directions (one bold), and saves `docs/intent.md`. While `docs/intent.md` says `status: discovering`, a skill hook blocks edits to every other file (in the session where discover was invoked).
- `/dev-harness:new`: discover, then the profile (prototype / product / assignment), then scaffolding. Content files are written first and guardrails last, because hooks take effect immediately.
- `scripts/scaffold.sh`: a no-overwrite copier with two phases (`files`, `guardrails`) and `--dry-run`. An existing `.claude/settings.json` is merged (union) only with `--merge-settings`, after the diff is shown.
- Project templates: a `CLAUDE.md` router with the profile's rules rendered in, the routed docs, the guardrail hooks, `.claude/rules/` and the `dev-harness-hooks` CI workflow.
- Profiles: `harness.conf` (`BLOCK_MAIN`, `VERIFY_CMD`), read by the hooks and protected from edits. A missing conf falls back to safe defaults.
- `tests/scaffold-test.sh`: 114 checks, run in CI. The project's `test-hooks.sh` grows from 28 to 58 checks across both `BLOCK_MAIN` settings and the no-conf default.

### Changed
- Hooks from claude-harness.zip: the main/master checks (edits, commits, push to main) now follow `BLOCK_MAIN`. `verify.sh` reads `VERIFY_CMD` from the conf.
- `validate.sh`: ignores `templates/` (it is never loaded), allows frontmatter hooks only for `discover`, and checks that `claude plugin details` reports Hooks (0).

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
