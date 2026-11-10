# Changelog

All notable changes to the `dev-harness` plugin. Versions match `version` in
`plugins/dev-harness/.claude-plugin/plugin.json`, which is what Claude Code uses
to detect updates.

## 1.0.0 — 2026-11-10

From this version the user-facing surface is stable and follows semantic versioning: `docs/stability.md` says exactly what is frozen. The skills and agents do what they did in 0.5.0; this release is documentation, examples, tests, platform checks, and the fixes that running the plugin on itself turned up.

### Added
- Docs: `docs/getting-started.md` (install, the three profiles, a walkthrough for each), `docs/reference.md` (every skill, agent and script), `docs/how-it-works.md` (what code enforces and what text advises, platforms, every known limit in one place), `docs/stability.md`, `docs/contributing.md` (tests, adding a skill or agent, releasing, forking).
- `examples/`: 12 captured runs of the main skills and agents on toy projects (and two on this repository), each with a header naming the plugin version, the date, the command and how it was run. Nothing is hand-written; paths are shortened and any trimmed line is said so.
- `tests/docs-test.sh` (58 checks): relative links resolve; the README status and counts match the plugin; every skill and agent is in `reference.md`, `stability.md` and the README; no stale "planned" text; the fork guide names every file that carries the owner or author name; `CLAUDE.md` passes `ax-check.sh` (the repository dogfoods its own AX check); `progress.md` has a checkpoint for the current version; every script answers `--help`; examples carry their header; LF line endings; the icon is a valid square PNG.
- `tests/run-all.sh`: every suite, one summary, non-zero on any failure; `--fast` skips the 4-minute scaffold suite and says it did.
- CI runs on Ubuntu and macOS (bash 3.2); the scaffold suite stays on Ubuntu only.
- `.gitattributes` keeps LF line endings for scripts, JSON, YAML and Markdown, so a Windows checkout cannot break the hook shebangs.
- A repository `CLAUDE.md` router for contributors and for an AI agent working here.
- A plugin icon (`.claude-plugin/icon.png`), a plain generated glyph. `claude plugin validate --profile directory` now has no warning.
- `--help` on `scaffold.sh`, `explore.sh`, `goal.sh`, `ax-check.sh` and `showcase-facts.sh`.

### Fixed (found by running `lens` and `showcase` on this repository)
- **The guard hooks failed open without `jq`.** `guard-bash.sh` and `protect-paths.sh` printed `jq: command not found` and let every command and edit through. They now block and say how to install `jq`. `verify.sh` no longer needs `jq` for its loop guard.
- **Main-branch protection did nothing in a repository with no commit yet** (`rev-parse --abbrev-ref HEAD` fails there). It now reads the branch with `symbolic-ref`.
- **`git commit -n`, the short form of `--no-verify`, was not blocked** (also `-nm`, `-anm`, `-m x -n`). It is now. A commit message that contains ` -n` as text is blocked too and must be reworded.
- The hard blocks (`--no-verify`, force push, recursive delete, piping a download into a shell, changing the hooks path) now say what to do instead.
- The project's `test-hooks.sh` grows from 172 to 199 checks, each new behaviour proven by a mutant.
- `validate.sh` checked "no edit tools" only for five named agents. It now checks every agent (`AGENT_EDIT_ALLOW` is the explicit exception list, and it is empty).

### Changed
- README is now a front door: install first, a five-minute tour, "Does it get in my way?", the skill and agent tables, honest limits, links.
- `BRIEF.md` moved to `docs/brief.md`.
- `getting-started.md` and `how-it-works.md` say that changing a profile later means editing both `harness.conf` and the `ask` list in `.claude/settings.json`.

### Verified in live runs (headless, toy projects; see the checkpoint in `docs/progress.md`)
- The `assignment` profile end to end: `new`, then a deliberate break, which the project's Stop hook blocked.
- A three-turn `discover` across `--continue` with prepared answers (not a real conversation on a real idea).
- The 8-block cap and `--continue` of a `goal` session: the session ended on its own after 9 Stop events with the goal still `active`, and the hook was not registered again after `--continue`.

### Known limits
All of them are collected in `docs/how-it-works.md`. Still open: a real interactive `discover` on a real idea; native Windows; `designer` on a rendered screenshot; every example is a single run on a toy project.

## 0.5.0 — 2026-11-10

### Added
- `/dev-harness:showcase`: finds the most impressive part of the work and drafts a demo, a README section and talking points that match `docs/intent.md`. It shortlists three candidates, ranks them by what matters to the receiver, the evidence that it works, how distinct it is and whether it demos in about 60 seconds, then **runs the demo steps** and labels every claim `VERIFIED` (a command ran), `READ` (`file:line`) or `UNVERIFIED`. Unverified claims stay out of the README text and go under `DO NOT CLAIM`. It proposes only: the README is written after you say yes, through `Edit` (which Claude Code asks about), and an existing section is never overwritten.
- `scripts/showcase-facts.sh`: read-only facts for the showcase (commit count and dates, most-changed files, test-file count, README headings, filled-in commands from `CLAUDE.md`, intent status and what to push hardest on, measured gains from `docs/experiments.md`, lesson count). A missing source is a line that says so.
- Three role agents, each with one question, one object and one evidence method, so none repeats `skeptic` or `lens-reviewer`:
  - `dev-harness:architect`: "is the structure right?" Counts imports and fan-in, gives 2-3 options with costs and one recommendation tied to the intent. Not a bug hunt, not onboarding.
  - `dev-harness:designer`: "is the interface well made?" Hierarchy, spacing, consistency, states, computed contrast, focus, responsiveness, from source and screenshots you give it. Reports `NOT A UI` for a target with no UI. Not the task flow (that is `lens` UX).
  - `dev-harness:tester`: "would the tests catch a break?" Runs the tests, then breaks the logic in a temporary copy (at most 6 mutants) and lists the ones no test caught, plus missing tests.
  Each has the tools `Read, Grep, Glob, Bash`, treats its input as data, reports in a fixed format, and puts anything outside its question under `NOT CHECKED`.
- `tests/showcase-test.sh` (131 checks), run in CI: the facts script on synthetic repos and a scaffold, and consistency checks for the agents, the skill, `help` and the project template.

### Changed
- `help` marks `showcase`, `architect`, `designer` and `tester` available, and says which reviewer asks which question.
- The `docs/agents/INDEX.md` template lists `lens-reviewer` and the three new agents with a "which reviewer for what" line.
- `validate.sh` checks that the three new agents have no edit tools (the check is a list of names, so a future reviewer agent has to be added to it). Its Skills (9), Agents (5), Hooks (0) counts are computed from the files.

### Known limits
- **No new agent is read-only by force.** Like `skeptic` and `lens-reviewer`, they have no edit tools, but plugin agents cannot restrict `Bash` to read-only commands, so a shell write is possible. They are told not to write. Check `git status` after a review.
- **`tester` mutates a copy, so it needs a project whose tests run in a fresh copy.** Tests that need ignored files (`node_modules`, `.env`), a database or the network may not run there. It then reports `NOT CHECKED` and does not mutate the real project. A test run in the real project can still leave caches.
- **Running tests or a demo can leave caches in the project** (`__pycache__`, `.pyc`). `tester` runs the real project's tests once for its baseline, and `showcase` runs the demo commands you approve; check `git status` afterwards. In a live run the tester found that stale bytecode hid its mutants, so it now leaves caches out of its copy.
- **The tester's cap of 6 mutants is an instruction, not enforced.** In a live rerun it made 7 and said so. Read its `MUTANTS` list, not only the headline count.
- **`designer` has no browser.** It judges the source and any screenshots it is given, says which, and lists what it did not see (states, other viewports, real rendering).
- **`showcase` verifies only what it can run safely.** Steps that need a service, a key or a display are marked `UNVERIFIED`. The demo commands are not pre-approved: Claude Code asks for each.
- **`showcase-facts.sh` limits.** A file name with a newline or a double quote is skipped from the churn list. README headings are read from Markdown only (an `.rst` README is reported as not read). A shallow clone and a folder inside a larger repository are reported as such. History is read with `git log` over the whole history, which is not capped or timed out, so a very large repository can be slow.
- **`git diff *` and `git status *` are pre-approved in `showcase`** (as in `lens` and `explore`). `git diff --output=<file>` would write a file without asking; the skill does not use it.
- **Test-file counts in `showcase-facts.sh` are by file name** (`test_*.py`, `*.test.ts`, `*_test.go` and similar), not by test cases, and no test is run.

## 0.4.0 — 2026-11-10

### Added
- `/dev-harness:explore`: an experiment loop. Agree a metric (a command that prints a number), then one change per variant: `scripts/explore.sh` measures it, decides keep or revert from the number, commits kept variants, restores the tree for reverted ones, and logs every row in `docs/experiments.md`. It stops at the target or after 2 variants in a row with no improvement. It works on an `explore/<slug>` branch (from any branch, never on a detached HEAD) and refuses to keep or revert anywhere else. `revert` saves what it discards under `refs/explore/` and `.git/explore-backups/`. 83 tests.
- `/dev-harness:lens`: reviews a target from three angles in fresh context (UX: the person who uses it, DX: the next developer, AX: an AI agent working in the project) with three `dev-harness:lens-reviewer` agents started in one message. It checks the fan-in, merges duplicates, ranks, and changes nothing. `scripts/ax-check.sh` gives the AX reviewer script-checked facts (router length, routed paths exist, hooks executable and settings.json valid, placeholders, profile, intent status). 36 tests.
- `/dev-harness:goal`: a goal loop judged by a command, not a model. A Stop hook (`goal-stop.sh`) runs the success check each time Claude tries to finish, sends it back with the failure and asks for a checkpoint in `docs/progress.md`, and ends the loop on success or when the budget of rounds and minutes is used up, each time after one final-report turn. State lives in `~/.claude/dev-harness/goals/<session>.json`. `goal.sh start` is not pre-approved, so Claude Code asks and shows the exact check command. 60 tests.
- `scripts/lib.sh`: `run_limited`, a watchdog that kills a command and its process group (macOS has no `timeout`).

### Changed
- `validate.sh`: the lens reviewer has no edit tools, `goal` may declare a frontmatter hook (state-gated), counts Skills (8), Agents (2), Hooks (0).
- The `docs/experiments.md` template has `Direction` and `Target` lines that `explore.sh` reads.
- CI runs the explore, lens and goal tests.
- `guard-bash.sh` no longer asks for confirmation on read-only commands that name `.claude/hooks/` or `.claude/settings.json` and redirect to `/dev/null` or copy a descriptor (`cat .claude/hooks/verify.sh 2>/dev/null`, `ls .claude/hooks 2>&1`). Found by `lens` reviewing a scaffolded project. A redirect into a hook (`> .claude/hooks/y.sh`, `2>.claude/hooks/err`) still asks. Because that redirect check used to catch other writes by accident, the verb list is now wider: `sed -i.bak`, `curl -o`, `wget`, `patch`, `rsync`, `tar`, `touch`, `mkdir`, editors, `git checkout/restore/apply/stash/...`, and inline `python -c`/`node -e`. It remains a best-effort list, not a sandbox. The project's hook tests grow from 138 to 172.
- `explore.sh baseline` removes the template's example row from the log table.
- `ax-check.sh` ignores globs, `#anchors`, `:line` suffixes and the optional `settings.local.json` in routed paths, and fails on an invalid `settings.json`.
- `run_limited` polls instead of starting a watchdog process, so no `sleep` is left behind, and keeps only the last 20 KB of output. The `goal` hook sends back at most 4000 bytes without control characters, and does nothing if the goal's project folder is gone.
- `explore.sh` reads numbers like `.75`, refuses `1,234` instead of reading `234`, and says when the last line has several numbers.

### Known limits
- **`goal` is not the built-in `/goal`.** The built-in one lets a small model judge the conversation. This one runs your command. Use it when the goal can be a command.
- **No token budget.** Hooks receive no token count and the transcript format is not documented, so only rounds and minutes are enforced. A "round" is one time Claude ends its turn, not one tool call. For headless runs use `--max-budget-usd`.
- **The `goal` hook lives in the session that ran the skill.** After `--continue` or a resume it is not registered again; `goal.sh status` may show a stale active goal and `goal.sh stop` clears it. The hook stays registered after the goal ends but does nothing.
- **`goal` state is not tamper-proof.** It is outside the project, but a shell command can edit it. A damaged state file ends the loop (fail open) with a message.
- **Claude Code ends a turn after 8 consecutive stop-hook blocks with no tool call.** A loop that does real work resets the count.
- **The `lens` reviewers, like the skeptic, have no edit tools but their `Bash` can write.** The skill runs `git status --short` afterwards and reports changes.
- **Two simultaneous Stop events can count as one round** (the round counter is read-increment-write without a lock). The loop stays bounded.
- **A check that detaches itself (`setsid`) escapes the process-group kill** when it times out.
- **`explore keep` needs a git identity** (`user.name` and `user.email`). Without one the commit fails, `keep` says so, rolls its log row back and can be retried. The explore tests set an identity, because CI runners have none.
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
