# Changelog

All notable changes to the `dev-harness` plugin. Versions match `version` in
`plugins/dev-harness/.claude-plugin/plugin.json`, which is what Claude Code uses
to detect updates.

## 0.1.0 — 2026-11-10

### Added
- Marketplace `claude-harness` (`.claude-plugin/marketplace.json`) listing the `dev-harness` plugin.
- Plugin manifest (`plugins/dev-harness/.claude-plugin/plugin.json`).
- `/dev-harness:help` skill: every skill and agent, when to use it, one example, and its status.
- `tests/validate.sh`: JSON syntax, manifest consistency, layout rules (no hooks in the plugin, kebab-case names), and `claude plugin validate`.
- CI workflow running `tests/validate.sh`.
