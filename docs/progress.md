# Progress

Handoff notes so a new session can resume. Newest checkpoint first.

## Checkpoint v0.2.0 — 2026-11-10

### Done
- `/dev-harness:discover`: a conversation that writes `docs/intent.md` from a template. A state-gated skill hook (`discover-lock.sh`) blocks edits to every other file while the status is `discovering`.
- `/dev-harness:new`: discover, then profile, then git checks, then `VERIFY_CMD`, then the `files` phase (with CLAUDE.md placeholders filled), then the `guardrails` phase last (dry run first), then a report.
- `scripts/scaffold.sh` (no overwrite, dry run, opt-in union merge of settings.json), the 3 profiles, and the project templates (CLAUDE.md router, docs, hooks, rules, CI).
- Hooks from the zip now follow `harness.conf`. They were hardened after the skeptic review; see the CHANGELOG.
- Version 0.2.0. `validate.sh` checks that the CHANGELOG matches `plugin.json`.

### Verified
- `tests/validate.sh` 27/27, `tests/scaffold-test.sh` 136/136, project `test-hooks.sh` 138/138. shellcheck reports no warnings.
- Mutation checks: each of 13 injected bugs made a test fail. That includes restoring the 3 old bugs the skeptic found (awk escapes, merge emptying settings.json, .gitignore glue).
- Live headless runs with `--plugin-dir`:
  - **discover:** it reflected back with guesses labelled and asked 3 questions. It wrote only `docs/intent.md` (`status: discovering`). In the same process, a `Write` to `notes/x.md` was **blocked** by the lock.
  - **new, product profile:** it switched to `chore/dev-harness-setup` and filled CLAUDE.md. Hook tests passed. In the same session, after `git switch main`, a `Write` was **blocked**, so the hooks are live mid-session.
  - **new, prototype profile** (hardened hooks): 138/138 hook tests. A `Write` on main was allowed and `git push --force` was blocked.
  - **Stop hook:** a failing `VERIFY_CMD` blocked the first stop and sent the error back. Claude explained it without editing `harness.conf`, and the second stop passed (`stop_hook_active` works). The run took 29 s.
- `claude plugin details`: Skills (3), Hooks (0). Template dotfiles and exec bits survive into the install cache.

### Skeptic review
The verdict was CHANGES REQUESTED, with 15 issues (3 high). All were fixed or documented in `415f04f`:
- **Fixed:** the merge emptying settings.json; awk `-v` escapes that could inject `BLOCK_MAIN=0`; the missing version bump; the conf failing open; shell writes to the config; path normalization; old hooks silently kept; .gitignore glue; common command variants; the option-value hang; the dangling symlink; chmod on skipped files; weak project CI; missing tests.
- **Documented, not fixed:** the discover lock covers file-edit tools only, not shell commands, and lives only in the session where discover ran.

### Not verified
- **A real interactive discover conversation with the user.** Recommended next, on a real idea.
- **`--continue` or resume of a discover session.** The lock is not re-registered, so it isn't enforced there. This is documented in the skill.
- **CI on ubuntu for the new tests.** It runs on push.
- **Installing v0.2.0 from GitHub.** It isn't pushed yet.
- **The assignment profile end to end in a live session.** It is covered by the scaffold tests only.
- **Windows and CRLF checkouts of the hook scripts themselves.** The conf parsing is CRLF-safe.

### Next
- v0.3.0: `add <part>`, the `skeptic` agent (plugin agent), `lesson` as a skill, and `progress.md` and `experiments.md` templates.

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

Issue 6, that the GitHub repo did not exist yet, is resolved: the repo was created and pushed.

### Verified after push (2026-11-10)
- Installing from GitHub works in an isolated config. `claude plugin marketplace add radeshgovind-2005/claude-harness` and `claude plugin install dev-harness@claude-harness` give version 0.1.0 with the `help` skill.
- CI on ubuntu-latest passes 20 of 20 checks with `REQUIRE_CLAUDE=1`, so `claude plugin validate` ran.

### Not verified
- **`/dev-harness:help` with an exact skill name.** `help help` printed the full guide instead of one row. This is minor model behaviour, not a layout bug.
- **Windows.** Path handling for the `allowed-tools` rule is untested.
- **Icon.** The plugin directory warns that no icon exists. This is optional and only matters if the plugin is submitted to Anthropic's directory.

### Next
- v0.2.0: `discover`, `new`, three profiles, and guardrail hooks copied into projects from `~/Downloads/claude-harness/.claude/hooks/`. The milestone plan is shown before building.
