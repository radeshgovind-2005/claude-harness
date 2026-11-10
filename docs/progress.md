# Progress

Handoff notes so a new session can resume. Newest checkpoint first.

## Checkpoint v0.3.0 — 2026-11-10

### Done
- `/dev-harness:add <part>` (guardrails, reviewer, lessons, memory, workflows, rules, all). It reuses `scaffold.sh`, which gained `files --part NAME`; `--profile` is required only for the default and for `memory`. `all` is `files` then `guardrails` last, ordered by the skill.
- `dev-harness:skeptic`, a plugin agent with `tools: Read, Grep, Glob, Bash`.
- `/dev-harness:lesson`: updates a similar lesson, tags discovery lessons `[discover]`, asks before promoting. `discover` step 0 reads `[discover]` lessons first.
- Templates `docs/progress.md` and `docs/experiments.md`, routed from the `CLAUDE.md` router and `docs/INDEX.md`. The checklist names `dev-harness:skeptic`.
- Version 0.3.0. `help` shows `add`, `lesson` and `skeptic` as available.

### Verified
- `tests/validate.sh` 37/37 (new: agent tool checks, help-versus-reality checks, Skills (5) / Agents (1) / Hooks (0) from `claude plugin details`). `tests/scaffold-test.sh` 192/192 (new: each part writes exactly its file set, second runs only skip, `all` parts + guardrails equal `files` + guardrails, router and `INDEX.md` routing). shellcheck is clean at warning level.
- Mutation checks: each of 15 injected bugs made a test fail (`--part` ignored, profile requirement dropped, overwrite guard removed, `.gitignore` line dropped, wrong file owner, stale version text, skeptic unnamed, `[discover]` tag removed, edit tool or `permissionMode` added to the skeptic, missing tools list, CHANGELOG mismatch, a ghost or missing skill in `help`). In the validate mutants the `--profile directory` check also fails, because the copy has no `.git` and so no README; the baseline copy fails it the same way.
- Live headless runs with `--plugin-dir`:
  - `add reviewer` wrote only `docs/agents/INDEX.md`.
  - `add all --profile product` on `main` stopped before writing, because `git switch` is not allowed to the skill. On a prepared branch it wrote the full set with 138/138 hook tests, `PROFILE=product`, `BLOCK_MAIN=1`, and `VERIFY_CMD` from `package.json`.
  - `lesson` added a new entry, then updated a near-duplicate in place (one entry), and left `CLAUDE.md` unchanged. A `[discover]` lesson was tagged correctly.
  - `skeptic` reported a planted off-by-one at `calc.py:5` with a failing scenario and `CHANGES REQUESTED`. It approved a correct diff with no invented issues. Told to fix the bug with `sed -i` (allowed), it refused and the file was unchanged.

### Skeptic review
A fresh-context reviewer got the goal and `git diff main..build/v0.3.0`. Its verdict was CHANGES REQUESTED, with 6 issues (none high). It also reran `validate.sh` 37/37 and `scaffold-test.sh` 185/185 (before the fixes below; 192/192 after) and found no defects in overwrite safety, dry run, second runs, bash 3.2 compatibility, `.gitignore` handling, or `all` equals `new`.
- **Fixed:**
  - `--part memory` wrote a router that points at files owned by `workflows` and `reviewer`. The script now prints a `note` naming each missing file and the part that adds it, the `add` skill reports it, and the README memory row no longer claims `intent`.
  - An empty `--part ""` meant "all parts". It is now rejected.
  - Two weak test assertions: the `docs/INDEX.md` check could pass on `progress.md` alone, and the stale-version check passed when a file was missing.
- **Documented, not fixed:**
  - The skeptic's "never edits" is only partly enforced (`Bash` can write, and `guard-bash.sh` guards only protected paths). The wording was corrected in the CHANGELOG, README, help and `agents/INDEX.md`.
  - The guardrails phase now adds a `skip .gitignore` line to `new`'s output. It was already in the CHANGELOG.
- **Not checked by the reviewer:** live skill behaviour, and that `all` writes guardrails last (skill text only, no test).

### Not verified
- **Interactive prompts.** In headless mode `AskUserQuestion` cannot be answered, so "asks before promoting to `CLAUDE.md`" is shown only as "did not edit `CLAUDE.md`". For a universal rule the model chose not to promote because it duplicated a checklist line, instead of asking.
- **The skeptic's "never edits" is not enforced.** `tools` removes Edit and Write but not shell writes. The refusal above comes from the agent's instructions. Test runs can create files (`__pycache__` appeared once). In projects with the guardrails, `guard-bash.sh` and `protect-paths.sh` also fire on subagent tool calls (per the docs; not tested live), but they guard only protected paths, not source files.
- **`discover` actually reading a `[discover]` lesson in a live run.** Only the instruction text and the tag consistency are tested.
- **`CLAUDE.md` placeholder filling by `add` in headless mode.** The `Edit` needs approval, so the skill reported the placeholders as unfilled.
- **CI on ubuntu and an install from GitHub for 0.3.0.** Neither has run: nothing is pushed.
- Carried over: a real interactive discover conversation; the assignment profile end to end in a live session; Windows and CRLF checkouts of the hook scripts.

### Next
- v0.4.0: `explore`, `lens`, `goal`.

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
- **CI on ubuntu** (run on `9c958e4`): `validate.sh` 27/27 and `scaffold-test.sh` 136/136 passed.
- **Installing v0.2.0 from GitHub:** gave version 0.2.0, 3 skills, Hooks (0). Scaffolding from the install cache passed the project hook tests, 138/138.

### Skeptic review
The verdict was CHANGES REQUESTED, with 15 issues (3 high). All were fixed or documented in `415f04f`:
- **Fixed:** the merge emptying settings.json; awk `-v` escapes that could inject `BLOCK_MAIN=0`; the missing version bump; the conf failing open; shell writes to the config; path normalization; old hooks silently kept; .gitignore glue; common command variants; the option-value hang; the dangling symlink; chmod on skipped files; weak project CI; missing tests.
- **Documented, not fixed:** the discover lock covers file-edit tools only, not shell commands, and lives only in the session where discover ran.

### Not verified
- **A real interactive discover conversation with the user.** Recommended next, on a real idea.
- **`--continue` or resume of a discover session.** The lock is not re-registered, so it isn't enforced there. This is documented in the skill.
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
