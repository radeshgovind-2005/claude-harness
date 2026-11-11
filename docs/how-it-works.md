# How it works

## Three layers

| Layer | Who builds it | What it is |
|---|---|---|
| Generic harness | Anthropic | Claude Code: the agent loop, tools, permissions, subagents |
| Practice layer | this plugin | how to work well on any project: intent, memory, guardrails, review, lessons, loops |
| Domain layer | you, per project | domain facts, checks and tools. The plugin shows how to build them; it ships none |

The plugin keeps to what stays useful as models improve: your intent, your project's facts, and real checks. It avoids long instructions on how to code.

## Code enforces, text advises

A rule that must never break is a hook, a test or CI, not a line in `CLAUDE.md`. This table says which is which.

| Rule | Enforced by | Where |
|---|---|---|
| No force push, `--no-verify` (and `git commit -n`), `rm -rf /`, `curl \| sh`, reading `.env`, changing `core.hooksPath` | `guard-bash.sh` (exit 2) and `deny` rules | in a project that opted in |
| Risky commands ask first: `reset --hard`, `git clean -f`, `DROP` / `TRUNCATE`, shell writes to `.claude/hooks` or `harness.conf` | `guard-bash.sh` (ask) | same |
| No edits to `.env*`, keys, lockfiles, `.claude/hooks/`, `.claude/settings.json`; none on `main` or `master` when `BLOCK_MAIN=1` | `protect-paths.sh` (exit 2) | same |
| The project's formatter runs after an edit; it never blocks | `format.sh` | same |
| Claude cannot stop while `VERIFY_CMD` fails or runs past 240 s (once; `stop_hook_active` prevents a loop). It runs only when the git tree has uncommitted or untracked changes | `verify.sh` | same |
| The hooks still trip | `test-hooks.sh`, and the `dev-harness-hooks` CI workflow | same |
| `docs/intent.md` stays the only editable file while `status: discovering` | `discover-lock.sh`, a skill hook | the session that ran `discover` |
| `goal` ends on its check or its budget | `goal-stop.sh`, a skill hook | the session that ran `goal` |
| `explore` keeps a variant only if the number improves | `explore.sh` | when the skill runs it |
| The plugin ships no hooks, no agent has an edit tool, `help` matches reality, the CHANGELOG matches the version | `tests/validate.sh` and CI | this repository |
| Review, "think first", "fail loud", the working principles | text in `CLAUDE.md` and the skills | advice only |

Local hooks stop mistakes, not a deliberate bypass: a person (or Claude, through a shell trick the guard does not know) can get around them. Turn on branch protection and required CI on your Git host. The `guard-bash.sh` command list is best-effort, not a sandbox.

## Profiles

A profile is a `harness.conf` plus a matching `settings.json`, chosen once.

| Key | Meaning |
|---|---|
| `PROFILE` | `prototype`, `product` or `assignment` |
| `BLOCK_MAIN` | `1` blocks edits, commits and pushes on `main` / `master`. Only an explicit `0` lifts it; a typo or an empty value keeps it on |
| `VERIFY_CMD` | runs when Claude stops, if `git status --porcelain` shows uncommitted or untracked changes (always, outside a git repository); a clean tree is skipped. Empty means off. Keep it under 60 seconds: `verify.sh` stops it after 240 s and blocks the stop once with "TIMED OUT". No profile ships a command: `new` and `add` propose one, and `scaffold.sh` detects one from `package.json`, a `Makefile`, `Cargo.toml`, `go.mod` or `pyproject.toml` when none is given |

The hooks parse this file, they never source it. One parser, `.claude/hooks/harness-conf.sh`, is shared by the hooks and the `dev-harness-hooks` CI workflow, so CI reads quotes, spaces and CRLF exactly as the hooks do; without it the two guards block everything (fail closed) and `verify.sh` says the work is not verified. Whether `git push` asks first is not in this file: it is the `ask` list in `.claude/settings.json`, so changing profiles after setup means editing both files. Claude's edits to it are blocked, and shell commands that look like they change it ask you first.

## Why the strict hooks are not in the plugin

A plugin stays on in every project where it is enabled. A rule like "block edits on `main`" must not fire in a project that did not choose it. So the plugin ships skills and agents only (`claude plugin details dev-harness` shows `Hooks (0)`). The hooks are copied into a project by `new` or `add guardrails`, from `plugins/dev-harness/templates/`. Two skills register a hook for the rest of the session in which they run, and each does nothing unless its own state says it is active.

## Never grade your own work

`skeptic`, `lens-reviewer`, `architect`, `designer` and `tester` start with fresh context and are given the goal and the thing to judge, not your reasoning. A test that ran beats an agent that agrees: every agent is told to run real checks when it can and to put what it could not verify under `NOT CHECKED`. `lens` counts the reviewers it started against the reports that came back and never fills in a missing angle itself.

## Platforms

- **macOS and Linux:** tested. The scripts run on bash 3.2 (the macOS default); CI runs the fast suites and the project hook self-test on Ubuntu and macOS; the scaffold suite runs on Ubuntu only.
- **Windows:** not tested. `.gitattributes` keeps LF line endings so a checkout cannot break the shebangs, but the hooks need `bash` and `jq`; use Git Bash or WSL.
- **Needs:** `bash`, `git`, `jq`. `explore` and `goal` also use `awk` and `mktemp`. If `jq` is missing, the guard hooks block every command and say how to install it (they fail closed); `format.sh` just skips formatting.

## Known limits

- **The discover lock covers file-edit tools only**, not shell commands, and lives only in the session where `discover` ran. After `--continue` or in a new session it is not registered again.
- **The `goal` hook is not registered again after `--continue`** (observed: the round counter did not move). `goal.sh status` may show a stale goal; `goal.sh stop` clears it. The hook stays registered after the goal ends but does nothing. Two simultaneous Stop events can count as one round. A check that detaches itself (`setsid`) escapes the process-group kill on timeout. The state file is outside the project but not tamper-proof against shell commands. There is no token budget, because hooks get no token count.
- **Claude Code ends a turn after 8 consecutive stop-hook blocks** with no tool call in between. A loop that does real work resets the count. In one test run with a goal that could not pass and a model told to answer "ok" with no tool, the session ended on its own after the hook had counted 9 Stop events, and the goal stayed `active` (see `examples/05-goal-edge-cases.md`). That is two runs on one machine, not a guarantee of the exact count.
- **The reviewer agents have no edit tools, but their `Bash` can still write.** They are told not to. `lens` compares `git status` before and after. A test run can leave caches.
- **`tester` mutates a temporary copy**, so a project whose tests need ignored files (`node_modules`, `.env`), a database or the network may not run there; it then reports `NOT CHECKED`. Its cap of six mutants is only an instruction.
- **`designer` has no browser.** It judges source and the screenshots you give it, and says so.
- **`showcase` verifies only what it can run safely.** Steps that need a service, a key or a display are `UNVERIFIED`.
- **`explore` trusts the metric command.** It cannot tell a gamed metric from a real gain; the skill forbids changing the measurement. `keep` needs a git identity (`user.name`, `user.email`). `explore` needs git.
- **`guard-bash.sh` is a best-effort list**, not a sandbox. `git commit -n` (and `-nm`, `-anm`, `-m x -n`) is blocked. Quoted text is ignored first, so `-m "refactor -nested"` passes; a commit message that spans several lines and has a word like ` -n` outside quotes can still trigger it (reword it).
- **`showcase-facts.sh`:** a file name with a newline or a double quote is skipped from the churn list; README headings are read from Markdown only; `git log` over a very large history is not capped.
- **Still open at 1.0.0:** a real interactive `discover` conversation on a real idea has not been run by the author (the three-turn run in `examples/` used prepared answers); every example is a toy project and a single headless run; `designer` has never been given a rendered screenshot; native Windows.
