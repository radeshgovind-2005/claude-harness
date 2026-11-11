# Changelog

All notable changes to the `dev-harness` plugin. Versions match `version` in
`plugins/dev-harness/.claude-plugin/plugin.json`, which is what Claude Code uses
to detect updates.

## 1.2.0 — 2026-11-11

A self-evolving harness. The template is the starting point; as a project grows, the harness proposes its own new parts, each in one strict form that code checks, installed only with the user's yes. Proven parts can go back to the marketplace. A second plugin, `dev-harness-perf` 0.1.0 (its own `CHANGELOG.md`), is the worked example. Nothing frozen in `docs/stability.md` changed; the part spec format is new and now listed there.

### Added
- **`scripts/forge.sh`** (code enforces the quality bar):
  - `check` fails unless every spec field is filled, the files fit the part type (one executable script for a hook; `SKILL.md` with name and description; an agent with an explicit tools list and no edit tool; a rule with `paths:`), every test passes, and **at least one test fails when the part's files are emptied** (tests that do not test the part are refused).
  - `install` copies a checked part into the project (hook plus a `.claude/settings.json` registration, skill, agent or path-scoped rule) and never overwrites.
  - `use` counts real uses; `status ... proven` needs 3; `list` checks the registry `docs/parts.md`.
  - `promote` puts a proven part on a `promote/<part>` branch in a clean local marketplace clone.
- **Skills:** `forge` (Claude may propose; builds nothing without a yes; fixes a misfiring hook test-first) and `promote` (user-invoked; a pull request only after a yes). Template `skills/forge/part-spec.md`.
- **Approval gate:** `guard-bash.sh` asks before `forge.sh install`, `status` and `promote`; no skill pre-approves them.
- `docs/parts.md` (the parts registry) in the memory part, routed from the template `CLAUDE.md` and `docs/INDEX.md`.
- **`explore.sh`** optional Metric lines, each enforced: `Runs: N` (no fewer runs: no single cold run), `Noise: P%` (a kept gain must beat it), `Correctness: \`cmd\`` (must pass to keep), `Evidence: required` (keep needs `--evidence FILE`); `baseline` and `measure` print `SPREAD=`; `--file` and `--template` choose the log. Without the new lines, nothing changes.
- `lesson` suggests `forge` when the same mistake comes back; `discover` notes recurring needs as candidate parts.
- Suites `tests/forge-test.sh` and `tests/perf-test.sh` in `run-all.sh` and CI. `validate.sh` checks a plugin against its own `CHANGELOG.md` when it has one, and fails on a symlink that dangles or leaves the marketplace.

### Fixed before release (fresh-context skeptic review; each case reproduced as a failing test first)
- `forge.sh check` runs a part's tests as code, so the `forge` skill no longer pre-approves it.
- An agent part may list only read-only tools; `[Read, Write]`, quoted names and MCP tools were let through.
- A skill part may not declare `hooks:` or pre-approve bare `Bash`, `Edit` or `Write`; a rule needs a non-empty `paths:`; a hook part's `files/` holds only its script; a timeout with a leading zero is refused.
- `install` prepares the settings change and checks the registry before it copies anything, so a refusal leaves nothing half-installed and can be retried.
- `promote --plugin` must be a plugin name (`../..` wrote outside the clone); `use` refuses a non-numeric `uses` (it was evaluated as shell arithmetic).
- The `guard-bash.sh` forge ask also catches a quoted subcommand, a variable or a glob for the script path (still best-effort).
- `explore.sh`: an optional Metric line that is present but unreadable (`Correctness: false` without backticks, `Runs: three`) stops with an error instead of being ignored; template `<placeholders>` still count as not set.
- `perf-guard` also checks a clean tree when HEAD moved since its last pass, so a regression that was already committed is caught.
- Documented, not changed: the emptied-files rule cannot tell a real test from one that only checks a file is not empty; evidence files are checked for existence, not content; artifacts of the Correctness command are committed with a kept variant unless ignored; a best value of 0 disables the Noise threshold.

## 1.1.0 — 2026-11-11

Stateful, parallel work. State lives in task cards in `docs/tasks/`, not in the conversation: a session is disposable, a card is not. Any session or person picks up one card with a small context, and long work prefers handoff, `/clear` and resume over compaction. Nothing frozen in `docs/stability.md` changed; the new skills, part, hooks and card format are additions.

### Added
- **`scripts/tasks.sh`** (code enforces): `new` writes a card in a fixed form; `check` fails on a missing or placeholder field, a bad status, an unknown or cyclic dependency, or an INDEX that does not match the cards; `overlap` fails when two not-done cards have overlapping scopes and no dependency path between them (they are not parallel); `index` rewrites the INDEX table; `active` keeps the active card per worktree in a gitignored `.claude/active-task`; `worktree <id>` makes a worktree and branch `task/<id>` and refuses a card that overlaps another, depends on an unfinished card, or is not committed. Overlap intersects the glob patterns (`*`, `?`, `**`; `[..]` and `{..}` count as `*`), so two cards that will both create the same new file are caught.
- **Skills:** `split` (a goal into cards, shown as a plan, written only after a yes, then `check`), `handoff` (Claude may start it: decisions, status, verified, next into the card, then "safe to /clear"), `resume <id>` (loads only `CLAUDE.md`, the intent, 5 lessons, the architecture doc, the card and its read-first files, and sets the active card).
- **Part `tasks`** (`add tasks`, and in `new`): `docs/tasks/_template.md`, `docs/tasks/INDEX.md`, `.gitignore += .claude/active-task`. The template `CLAUDE.md` routes to it and says to hand off before stopping; `docs/INDEX.md` and `docs/workflow.md` say how cards work.
- **Project hooks, all profiles:** `task-context.sh` (SessionStart: the active card and the newest 5 lessons, capped at 9,000 characters) and `task-compact.sh` (PreCompact: its stdout tells the compaction to keep the card's id, goal, decisions and status; it appends a timestamped "compacted" note with a git status snapshot to the card; it always exits 0, because exit 2 would block compaction). Both do nothing without an active card and need no `jq`.
- `validate.sh`: the three profiles must register the same hooks, and every project hook must be registered.

### Fixed before release (fresh-context skeptic review, each reproduced as a failing test first)
- `overlap` missed real overlaps for: a whole-project scope written `.`, `./` or `/`; dot folders such as `.github` or `.claude`; nested braces (`src/{a,{b,c}}`); a comma inside `[..]`; quoted entries; `//` and `.` segments; and a different letter case (macOS and Windows file systems ignore case). All now widen to a match; a literal that names an existing folder covers what is below it.
- `check` now fails on a scope with `..` or an unmatched `{` or `[`, and on two cards with the same number (two worktrees that each ran `new`, then merged).
- `check` flagged real text such as `List<T>` or `<div> renders` as a placeholder; only a whole value or line in `<...>` counts now.
- The PreCompact note goes at the end of the card's `## Log` section, even when another section follows it.
- A chained or variable-based call (`T="bash .../tasks.sh"; $T new ...`) missed the skills' pre-approval in a headless run; the three skills now say to run one written-out `tasks.sh` call per command (the rerun had no permission denial).
- Suite `tests/tasks-test.sh` in `run-all.sh` and CI; hook cases in `test-hooks.sh`.

### Not added (after checking the docs)
- A Stop reminder to update the card. A Stop hook's `additionalContext` reaches Claude but continues the conversation, and `systemMessage` reaches only the user, so it cannot be both non-blocking and visible to Claude. The rule is text in the template `CLAUDE.md` instead.

## 1.0.2 — 2026-11-11

Fixes from an audit of the files copied into projects. No skill or agent was renamed and no `harness.conf` key changed meaning. Three behaviour changes are listed under "Changed".

### Fixed
- **CI read `harness.conf` differently from the hooks.** The `dev-harness-hooks` workflow used `grep '^BLOCK_MAIN=' | cut`, so `BLOCK_MAIN="0"`, ` BLOCK_MAIN = 0` or a later duplicate line slipped past its "product with BLOCK_MAIN=0" check while the hooks read them as 0. Now one parser, `.claude/hooks/harness-conf.sh`, is shared by `protect-paths.sh`, `guard-bash.sh`, `verify.sh` and the workflow. `scaffold-test.sh` runs the workflow's own step against 30 conf variants and checks that CI fails exactly when the project's hook lets an edit on `main` through.
- **`protect-paths.sh` stripped the project root before lower-casing it.** bash's `pwd -P` keeps the case it is given, so with a project dir spelled `/Users/me/App` and a file path `/users/me/app/.claude/hooks/x.sh` the root was not stripped and the folder rules (`.claude/hooks/`, `.claude/settings.json`, `.git/`) did not match. Both sides are lower-cased first now. Regression tests in `test-hooks.sh`.
- **`verify.sh` had no time limit of its own.** Claude Code discards the output of a hook that hits its registered timeout (300 s here), so a slow check let Claude stop unverified and silently. The check now gets 240 s (GNU `timeout` or `gtimeout`, otherwise a bash 3.2 process-group fallback), then the stop is blocked once with "VERIFICATION TIMED OUT". A check that ignores SIGTERM is killed too. A check that exits 124 or 137 by itself is reported as failed, not timed out.
- `discover-lock.sh` header named the wrong matcher (`MultiEdit` was missing).
- The project `docs/INDEX.md` routed to `audits/`, which no part created. The `workflows` part now writes `docs/audits/README.md`, and `add memory` names it in its `note` lines.
- `ax-check.sh` stripped an unpaired leading or trailing quote; it now follows the same rules as `harness-conf.sh` (a parity test in `lens-test.sh`).

### Changed
- **No profile ships an npm `VERIFY_CMD`.** `product` (was `npm run typecheck && npm run lint`) and `assignment` (was `npm test`) now default to empty. Without `--verify-cmd`, `scaffold.sh` detects a command from `package.json` scripts (typecheck/lint for product, a real `test` script for assignment; the `npm init` placeholder is ignored; pnpm and yarn lockfiles are respected), a `Makefile` target, `Cargo.toml`, `go.mod` or `pyproject.toml` (pytest only when `[tool.pytest]`, `pytest.ini` or `tests/` exists), and reports it, or the empty value, as a `note`. A detected command whose tool is not installed is left empty, with a note that says so. `new` and `add` still propose a command and ask, as before.
- **The two guards fail closed without `harness-conf.sh`**, as they already do without `jq`. `verify.sh` blocks the stop once and says the work is not verified. A project upgraded from 1.0.1 keeps its old hooks (they parse inline) and gets the parser added; this is tested.
- `verify.sh` documents exactly when it runs: on every Stop when `VERIFY_CMD` is set and `git status --porcelain` is not empty (uncommitted or untracked changes), or always outside a git repository.

### Not changed (after checking the docs)
- The audit asked for `Write(docs/intent.md)` in the `discover` skill's `allowed-tools`. The permissions docs say `Write(path)` rules never match and `Edit(path)` covers every file-edit tool. A headless run confirmed it: inside `discover`, Write created `docs/intent.md` with no denial under the existing `Edit(docs/intent.md)`; outside the skill the same Write was denied. `validate.sh` now fails on a `Write(`, `MultiEdit(` or `NotebookEdit(` path rule in any skill.
- `guard-bash.sh` write detection stays a documented best-effort list.

## 1.0.1 — 2026-11-10

A documentation fix. No skill, agent, script, hook or template changed.

### Fixed
- The 1.0.0 entry below said `tests/docs-test.sh` has 58 checks. It has 80 (the number was written before the fence-balance, `--help` and fork-guide checks were added). The v1.0.0 tag and GitHub release were already published with the old line, and a published tag is not moved, so this patch release carries the correction. The 1.0.0 release notes on GitHub already say 80.
- `docs/progress.md` records the CI and install results for 1.0.0 (they were verified after the tag).

## 1.0.0 — 2026-11-10

From this version the user-facing surface is stable and follows semantic versioning: `docs/stability.md` says exactly what is frozen. The skills and agents do what they did in 0.5.0; this release is documentation, examples, tests, platform checks, and the fixes that running the plugin on itself turned up.

### Added
- Docs: `docs/getting-started.md` (install, the three profiles, a walkthrough for each), `docs/reference.md` (every skill, agent and script), `docs/how-it-works.md` (what code enforces and what text advises, platforms, every known limit in one place), `docs/stability.md`, `docs/contributing.md` (tests, adding a skill or agent, releasing, forking).
- `examples/`: 12 captured runs of the main skills and agents on toy projects (and two on this repository), each with a header naming the plugin version, the date, the command and how it was run. The output is not hand-written; paths are shortened, trimmed lines are said so, and the three agent examples are the parent session's relay of the agent's report (the files say so).
- `tests/docs-test.sh` (80 checks): relative links resolve; the README status and counts match the plugin; every skill and agent is in `reference.md`, `stability.md` and the README; no stale "planned" text; the fork guide names every file that carries the owner or author name; `CLAUDE.md` passes `ax-check.sh` (the repository dogfoods its own AX check); `progress.md` has a checkpoint for the current version; every script answers `--help`; examples carry their header; LF line endings; the icon is a valid square PNG.
- `tests/run-all.sh`: every suite, one summary, non-zero on any failure; `--fast` skips the 4-minute scaffold suite and says it did.
- CI runs on Ubuntu and macOS (bash 3.2): the fast suites and the project hook self-test on both, the 4-minute scaffold suite on Ubuntu only.
- `.gitattributes` keeps LF line endings for scripts, JSON, YAML and Markdown, so a Windows checkout cannot break the hook shebangs.
- A repository `CLAUDE.md` router for contributors and for an AI agent working here.
- A plugin icon (`.claude-plugin/icon.png`), a plain generated glyph. `claude plugin validate --profile directory` now has no warning.
- `--help` (as the first argument) on `scaffold.sh`, `explore.sh`, `goal.sh`, `ax-check.sh` and `showcase-facts.sh`.

### Fixed (found by running `lens` and `showcase` on this repository)
- **The guard hooks failed open without `jq`** (and with a `jq` that exits with an error). `guard-bash.sh` and `protect-paths.sh` printed `jq: command not found` and let every command and edit through. They now block, and tell Claude to ask the user to install `jq` (Claude cannot: every command is blocked until then). `verify.sh` no longer needs `jq` for its loop guard.
- **Main-branch protection did nothing in a repository with no commit yet** (`rev-parse --abbrev-ref HEAD` fails there), and a tag named `main` hid the branch. It now reads the branch with `symbolic-ref` and cuts `refs/heads/` itself.
- **`git commit -n`, the short form of `--no-verify`, was not blocked** (also `-nm`, `-anm`, `-m x -n`). It is now. Quoted text is removed before the check, so `-m "refactor -nested"` and `-m "$(git log -n 1)"` pass; a multi-line message with a word like ` -n` outside quotes can still trigger it and must be reworded.
- The hard blocks (`--no-verify`, force push, recursive delete, piping a download into a shell, changing the hooks path) now say what to do instead.
- The project's `test-hooks.sh` grows from 172 to 211 checks, each new behaviour proven by a mutant.
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
