# Progress

Handoff notes so a new session can resume. Newest checkpoint first.

## Checkpoint v0.1.0 — 2026-11-10

### Done
- Marketplace `claude-harness`: `.claude-plugin/marketplace.json`, owner `radeshgovind-2005`.
- Plugin `dev-harness` 0.1.0: `plugins/dev-harness/.claude-plugin/plugin.json`.
- Skill `/dev-harness:help`. It shows the version and lists all skills and agents with their status. It is user-only (`disable-model-invocation`). It pre-approves only `Read(/${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json)`.
- `tests/validate.sh` checks:
  - JSON syntax and manifest consistency; the version lives only in plugin.json
  - no hooks in any form (`hooks/`, `hooks.json`, a plugin.json key, or frontmatter)
  - local `./` sources only, and that every entry was checked
  - closed frontmatter with a description, and an exact-case `SKILL.md`
  - kebab-case names
  - `claude plugin validate --strict` and `--profile directory`
- CI: `.github/workflows/ci.yml` runs validate.sh with `REQUIRE_CLAUDE=1`.
- README, CHANGELOG, LICENSE (MIT), BRIEF.md (amended with the owner fix and the decisions from the docs check).

### Verified
- `bash tests/validate.sh`: 20 passed, 0 failed, 0 skipped. `shellcheck` is clean.
- Each rule fails when its input is broken. 15 mutation cases were caught, including all 6 found by the skeptic.
- With claude missing and `REQUIRE_CLAUDE=1`, the script fails. Without that variable it skips loudly with a warning.
- `claude plugin validate` works with an empty config and no API key, so CI needs no secrets.
- Local marketplace add and install in an isolated `CLAUDE_CONFIG_DIR`. Result: version 0.1.0, 1 skill, 0 hooks, about 27 always-on tokens.
- `claude --plugin-dir … -p "/dev-harness:help"` prints `dev-harness v0.1.0` with no permission denials. `/dev-harness:help lesson` shows only that row.

### Skeptic review
The first verdict was CHANGES REQUESTED. All 5 issues were fixed in `4596b88`:
1. Hooks in plugin.json or frontmatter were not detected. Fixed.
2. A non-string `source` skipped every check silently. Fixed.
3. Unclosed frontmatter passed the local check. Fixed.
4. A wrong-case `skill.md` passed on macOS. Fixed.
5. The help text pointed to skills that haven't shipped. Fixed.

Issue 6, that the GitHub repo doesn't exist yet, is open. See below.

### Not verified
- **Install from GitHub.** `radeshgovind-2005/claude-harness` has not been created or pushed. The README install commands will fail until it is.
- **CI on ubuntu-latest.** It has never run: there is no remote yet.
- **`/dev-harness:help` with an exact skill name.** `help help` printed the full guide instead of one row. This is minor model behaviour, not a layout bug.
- **Windows.** Path handling for the `allowed-tools` rule is untested.
- **Icon.** The plugin directory warns that no icon exists. This is optional and only matters if the plugin is submitted to Anthropic's directory.

### Next
- v0.2.0: `discover`, `new`, three profiles, and guardrail hooks copied into projects from `~/Downloads/claude-harness/.claude/hooks/`. The milestone plan is shown before building.
