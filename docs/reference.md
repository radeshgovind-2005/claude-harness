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
- **Input:** `<guardrails|reviewer|lessons|memory|workflows|rules|all> [--profile P]`.

| Part | Adds |
|---|---|
| `memory` | `CLAUDE.md` router, `docs/INDEX.md`, architecture, conventions, lessons, progress, experiments |
| `lessons` | `docs/lessons.md` |
| `reviewer` | `docs/agents/INDEX.md` |
| `workflows` | `docs/workflow.md`, `docs/agents/first-workflow.md` |
| `rules` | `.claude/rules/` |
| `guardrails` | hooks, `harness.conf`, `.claude/settings.json`, CI workflow, then the hook self-test |
| `all` | every part; guardrails last |

- **Needs a profile:** `memory`, `guardrails`, `all`. It reads `harness.conf`, then `CLAUDE.md`, then asks.
- **Never:** overwrites, or switches a project's profile silently. `--part memory` prints a `note` for routed files that another part adds.

### lesson
- **Use when:** you corrected Claude, or discovery missed something that mattered.
- **Input:** what went wrong (or the latest correction).
- **Does:** updates a similar lesson in place instead of adding a duplicate; tags lessons about discovery `[discover]`.
- **Writes:** `docs/lessons.md`. **Asks before** promoting a rule to `CLAUDE.md`, and before deleting a lesson.

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
| `explore.sh start \| baseline \| measure \| keep \| revert \| status` | the experiment referee | `EXPLORE_TIMEOUT` seconds per measurement (default 600) |
| `goal.sh start \| status \| stop` | state for the goal loop | `DEV_HARNESS_STATE_DIR` moves the state; `GOAL_CHECK_TIMEOUT` seconds per check (default 120) |
| `ax-check.sh [dir]` | facts for the AX reviewer: router length, routed paths exist, hooks executable, `settings.json` valid, placeholders, profile, intent status | `PASS`, `WARN`, `FAIL` lines, exit 1 on any `FAIL`; reads files only |
| `showcase-facts.sh [dir]` | facts for `showcase`: history, most-changed files, tests, README headings, commands, intent, measured gains, lessons | `FACT` lines; reads files and git history only |
