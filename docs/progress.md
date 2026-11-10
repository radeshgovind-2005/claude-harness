# Progress

Handoff notes so a new session can resume. Newest checkpoint first.

## Checkpoint v0.4.0 — 2026-11-10

### Done
- `/dev-harness:explore` + `scripts/explore.sh`: a referee for the experiment loop. It measures a metric command (median of N runs), keeps a variant only if it beats the best (commit), otherwise restores the tree, logs every row in `docs/experiments.md`, and stops at the target or after 2 variants in a row without gain. It works on an `explore/<slug>` branch and refuses a detached HEAD. `revert` saves what it discards under `refs/explore/` and `.git/explore-backups/`.
- `/dev-harness:lens` + `agents/lens-reviewer.md` + `scripts/ax-check.sh`: UX, DX and AX reviews by three fresh-context agents started in one message, with script-checked facts for AX, a fan-in count, and a `git status -uall` comparison afterwards.
- `/dev-harness:goal` + `scripts/goal.sh` + `skills/goal/goal-stop.sh`: a goal loop judged by a command's exit code. Stop hook, state-gated per session, budget of rounds and minutes (no tokens: hooks get no token count), one final-report turn after success or budget. State in `~/.claude/dev-harness/goals/`.
- `scripts/lib.sh` (`run_limited`, `last_number`): a polling runner with a process-group kill, no leftover sleep, and a 20 KB output cap.
- Version 0.4.0, `help`, README ("goal vs the built-in /goal"), CHANGELOG, CI runs the three new test files.
- Decisions made with you: `goal` is command-judged (not a helper for the built-in `/goal`); the budget is rounds + minutes.
- Found by `lens` on a real scaffold, fixed: `guard-bash.sh` asked for confirmation on `cat .claude/hooks/x 2>/dev/null`. See the CHANGELOG for the wider verb list that came with it.

### Verified
- `validate.sh` 44/44 (Skills (8), Agents (2), Hooks (0); the lens reviewer has no edit tools; `goal` is the only other skill with a frontmatter hook), `scaffold-test.sh` 192/192, `explore-test.sh` 83, `lens-test.sh` 36, `goal-test.sh` 60, project `test-hooks.sh` 172 per scaffold. shellcheck clean at warning level.
- Mutation checks: 35 mutants before the review, 30 more for the review fixes, each made a test fail. Survivors found and fixed: a non-numeric `keep` caught only by a later guard (now asserts the message), a detached-HEAD guard hidden by the branch guard (now asserts the message), the `run_limited` output cap (now tested directly), and a weak `2>&1` hook test. One mutant (a `sleep` left behind) makes the suite hang instead of fail, which is the bug it simulates. In the validate mutants the `--profile directory` check fails in any copy without `.git`; the baseline copy fails it too.
- Spikes: a skill-frontmatter Stop hook fires in `-p` mode; the hook's `session_id` equals the skill's `${CLAUDE_SESSION_ID}`; `CLAUDE_PLUGIN_DATA` is substituted in skill text but **not set in the hook's environment** under `--plugin-dir`, so goal state lives under `$HOME/.claude/dev-harness`; a plugin agent can be spawned by a skill without `Agent` in `allowed-tools`.
- Live headless runs with `--plugin-dir`, twice (before and after the review fixes):
  - **explore:** baseline 11; a bold variant (`threads=8`) scored 4 and was reverted; `threads=4` scored 20 and was kept; it stopped at the target. The final report named the branch and commit correctly.
  - **goal, met:** 3 rounds, a checkpoint in `docs/progress.md` each round, one final report; state `finished/met`; the session then ended (no endless loop).
  - **goal, budget:** an impossible check with 2 rounds stopped after 2 rounds, the report said the goal was **not** met, `check.sh` was untouched, state `finished/budget`.
  - **lens:** 3 of 3 reviewers returned in the fixed format, with `file:line` evidence, on a scaffolded project; `git status` was unchanged.

### Skeptic review
A fresh-context reviewer got the goal and `git diff main..build/v0.4.0`. Its verdict was CHANGES REQUESTED, with 14 issues (1 high, 5 medium, 8 low). It also confirmed that the goal hook is state-gated and cannot loop, that revert keeps ignored files, staged files and nested folders, and that the plugin ships no always-on hooks.
- **Fixed:**
  - High: a user file such as `docs/experiments.md.bak` hid from the clean-tree check, and `revert` then deleted it. The check now compares the exact path, and `revert` backs up what it discards.
  - `awk -v` turned `\n` and `\t` in variant text into line breaks, corrupting the log and the best value. Rows are now passed via `ENVIRON`.
  - A failing commit left a `kept` row and a moved best value. The row is now rolled back and `keep` can be retried.
  - `last_number` misread `.5`, `1,234` and dates. It reads leading-dot numbers, refuses thousands separators and notes lines with several numbers.
  - My `/dev/null` strip in `guard-bash.sh` exposed that the verb list never covered `sed -i.bak`, `curl -o`, `patch`, `rsync`, `git checkout` and inline interpreters. All now ask. The docs say it is a best-effort list.
  - `ax-check` false FAILs (globs, `#anchor`, `:line`, `settings.local.json`) and a PASS for an invalid `settings.json`.
  - The watchdog left a `sleep` process per run. The runner now polls.
  - A check printing one huge line or escape codes flooded the feedback. It is capped at 4000 bytes and stripped.
  - A vanished project folder ran the check elsewhere. The hook now fails open with a message.
  - `explore` branched only from `main` and committed on a detached HEAD. It now branches from any non-`explore/` branch and refuses a detached HEAD.
  - `allowed-tools` pre-approved installing a check or metric command. `goal.sh start` and the Metric `Edit` now prompt, which shows the exact command.
  - A test count in the CHANGELOG was wrong.
- **Documented, not fixed:** two simultaneous Stop events can count as one round (bounded); a check that detaches with `setsid` escapes the process-group kill.
- **Not checked by the reviewer:** live behaviour (covered above), the built-in `/goal` claims, real lens runs, Windows and CRLF.

### Verified after the push (2026-11-10)
- **Installing v0.4.0 from GitHub** (isolated config): version 0.4.0, Skills (8), Agents (2), Hooks (0), executable bits kept (`goal-stop.sh`, `explore.sh`, `goal.sh`, `ax-check.sh`). Scaffolding from the install cache passed the project hook tests 172/172; `ax-check.sh` and `explore.sh start` ran from the cache.
- **CI on `db84e15` was partly red.** `validate.sh` 44/44 and `scaffold-test.sh` 192/192 passed on ubuntu. `explore-test.sh` failed 14 of 83, all in `keep`: the runner has no git identity, so `git commit` failed. This is a test-environment gap, not a plugin bug (`explore.sh` correctly does not invent an identity; on a machine without one, `keep` fails loudly and rolls its log row back). Reproduced locally with `user.useConfigOnly=true` (69/83), fixed by giving the test an identity (83/83). The fix is test-only, so the `v0.4.0` tag was not moved. **The tag points at a commit whose CI is red for that test file.**
- **CI on `cd69265` (the test-only fix) is green on ubuntu** (run 42846031175, 2 m 54 s): `validate.sh`, `scaffold-test.sh`, `explore-test.sh`, `lens-test.sh` and `goal-test.sh` all passed. The `lens` and `goal` tests ran on ubuntu for the first time. `v0.4.0` still points at the red commit `db84e15`; the fix is on `main` only.

### Not verified
- **The built-in `/goal` claims in the README** come from the docs research, not from running it.
- **`--continue`/resume of a goal session.** The hook is not re-registered (documented); the stale-state path is covered by unit tests only.
- **The 8-block cap** ("Claude Code ends a turn after 8 consecutive stop-hook blocks") is from the docs and was not provoked.
- **The user's confirmation prompts.** In headless mode the confirmation of the check or metric command, and the permission prompt for `goal.sh start` / the Metric `Edit`, cannot be answered; the runs passed the confirmation in the prompt and `--allowedTools`.
- **Reviewers obeying "do not write".** `lens` compares `git status -uall` before and after; in the live run nothing changed, but `Bash` can write.
- Carried over: a real interactive discover conversation; the assignment profile end to end in a live session; Windows and CRLF.

### Next
- v0.5.0: `showcase`, and the `architect`, `designer` and `tester` agents.

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

- **CI on ubuntu** (run on `bdca793`, after the push): `validate.sh` 37/37 and `scaffold-test.sh` 192/192 passed.
- **Installing v0.3.0 from GitHub** (isolated config): version 0.3.0, Skills (5), Agents (1), Hooks (0). Scaffolding from the install cache printed the expected `note` lines for `--part memory`, and the project hook tests passed 138/138.

### Not verified
- **Interactive prompts.** In headless mode `AskUserQuestion` cannot be answered, so "asks before promoting to `CLAUDE.md`" is shown only as "did not edit `CLAUDE.md`". For a universal rule the model chose not to promote because it duplicated a checklist line, instead of asking.
- **The skeptic's "never edits" is not enforced.** `tools` removes Edit and Write but not shell writes. The refusal above comes from the agent's instructions. Test runs can create files (`__pycache__` appeared once). In projects with the guardrails, `guard-bash.sh` and `protect-paths.sh` also fire on subagent tool calls (per the docs; not tested live), but they guard only protected paths, not source files.
- **`discover` actually reading a `[discover]` lesson in a live run.** Only the instruction text and the tag consistency are tested.
- **`CLAUDE.md` placeholder filling by `add` in headless mode.** The `Edit` needs approval, so the skill reported the placeholders as unfilled.
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
