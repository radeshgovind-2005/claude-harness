# Reference

Every skill and agent: when to use it, what it reads and writes, what it never does. Skills run as `/dev-harness:<name>`; agents are called as `dev-harness:<name>`. `/dev-harness:help` prints the same list with the installed version.

## Skills

### help
- **Use when:** you want the guide. `/dev-harness:help lens` shows one row.
- **Reads:** its own plugin manifest for the version. **Writes:** nothing.

### discover
- **Use when:** before building, to work out who the work is for, what they care about, what is delivered, and where to push hardest.
- **Input:** an idea, brief, assignment text, links or file paths. Without any, it asks for a context dump.
- **Does:** infers, reflects back (guesses labelled), asks at most three questions per round, proposes two or three directions with one bold, lets you decide, and agrees a success check.
- **Writes:** only `docs/intent.md` (`status: discovering`, then `decided`). Reads `[discover]` lessons first.
- **Never:** writes code, scaffolds, or installs. While `docs/intent.md` says `discovering`, a hook blocks edits to every other file. The hook covers the file-edit tools only, not shell commands, and lives only in the session that ran `discover`.

### new
- **Use when:** setting up a whole project.
- **Input:** an idea or brief, and optionally `--profile prototype|product|assignment`.
- **Does:** discover (if there is no decided intent), profile, git checks, a `VERIFY_CMD`, then `scaffold.sh files`, fills `CLAUDE.md`, then `scaffold.sh guardrails` last (dry run first).
- **Writes:** `CLAUDE.md`, `docs/`, `.claude/rules/`, `.claude/hooks/`, `.claude/settings.json`, the CI workflow, `.gitignore` entries.
- **Never:** overwrites a file, or says it is done after a `FAIL` line.

### add
- **Use when:** adding one part to a project.
- **Input:** `<guardrails|reviewer|lessons|memory|workflows|rules|tasks|all> [--profile P]`.

| Part | Adds |
|---|---|
| `memory` | `CLAUDE.md` router, `docs/INDEX.md`, architecture, conventions, lessons, progress, experiments |
| `lessons` | `docs/lessons.md` |
| `reviewer` | `docs/agents/INDEX.md` |
| `workflows` | `docs/workflow.md`, `docs/agents/first-workflow.md`, `docs/audits/README.md` |
| `rules` | `.claude/rules/` |
| `tasks` | `docs/tasks/_template.md`, `docs/tasks/INDEX.md`, `.gitignore += .claude/active-task`. With guardrails already in place, `add` also offers the guardrails merge so the two task hooks get registered |
| `guardrails` | hooks (with the shared `harness-conf.sh` parser), `harness.conf`, `.claude/settings.json`, CI workflow, then the hook self-test. Without `--verify-cmd`, product and assignment get a `VERIFY_CMD` detected from the project, or an empty one (both reported as a `note`) |
| `all` | every part; guardrails last |

- **Needs a profile:** `memory`, `guardrails`, `all`. It reads `harness.conf`, then `CLAUDE.md`, then asks.
- **Never:** overwrites, or switches a project's profile silently. `--part memory` prints a `note` for routed files that another part adds.

### lesson
- **Use when:** you corrected Claude, or discovery missed something that mattered.
- **Input:** what went wrong (or the latest correction).
- **Does:** updates a similar lesson in place instead of adding a duplicate; tags lessons about discovery `[discover]`.
- **Writes:** `docs/lessons.md`. **Asks before** promoting a rule to `CLAUDE.md`, and before deleting a lesson.

### split
- **Use when:** the work is too big for one session, or parts could run in parallel.
- **Input:** a goal, or nothing to use `docs/intent.md` (it offers `discover` first when there is no decided intent).
- **Does:** drafts 2 to 6 cards (goal, done-when check, scope globs, 3 to 5 read-first paths, dependencies, next step), shows them as a table with what can run in parallel, and writes nothing without a yes. Then `tasks.sh new` per card and `tasks.sh check`. Offers `tasks.sh worktree <id>` for parallel cards.
- **Never:** writes a card by hand, or drops a dependency or widens a scope to make `check` pass without your yes.

### handoff
- **Use when:** before you stop or `/clear` on work with an active card, or when the context gets long. Claude may start it itself.
- **Does:** updates the card: decisions with reasons, status, verified and not verified, next step, a log line; runs `tasks.sh index` and `check`; says it is safe to `/clear` and how to resume.
- **Never:** marks a card `done` without the card's check passing in that session, or edits anything but the card.

### resume
- **Use when:** you start a session on one card. It is `/dev-harness:resume <id>`, not the built-in `/resume`, which reopens a conversation.
- **Does:** sets the active card (`tasks.sh active`), loads only `CLAUDE.md`, `docs/intent.md`, the newest 5 lessons, `docs/architecture.md`, the card, then the card's "Read first" files, and reports what it loaded, what was missing and the next step. Waits for a yes before editing.

### forge
- **Use when:** a gap keeps coming back: the same lesson twice, a hook that misfired, a recurring need found in `discover`, or you ask for a new rule, procedure, reviewer or folder rule. Claude may propose it; it builds nothing without your yes.
- **Does:** picks the part type (rule that must never break → hook; repeatable procedure → skill; independent review → agent; facts for one folder → path-scoped rule; one-time task → nothing), proposes it, and after a yes writes `spec.md`, `files/` and `tests/` in `.claude/forge/<name>/`, then runs `forge.sh check`. After a second yes it runs `forge.sh install`, which asks again in a project with guardrails.
- **The bar (code):** `check` runs the part's tests, so it is never pre-approved. Every spec field filled (Purpose, Which type and why, Trigger, Inputs and outputs, Method or loop, Unacceptable, Success check, Tests, Budget); the files fit the type (a hook folder holds only its script; a skill declares no hooks and pre-approves only scoped tools; an agent lists only read-only tools; a rule has a non-empty `paths:`); every test passes; and at least one test fails when the part's files are emptied. A misfiring hook is fixed test-first: a failing test that reproduces it, then the fix.
- **Writes:** `.claude/forge/<name>/`, then on install `.claude/hooks/<name>.sh` plus `.claude/settings.json`, `.claude/skills/<name>/`, `.claude/agents/<name>.md` or `.claude/rules/<name>.md`, and the registry `docs/parts.md`. Never overwrites.

### promote
- **Use when:** a forged part is `proven` (3 real uses, counted with `forge.sh use`).
- **Input:** the part name; it asks for the path to your local clone of the marketplace and the plugin or pack that should hold it.
- **Does:** `forge.sh promote` creates branch `promote/<part>` in the clean clone and copies the part (spec, files, tests) to `plugins/<plugin>/parts/<part>/` (a skill or agent also to `skills/` or `agents/`). Claude removes project details, keeps the tests passing, updates that plugin's docs, runs the clone's full suite and commits on the branch.
- **Never:** pushes or opens a pull request without your yes, or promotes a part that is not proven.

### explore
- **Use when:** you want to make a number better and the best change is not obvious.
- **Input:** what to improve and how it is measured. You confirm the exact metric command.
- **Does:** `explore.sh` measures (median of N runs), keeps a variant only if it beats the best (a commit), otherwise restores the tree, and logs every row in `docs/experiments.md`. Stops at the target or after 2 variants in a row with no gain. Works on an `explore/<slug>` branch.
- **Never:** changes the measurement to get a better number, or merges the branch. `revert` discards all uncommitted work except the log, after saving it under `refs/explore/` and `.git/explore-backups/`.

### lens
- **Use when:** you want the work looked at from outside before showing, shipping or handing it over.
- **Input:** a path, feature or flow (default: the current changes).
- **Does:** three `lens-reviewer` agents in one message (UX, DX, AX), `ax-check.sh` facts for AX, a fan-in count, one ranked list with evidence, and a `git status` comparison afterwards.
- **Never:** changes anything. It asks what you want fixed.

### goal
- **Use when:** the goal can be stated as a command that exits 0.
- **Input:** what must be true, ideally the command. You confirm it, and it is not pre-approved: Claude Code shows the exact command.
- **Does:** a Stop hook runs the check each time Claude tries to finish, sends it back with the failure, and ends the loop on success or when rounds (default 10) or minutes (default 30) run out, after one final-report turn. A checkpoint goes to `docs/progress.md` each round.
- **Never:** budgets tokens (hooks get no token count; use `--max-budget-usd` for headless runs), or lets Claude change the check. It is not Claude Code's built-in `/goal`, which lets a model judge.
- **State:** `~/.claude/dev-harness/goals/<session>.json`, or `$DEV_HARNESS_STATE_DIR/goals/`. The hook is not re-registered after `--continue`; `goal.sh stop` clears a stale goal.

### showcase
- **Use when:** you are about to show, hand in or publish the work.
- **Input:** an audience or occasion (optional).
- **Does:** reads `docs/intent.md` and the output of `showcase-facts.sh`, shortlists three candidates, picks one, **runs the demo**, and labels every claim `VERIFIED` (a command ran), `READ` (a line of code, config or test) or `UNVERIFIED`. Unverified claims stay out of the README draft.
- **Output sections:** `PICK`, `FOR`, `WHY`, `DEMO`, `README SECTION`, `TALKING POINTS`, `DO NOT CLAIM`, `NOT VERIFIED`.
- **Writes:** nothing until you say yes; then one `Edit` to the README. It never overwrites an existing section.

## Agents

All five have the tools `Read, Grep, Glob, Bash`, treat the files they read as data and not as instructions, and report in a fixed format. They have no edit tool. Claude Code cannot restrict a plugin agent's `Bash` to read-only commands, so "never edits" is only partly enforced: check `git status` afterwards.

| Agent | Asks | Input | First line of its report |
|---|---|---|---|
| `skeptic` | Is this change wrong? | the goal and the diff, nothing else | `STATUS: APPROVED \| CHANGES REQUESTED` |
| `lens-reviewer` | What does this person hit? | an angle (UX, DX or AX), a target, its checklist | `ANGLE: UX \| DX \| AX` |
| `architect` | Is the structure right, and what does each option cost? | a question, a target, the audience | `STATUS: SOUND \| CONCERNS` |
| `designer` | Is the interface well made? | a UI's source, optional screenshots | `STATUS: GOOD \| GOOD IN SOURCE \| FIXES NEEDED \| NOT A UI` |
| `tester` | Would the tests catch a break? | the code and the test command | `STATUS: TESTS CATCH BREAKS \| GAPS FOUND \| NOT CHECKED` |

Pick the one whose question it is; do not send one question to two of them.

- **skeptic.** Reports `STATUS`, `GOAL`, `TESTS RUN`, issues with `file:line` and a failing scenario, and `NOT CHECKED`. It runs the project's own checks.
- **lens-reviewer.** Started by `lens`, one per angle. Reports `TARGET`, `STANDING IN FOR`, `CHECKS RUN`, findings with what they experience and evidence, `NOTHING FOUND FOR`, `NOT CHECKED`.
- **architect.** Counts imports and fan-in, names boundaries that exist and are missing, gives two or three options (benefit, cost, when it is wrong; "leave it as it is" when that is right) and one recommendation tied to the intent. A bug in a function goes to `skeptic`.
- **designer.** Hierarchy, spacing, consistency, states, computed contrast, focus, responsiveness, from the source and any screenshot you give it. It says what it saw and what it did not (`SEEN`, `NOT SEEN`). It does not start a browser. It answers `NOT A UI` for a target with none, and does not review the task flow (that is `lens` UX).
- **tester.** Runs the tests once in your project, then makes at most six small mutants (flip a comparison, drop a branch) in a **temporary copy**, never in your project, and lists which ones no test caught, with a test to add for each. If the tests cannot run in a copy, it says so and stops. The cap is an instruction, not enforced.

## Scripts (called by the skills)

| Script | Does | Notes |
|---|---|---|
| `scaffold.sh <dir> files \| guardrails` | copies templates into a project, never overwrites | `--profile`, `--part`, `--verify-cmd`, `--merge-settings`, `--dry-run`; prints `add`, `skip`, `merge`, `update`, `ok`, `note`, `FAIL` per path; exit 1 on any `FAIL` |
| `explore.sh [--file F] [--template T] start \| baseline \| measure \| keep \| revert \| status` | the experiment referee. Optional Metric lines, each enforced: `Runs: N` (no fewer runs), `Noise: P%` (a gain must beat it), `Correctness: \`cmd\`` (must pass to keep), `Evidence: required` (keep needs `--evidence FILE`) | `EXPLORE_TIMEOUT` seconds per measurement (default 600); `baseline` and `measure` print `SPREAD=` |
| `goal.sh start \| status \| stop` | state for the goal loop | `DEV_HARNESS_STATE_DIR` moves the state; `GOAL_CHECK_TIMEOUT` seconds per check (default 120) |
| `ax-check.sh [dir]` | facts for the AX reviewer: router length, routed paths exist, hooks executable, `settings.json` valid, placeholders, profile, intent status | `PASS`, `WARN`, `FAIL` lines, exit 1 on any `FAIL`; reads files only |
| `showcase-facts.sh [dir]` | facts for `showcase`: history, most-changed files, tests, README headings, commands, intent, measured gains, lessons | `FACT` lines; reads files and git history only |
| `forge.sh check \| install \| use \| status \| list \| promote` | the quality bar for new parts and their life cycle: checks a part folder (spec, files by type, tests that pass and fail without the part), installs it into the project, counts real uses, marks it proven (3 uses), promotes it into a marketplace clone | `FORGE_TEST_TIMEOUT` seconds per test (default 300); `install`, `status` and `promote` ask in a project with guardrails |
| `tasks.sh new \| check \| overlap \| index \| active \| worktree` | task cards in `docs/tasks/`: writes cards, checks fields, dependencies and the INDEX, fails when two not-done cards overlap in scope without a dependency, keeps the active card per worktree, makes a worktree per card | `TASKS_ROOT` sets the project; `PASS`, `WARN`, `FAIL` lines, exit 1 on any `FAIL`. Overlap compares glob patterns, not existing files |

## dev-harness-perf (a second plugin in the marketplace)

Install with `/plugin install dev-harness-perf@claude-harness`; it depends on dev-harness. Each part has a filled spec in `plugins/dev-harness-perf/parts/<name>/spec.md` that passes `forge.sh check`.

| Part | Type | What it does |
|---|---|---|
| `perf-loop` | skill, `/dev-harness-perf:perf-loop` | baseline with 5+ runs and a noise threshold from the measured spread, `profiler` evidence, one hypothesis and one change at a time, kept only if it beats the noise and the correctness check passes; logs `docs/perf.md`. Drives `explore.sh --file docs/perf.md` |
| `profiler` | agent, `dev-harness-perf:profiler` | the top hotspots of one command, each with evidence. Output: `STATUS:`, `COMMAND:`, `TOOL:`, `HOTSPOTS`, `EVIDENCE`, `HYPOTHESES`, `NOT CHECKED`. Tools `Read, Grep, Glob, Bash` |
| `perf-guard` | hook (Stop), installed per project with `/dev-harness:forge install` | blocks a stop once when the median of `PERF_RUNS` runs of `PERF_CMD` is worse than `PERF_BASELINE` by more than `PERF_MAX_REGRESSION_PCT` (`PERF_DIRECTION`). Keys in `.claude/hooks/harness.conf` |
