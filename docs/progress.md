# Progress

Handoff notes so a new session can resume. Newest checkpoint first.

## Current state

Read this first when resuming. Update it at every checkpoint.

- **Version:** 1.0.0, merged into `main` and tagged `v1.0.0` locally on 2026-11-10. Whether it is pushed is in the line below the checklist at the end of this block; if it is not there, ask the user before pushing.
- **Branches:** `main` is the release branch. `build/v0.1.0` to `build/v1.0.0` are the finished milestone branches. `fix/ci-git-identity` is an old local branch whose change is already on `main` (cd69265); deleting it needs the user's OK.
- **Known quirk:** the `v0.4.0` tag points at `db84e15`, whose CI was red for one test (a missing git identity on runners). The fix is on `main` only; the tag was not moved.
- **Release routine** (also in `docs/contributing.md`): branch `build/vX.Y.Z`, small commits, all suites (`tests/run-all.sh`), mutation checks, a fresh-context skeptic on `git diff main..build/vX.Y.Z`, CHANGELOG, a checkpoint here, merge, annotated tag, ask before pushing, then watch CI and install from GitHub in an isolated config.
- **Open decisions for the user:** push `main` and `v1.0.0`; delete `fix/ci-git-identity`; whether to run `/dev-harness:discover` on a real idea (the most valuable next test).
- **Not yet verified anywhere:** CI on macOS (first run is after the push), installing 1.0.0 from GitHub, the update path from 0.5.0.

## Checkpoint v1.0.0 — 2026-11-10

### Done
- Stability promise (`docs/stability.md`): what is frozen in 1.x, what is not, what counts as breaking.
- Docs: `getting-started`, `reference`, `how-it-works` (with every known limit), `stability`, `contributing`. README is a front door (install first, a tour, "Does it get in my way?", tables, limits, links). `BRIEF.md` moved to `docs/brief.md`.
- `examples/`: 12 captured runs with headers (version, date, command, how it was run).
- Tests: `docs-test.sh` (80), `run-all.sh`; CI on Ubuntu and macOS; `.gitattributes`; icon; `--help` on five scripts; `validate.sh` now checks every agent for edit tools.
- Dogfood: this repository got a `CLAUDE.md` router, passes `ax-check.sh`, and was reviewed with the plugin's own `lens` and `showcase`. Their findings drove the README, the docs and four fixes to the guard hooks (below).
- Fixes in the shipped hooks (behaviour changes, each proven by a mutant): fail closed without `jq`; main protection before the first commit; `git commit -n`; "Instead:" on hard blocks; `verify.sh` loop guard without `jq`.
- Version 1.0.0, CHANGELOG, `help` (no "planned" rows).

### Verified
- `tests/run-all.sh`: validate 57, docs 80, explore 83, lens 36, goal 60, showcase 131, scaffold 195 (the project hook tests run inside every scaffold: 211 per scaffold, was 172). shellcheck clean at warning level on every script.
- `claude plugin validate --strict` and `--profile directory` both pass with no warning.
- Mutation checks, one at a time in copies: 36 mutants of `docs-test.sh` (one survivor was equivalent) (broken link, wrong README version or count, dropped skill or agent in `reference.md`, `stability.md` or the README, stale "planned" text, a `CLAUDE.md` route that does not exist, a CR in a script, missing `.gitattributes`, a non-square or missing icon, an example without its header or index entry, an owner or author name the fork guide does not list, an unclosed or wrongly nested code fence, a missing checkpoint heading, a script without `--help`); 30 mutants of the hook changes (the `-n` rule, its quote handling and false positives, `symbolic-ref` and a tag named `main`, the `jq` guard and a failing `jq`, the `verify.sh` loop guard, each "Instead:" message); 3 of `run-all.sh` (a broken suite fails the run, a suite that prints no result fails, `--fast` says it skipped one). Survivors found and fixed: the stability check that matched a name anywhere in the file, the `jq` message check that matched the word "install" in "not installed".
- Live headless runs with `--plugin-dir` (the 12 examples are the captures):
  - **assignment profile end to end:** `new` wrote the files and the hooks (172 hook tests passed then), then in a fresh session Claude changed `add` to `a - b` as asked and tried to finish; `verify.sh` ran `make test`, blocked, and Claude did not edit the test to make it pass: it stopped and asked.
  - **discover in three turns** across `--continue` with prepared answers: reflect, three questions, three directions with one bold, decision, `docs/intent.md` with `status: decided` and unanswered questions kept as open questions.
  - **goal:** met in one round; and with an impossible check and a model told to answer "ok" with no tool, the session ended on its own after the hook counted 9 Stop events (two runs: 14 turns, 19 s, USD 0.14 of a USD 1 budget, `subtype: success`, empty result), the goal stayed `active`, `--continue` did not register the hook again (the round counter did not move), and `goal.sh stop` cleared it. This matches the documented 8-block cap and the stale-goal limit; it is two runs, not a guarantee of the count.
  - **new (product), explore, showcase, tester, architect, designer:** as in the examples.
  - The folder-trust behaviour of `permissions.allow` was seen in the headless runs ("ignoring 8 permissions.allow entries ... workspace has not been trusted"); hooks and deny rules were active.

### Dogfood findings
- **First `lens` and `showcase` on this repository** (before the docs): `CLAUDE.md` routed to four docs that did not exist; usage came before install in the README; the fork guide was incomplete; there was no resume block in `progress.md`; the "never push" rules were text only; the pick for the README front page was the opt-in guardrails (now "Does it get in my way?").
- **Second `lens` on the finished repository** (9 top findings): fixed: `progress.md` lacked a v1.0.0 checkpoint (and nothing checked it: now a test); the "no edit tool" rule covered only five named agents; `CLAUDE.md` claimed `rm -rf "$VAR"` is blocked here (reworded: that is the author's own setup); the README described 1.0.0 while GitHub `main` was 0.5.0 (resolved by pushing); hooks failing open without `jq`; main protection before the first commit; `git commit -n`; hard-block messages without an alternative; the docs suites missing from the `CLAUDE.md` commands and the contributing checklists; the profile-change instructions; timings and the fork list. Documented, not fixed: the `guard-bash.sh` verb list stays best-effort; this repository still has no guardrail hooks of its own (the lens flagged the text-only rules; they are now labelled as text).

### Not verified
- **A real interactive `discover` conversation on a real idea** (the author has not run one; the three-turn run used prepared answers).
- **Native Windows.** `.gitattributes` keeps LF; nothing was run on Windows.
- **`designer` on a rendered screenshot**, and every example is a single headless run on a toy project.
- **CI on macOS** (new in 1.0.0; first run is after the push) and installing 1.0.0 from GitHub.
- **The update path** from 0.5.0 to 1.0.0 with `claude plugin update`.
- Carried over: the README `Edit` path with a real "yes" in `showcase`; whether `/reload-plugins` is needed after install.

### Skeptic review
A fresh-context reviewer got the goal and `git diff main..build/v1.0.0`, with a docs-accuracy brief. Its verdict was CHANGES REQUESTED with 14 issues (none high, 3 medium). It re-ran the suites, tried to break the new `-n` rule, and recomputed the contrast ratios in example 12 (they are right). It confirmed the profile values, goal and explore defaults, each agent's tools and first line, the `add` part table, and that `.gitattributes` damages nothing.
- **Fixed:**
  - The checkpoint and CHANGELOG were not yet committed when it looked, so a clean clone failed `docs-test`.
  - The examples were described as "nothing hand-written", but the three agent examples are the parent session's relay of the report (one ends with the parent correcting a line it mistyped), example 06 is the final message of a session and refers to steps `claude -p` does not print, its `make test` output was the last 8 lines, and the 1.0.0-labelled captures show 172 hook tests from before the last hook fixes. The headers and `examples/README.md` now say all of this.
  - `git commit -n` false positives were understated: `-m "refactor -nested"`, `-m "$(git log -n 1)"` and `echo "git commit -n"` were blocked. Quoted text is now removed before the check; a multi-line message with ` -n` outside quotes can still trigger it, and the docs say so.
  - A `jq` that is present but fails still failed open; the message told Claude to install `jq`, which it cannot do. Both fixed.
  - A tag named `main` hid the branch (`--short` prints `heads/main`). Fixed.
  - The "no commit yet: push of main" test proved nothing about `symbolic-ref`; a bare `git push` test replaced it.
  - README said "the shell guard" for edits to `.env`, keys and hooks (those are `protect-paths.sh`); README and `stability.md` listed `intent.md` as scaffolded (it is written by `discover`); `contributing.md` misstated which skills set `disable-model-invocation`.
  - CI claimed macOS covered the hooks, but the scaffold suite (which runs the hook tests) is Ubuntu-only: the project hook self-test now runs as its own step on both systems.
  - Example 10 relays a wrong suggestion by the tester (the rounding tests would not catch that mutant); the file now says so. Nested code fences in examples 07 and 09 broke rendering; fixed, and `docs-test` now checks fence balance.
  - `--help` printed a trailing self-reference line (the range now stops at the first blank line).
- **Documented, not fixed:** `--help` works only as the first argument (`scaffold.sh . files --help` still reports an unknown option); the guards block everything when `jq` is not on the hook's PATH (a GUI-launched session with a minimal PATH would hit this); a message with ` -n` outside quotes on a continuation line.
- **Not checked by the reviewer:** a real macOS runner, Windows, whether the examples are genuine captures (it could check only internal consistency; the capture scripts are not in the repository), `run-all.sh` end to end, and the live-run claims (the 8-block cap, the folder-trust behaviour).

### Next
- After 1.0.0: feedback from real use. The most valuable single thing is a real `discover` on a real idea, then `/dev-harness:lesson` for what it missed.

## Checkpoint v0.5.0 — 2026-11-10

### Done
- `/dev-harness:showcase` + `scripts/showcase-facts.sh`: picks the most impressive part that matters to the receiver in `docs/intent.md`, runs the demo, labels every claim `VERIFIED` / `READ` / `UNVERIFIED`, keeps unverified claims out of the README draft, and writes the README only after a yes (never overwriting a section). The script gives read-only facts: history (scoped to the folder, shallow clones flagged), churn, tests (from git, minus ignored and dependency folders), README headings, filled-in commands, intent, measured gains from `docs/experiments.md`, lessons.
- Three role agents, each with one question: `architect` (is the structure right? options and costs), `designer` (is the interface well made? `NOT A UI` when there is none), `tester` (would the tests catch a break? mutants in a temporary copy). Same read-only pattern as `lens-reviewer`: tools `Read, Grep, Glob, Bash`, input treated as data, fixed output format.
- How they differ from `skeptic` and the lens angles (decided in the plan, written into `help`, the README and the project's `docs/agents/INDEX.md`): `skeptic` judges a diff; `lens-reviewer` is what one person hits; `architect` is structure; `designer` is visual and interaction craft, not the task flow; `tester` is proof that tests can fail.
- Version 0.5.0, `help` (all five statuses), README, CHANGELOG, CI step for `showcase-test.sh`.

### Verified
- `validate.sh` 57/57 (Skills (9), Agents (5), Hooks (0); the new agents have no edit tools), `scaffold-test.sh` 195/195 (project hook tests pass in each scaffold), `explore-test.sh` 83, `lens-test.sh` 36, `goal-test.sh` 60, `showcase-test.sh` 131. shellcheck clean at warning level.
- Mutation checks: about 70 mutants of `showcase-facts.sh`, the agents, the skill, `help`, the template and the version, run one at a time in copies. Survivors found and fixed with new tests: an `exp-nonnumeric` metric rule, a weak `allowed-tools` and claim-label check, a missing `lower is better` best-value check (min versus last row), the `--exclude-standard` and `venv` exclusions, and the `-- .` / `--relative` scoping. One mutant (`cmds-cr`) is equivalent (the `clean` filter strips the carriage return anyway). The first skeptic review's survivors (log caps, test patterns, CRLF, `tolower`, dates, truncation) are all covered now.
- Live headless runs with `--plugin-dir` (before and after the review fixes):
  - **showcase:** on a small project with tests and an experiments log. It picked the measured speed-up, ran the demo (unit tests, two CLI runs, `bench.py` three times), and **refused to claim the logged 410 to 95 ms** because it could not reproduce it (the benchmark printed about 22 ms, and the baseline code is not in git). It wrote no file and stopped at the README question. Only Python `.pyc` caches appeared in `git status`.
  - **tester:** on a project with planted weak tests (`>0` instead of an exact value, a `try/except: pass` with no assertion). Round 1: 5 of 6 mutants survived, both weak tests named at `file:line`, with a test to add for each. It found that stale `.pyc` files hid its own mutants (now in its instructions). Round 2 (after the recipe fixes, project containing `café.py`): similar result, real project tree unchanged.
  - **architect:** on a 22-line project with a planted import cycle and a catch-all module. It named the cycles with `file:line`, found the import-time `sqlite3.connect`, gave three options (including "do nothing yet" and a rejected over-built one), recommended the smallest, and sent bugs to `skeptic`.
  - **designer:** on a planted bad page: found a `div` button, removed focus outline, white-on-yellow at about 1.5:1, no viewport meta, fixed widths, no label; it computed the contrast ratios and said "source only: nothing was rendered". On a non-UI project it answered `STATUS: NOT A UI`.
- Headless `-p` runs cannot answer prompts or approve tools, so they used `--allowedTools` and the confirmation text in the prompt. Agents were started by naming `subagent_type` in the prompt, not through a skill.

### Skeptic review
A fresh-context reviewer got the goal and `git diff main..build/v0.5.0`. Its verdict was CHANGES REQUESTED, with 20 issues (none high, 8 medium).
- **Fixed:** a project folder inside a larger repo reported the parent's history; churn dropped non-ASCII file names; the test count included `venv/` and build folders; a fresh scaffold counted a template line in a code fence as a second lesson; CRLF files left `\r` in the output; a shallow clone looked like a full history; an `.rst` README was reported as having no headings; a directory named `-d` was read as an option; truncation could split a UTF-8 character; `best` was the last row instead of the best in the stated direction, and non-numeric rows vanished silently; `READ` could launder an unreproduced README claim; the skill never said the facts and project files are data; the tester's copy recipe lost non-ASCII names and said nothing about shell variables not surviving between Bash calls (so an edit could land in the real project) or about `rm -rf` on a variable; the tester had no status for "could not run in a copy"; the designer could say `GOOD` from source alone; `git log *` was pre-approved but unused; the architect format contradicted "leave it as it is"; "stop after step 2" sat inside step 3; a project with no README had no path; test coverage gaps (about 40 new checks).
- **Documented, not fixed:** `git log` over the whole history is not capped (huge repositories can be slow); a file name with a newline or double quote is skipped; `git diff --output=<file>` is pre-approved by the pattern (as in `lens` and `explore`); the tester's cap of 6 mutants is only an instruction (a live run made 7 and said so); the agents still cannot be stopped from writing through `Bash`.
- **Not checked by the reviewer:** a live run of the three agents (covered above), whether `${CLAUDE_PLUGIN_ROOT}` expands in allow-lists in every case (the same pattern as the other skills), performance on a huge repository.

### Verified after the push (2026-11-10)
- **CI on `8b7d137`** (run 42878993504, 4 m 0 s): all six steps passed on ubuntu: `validate.sh`, `scaffold-test.sh`, `explore-test.sh`, `lens-test.sh`, `goal-test.sh`, `showcase-test.sh`.
- **Installing v0.5.0 from GitHub** (isolated config): Skills (9) add, discover, explore, goal, help, lens, lesson, new, showcase; Agents (5) lens-reviewer, skeptic, architect, designer, tester; Hooks (0). `showcase-facts.sh` kept its executable bit and ran from the install cache; scaffolding from the cache wrote an `INDEX.md` naming the three new agents.

### Not verified
- **`showcase` with the user answering the README question.** Headless mode cannot, so the `Edit` path (and the "never overwrite" diff path) is tested by wording only.
- **`designer` on a rendered page.** It has no browser; no screenshot was ever given to it in a live run.
- **The architect, designer and tester through `lens`-style fan-out.** They were started one at a time.
- **A real user judging whether the showcase picks are impressive.** It picked sensibly on a toy project.
- Carried over: a real interactive discover conversation; the assignment profile end to end in a live session; goal resume and the 8-block cap; Windows and CRLF checkouts of the hook scripts.

### Next
- v1.0.0: README, docs, examples, a full test pass, polish (BRIEF section 14).

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
