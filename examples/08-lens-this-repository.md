# `lens` run on this repository, before the docs were written

- Plugin version: 0.5.0
- Date: 2026-11-10
- Command: `/dev-harness:lens README.md and the install and fork path of this repository ...`
- How it was run: headless `claude -p` with `--plugin-dir`. A headless run cannot answer prompts or approve tools, so the confirmations are in the prompt and the tools are passed with `--allowedTools`.
- Project: this repository, on the `build/v1.0.0` branch right after `CLAUDE.md` was added and before the docs existed (the plugin was still at 0.5.0).

The findings were real and are why the README now starts with the install, why `docs/` has five new pages, and why `docs/contributing.md` lists every file that names the owner. The lens skill itself is the same in 1.0.0.

Absolute paths were shortened (`<scratch>`, `~`). Nothing else was edited.

## What Claude reported

```
All three reviewers (UX, DX, AX) are running in the background. I'll merge their reports when they come back, and I'm not guessing at any of their findings before then.

The UX reviewer has returned. DX and AX are still running, so I'm waiting for both before I merge and rank anything.

Two of three reviewers have returned (UX and AX). The DX reviewer is still running, so I'm holding the merge until its report arrives.

**3 of 3 reviewers returned** (UX, DX, AX), each in the fixed format. `ax-check`: pass=3 warn=4 fail=1. The fail is that four routed docs are missing.

The working tree was clean before and is still clean after, so the reviewers changed nothing in the project. The DX reviewer cloned the repo to a temp directory and wrote its test output to `/tmp/dx-*.out`, both outside the project. No `docs/intent.md` exists, so each reviewer stated its own assumption about the audience, and I could not rank anything against a stated priority. I dropped no findings; each had evidence.

## Top findings

1. **[high] `CLAUDE.md` routes to four docs that don't exist (AX, DX, UX).**
   - `CLAUDE.md:46-49` sends the reader to `docs/contributing.md`, `how-it-works.md`, `stability.md` and `reference.md`. `docs/` contains only `brief.md` and `progress.md`.
   - The first row is the "add a skill" route, so a forker or an agent has no guide for the main contributor task.
   - Nothing catches it: `validate.sh` has no check for `CLAUDE.md` routes, and nothing runs `ax-check.sh` on this repo.
   - Fix idea: write the docs, or mark them "planned for 1.0.0" until they exist. Add a `validate.sh` check that every backticked `docs/` route in `CLAUDE.md` exists.

2. **[medium] The fork instructions are incomplete (UX, DX).**
   - `README.md:123` says to change `owner` in `marketplace.json` and the URLs in `plugin.json`.
   - A fork would still print the original repo in `/dev-harness:help` (`skills/help/SKILL.md:62`) and in the README install commands (lines 76, 77, 85, 89, 92).
   - The README also doesn't say whether to rename the marketplace `name`, which is part of every `dev-harness@claude-harness` install command.
   - Fix idea: list every place the owner appears, or give a `grep -rn radeshgovind-2005` step.

3. **[medium] The "Develop or fork" section gives one command out of several (DX, UX).**
   - `README.md:111-123` shows only `validate.sh` and `--plugin-dir`.
   - CI runs six suites, and `CLAUDE.md` makes "run the area suite plus shellcheck" the Definition of Done.
   - The README says nothing about needing `jq`, the `claude` CLI and shellcheck, about running tests with `/bin/bash` (bash 3.2), or that `scaffold-test.sh` takes about 4 minutes.
   - The README never mentions `CLAUDE.md`.
   - Fix idea: add a short Develop block with the tools, the suites, and a pointer to `CLAUDE.md`.

4. **[medium] A new session can't resume the v1.0.0 work from `docs/progress.md` alone (AX).**
   - The latest checkpoint is v0.5.0, but the branch is `build/v1.0.0`. The last commit (`f3c7c7c`, housekeeping) isn't recorded.
   - `progress.md:41` and `:189` still say "BRIEF section 14" and "BRIEF.md", although the file moved to `docs/brief.md`.
   - The release routine (branch, skeptic review, CHANGELOG, tag, checkpoint, merge) lives only in `docs/brief.md:188-200`.
   - The v0.4.0 tag points at a red-CI commit, and the `fix/ci-git-identity` branch is still around.
   - Fix idea: add a "Now / Next / Open decisions" block at the top of `progress.md`.

5. **[medium] The README and `CLAUDE.md` describe different project states (DX).**
   - The README says v0.5.0 and `plugin.json` says 0.5.0.
   - `CLAUDE.md` talks as if 1.x had shipped: "What must not change in 1.x → `docs/stability.md`".
   - Fix idea: land the docs and the version bump together, or mark the 1.x docs as coming with 1.0.0.

6. **[medium] Usage comes before install in the README (UX).**
   - "## Use" at `README.md:9` shows `/dev-harness:new …`, but "## Install" is at line 71.
   - Nothing at the top says you must install first or that Claude Code is required.
   - Fix idea: put a short install block above "Use".

7. **[medium] The risky rules in `CLAUDE.md` are text only (AX).**
   - Nothing backs "never commit secrets", "never push or delete without asking" or "run the suites before done".
   - The repo has no `.claude/` directory and no secret scan in CI, and `.gitignore` has no `.env`.
   - `CLAUDE.md:35` says `rm -rf "$VAR"` is "(blocked)". Nothing in the repo blocks it, so that must come from your global config.
   - Rules that are enforced: the CHANGELOG matching `plugin.json`, no edit tools in agents, and the skill-hook allowlist.
   - Fix idea: run `/dev-harness:add guardrails` on this repo, or add a `.claude/settings.json` that denies push, release and delete, plus a CI secret scan.

## Remaining findings

**UX**
- Jargon appears before it is explained: "router", "Stop hook", "profile", "skeptic", "lens". There is no "what you get" list after the first command. The skeptic paragraph at `README.md:43` is one dense block (`README.md:5,25,43,47-53`, low).
- `scaffold.sh` prints `FAIL project dir not found: ''` or `unknown option: --help` with no usage text. The usage is only in a header comment (low).

**DX**
- `DEV_HARNESS_STATE_DIR` and `GOAL_CHECK_TIMEOUT` are documented nowhere a contributor would look. A new test that calls `goal.sh` without setting the first would write into the real `~/.claude`. `goal-test.sh` handles it correctly (low).
- Adding a skill makes `validate.sh` fail until you add a row to the `help` skill. The message is clear, but the other registration steps (README row, CHANGELOG entry, a test) aren't written down (low).

**AX**
- Several `guard-bash.sh` block messages say what's forbidden but not what to do instead. Examples are `--no-verify`, force push, recursive delete, and piping a download into a shell (low).
- `CLAUDE.md` doesn't map each area to its suite, give suite runtimes (except 4 min for scaffold), or say what a passing result looks like (low).

**Nothing found for**
- Commands and tests: `validate.sh` passed 57/57 and every other suite passed in a fresh clone (`explore` 83, `lens` 36, `goal` 60, `showcase` 131, `scaffold` 195). `shellcheck -S warning` was clean.
- Install: the repo `radeshgovind-2005/claude-harness` is public. The marketplace and plugin names match the install commands, and `claude plugin validate --strict` passes.
- Errors and edge states: an unknown skill name in `help` gives a clear message and falls back to the full guide, and the "never overwrites" line covers existing projects.
- Docs that exist: `progress.md`, `brief.md` and `CHANGELOG.md` hold what the router promises, and `CLAUDE.md` is 60 lines.
- Layout: it matches the tree.
- Test hygiene: the tests use temp dirs and set a git identity.
- Definition of Done: it gives runnable commands, and CI runs the same six suites.

## Not checked

- **Install from GitHub:** nobody ran the real `claude plugin marketplace add` / `install`, because they write to `~/.claude`. `docs/progress.md` says it was verified in v0.5.0.
- **Session behavior:** nobody checked that `claude --plugin-dir` and `/reload-plugins` work, or the `new`, `discover`, `lens`, `goal` and `explore` flows.
- **Mutation:** nobody ran mutations, so whether each test would fail on a real break is unproven.
- **Platforms:** Linux, Windows/CRLF, and `validate.sh` without the `claude` CLI were not run. The DX reviewer ran macOS only.
- **Hooks:** the hooks' live behavior wasn't tested; only their messages were read.
- **Your global config:** whether it blocks `rm -rf "$VAR"`.
- **Not sent to the reviewers:** anything outside the README and the install/fork path, `docs/brief.md` beyond what was quoted, and any audience intent, because none is recorded.

Which of these do you want fixed? I changed nothing. Findings 1, 2 and 3 are quick text changes, 4 is a rewrite of the top of `progress.md`, and 7 changes how the repo is configured.
```

