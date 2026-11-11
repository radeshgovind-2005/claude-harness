# `forge` and `dev-harness-perf`: a lesson becomes a hook; a performance loop

- Plugin version: 1.2.0
- Pack version: dev-harness-perf 0.1.0
- Date: 2026-11-11
- Command: `/dev-harness:forge`, then `forge.sh check`, the `guard-bash.sh` ask and `forge.sh install`; `/dev-harness-perf:perf-loop`
- How it was run: headless `claude -p` with `--plugin-dir` for both plugins, in throwaway projects with dev-harness guardrails (prototype profile). A headless run cannot answer prompts or approve tools: the "yes" was in the prompt. **What a headless run could not do is marked below.** Claude Code treats `.claude/` as a protected folder, so the headless `forge` run could not write the part to `.claude/forge/` and stopped at the proposal (as it should: it did not write the files elsewhere). Section 2 is the part that the proposal described, **written by hand** for this example, then put through the real scripts. Absolute paths are shortened. `claude -p` prints only Claude's final message.
- Projects: (1) a one-file app with `CHANGELOG.md` and a lesson in `docs/lessons.md` recorded twice; (2) a toy `stats.py` whose `variance()` is O(n²), with two unit tests.

## 1. `/dev-harness:forge` proposes a part (headless)

Prompt: `/dev-harness:forge  The lesson in docs/lessons.md came back a second time. I cannot answer questions in this run: propose the part, and treat this message as my yes to build it. Write it in .claude/forge/ only, run forge.sh check until it passes, then run forge.sh install (I approve the install).`

```
I haven't built or installed anything. The permission system refused every write under `.claude/forge/`, so the part doesn't exist yet. The error was "requested permissions to edit … which is a sensitive file", and the run is non-interactive, so there was nobody to grant it. I didn't try to get around it, for example by writing the files elsewhere and copying them in with Bash. `forge.sh check` and `forge.sh install` haven't run either. I also couldn't read `forge.sh` (outside the project, read not granted), so I haven't seen its exact file rules for a hook.

## Proposal

- **Gap:** `docs/lessons.md` (2026-11-11) records twice that a commit changed `app.py` without `CHANGELOG.md`, so the release notes missed both changes. No existing part or lesson covers it, and `docs/parts.md` has no parts yet.
- **Type: hook, named `changelog-with-app`.** The rule must never break, and a hook enforces it where the `CLAUDE.md` line it already came back past would only advise. A rule would be text again, and a skill depends on someone remembering to run it.
- **What it does:** a `PreToolUse` hook on `Bash` that catches `git commit`. It exits 2 with a how-to-fix message when `app.py` is in the commit but `CHANGELOG.md` is not. With `-a` or `--all`, it also counts modified tracked files.
- **Install entry:** a `PreToolUse` / `Bash` entry in `.claude/settings.json` with a 10 s timeout, next to `guard-bash.sh`. `forge.sh install` would write it, and `guard-bash.sh` would ask you first.
- **Risks:**
  - It reads the staged files before the command runs, so `git add … && git commit` in one command is judged on the old staging area.
  - `git commit app.py` with a pathspec isn't followed.
  - Quoted text such as `echo "git commit"` is ignored, as in `guard-bash.sh`.
  - It needs `jq` and blocks if `jq` is missing.
- **Tests, in a temporary git repo:**
  - `app.py` staged without the changelog is blocked (exit 2, message names `CHANGELOG.md`).
  - Both files staged is allowed.
  - A commit that doesn't touch `app.py` is allowed.
  - A non-commit command is allowed.
  - `-am` with an unstaged `app.py` change is blocked.
  - `echo "git commit"` is allowed.
  - Emptying the hook script makes the block tests fail, which is the check `forge.sh check` needs.

## To continue

Either allow writes to `.claude/forge/` for this run, or run `/dev-harness:forge` again in an interactive session. I'll then build `spec.md`, `files/` and `tests/`, run `forge.sh check` until it passes, and run `forge.sh install`. That install still asks you at the `guard-bash.sh` prompt.
```

## 2. The proposed part through the real scripts (part written by hand; commands and output as run)

`.claude/forge/changelog-with-app/` holds `spec.md` (every section filled), `files/changelog-with-app.sh` (a PreToolUse hook on Bash) and `tests/commit.sh` (6 cases in a temporary repository).

```
$ forge.sh check .claude/forge/changelog-with-app
PASS  spec frontmatter — changelog-with-app (hook, experimental, uses 0)
PASS  spec sections — all 9 filled
PASS  files — one executable hook script
PASS  tests — 1 test(s) pass
PASS  tests fail without the part — with files/ emptied, a test fails
SUMMARY pass=5 warn=0 fail=0
```

Claude asking to install it meets the project's `guard-bash.sh`, which asks the user (this is the approval gate; a headless run cannot answer it, so it is refused there):

```
$ echo '{"tool_name":"Bash","tool_input":{"command":"bash .../forge.sh install .claude/forge/changelog-with-app"}}' | .claude/hooks/guard-bash.sh
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "This installs, promotes or changes the status of a harness part (forge.sh). Only the user approves that."
  }
}
```

After the user's yes:

```
$ forge.sh install .claude/forge/changelog-with-app
PASS  spec frontmatter — changelog-with-app (hook, experimental, uses 0)
PASS  spec sections — all 9 filled
PASS  files — one executable hook script
PASS  tests — 1 test(s) pass
PASS  tests fail without the part — with files/ emptied, a test fails
PASS  installed — .claude/hooks/changelog-with-app.sh, registered for PreToolUse (Bash) in .claude/settings.json
PASS  registry — docs/parts.md
SUMMARY pass=7 warn=0 fail=0
```

`.claude/settings.json` now has a third PreToolUse entry (after the dev-harness guards):

```json
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/changelog-with-app.sh",
      "timeout": 10
    }
  ]
}
```

`docs/parts.md`:

```
<!-- parts:index:start -->
| part | type | status | uses | installed | spec |
|---|---|---|---|---|---|
| changelog-with-app | hook | experimental | 0 | yes | `.claude/forge/changelog-with-app/spec.md` |
<!-- parts:index:end -->
```

The installed hook on the mistake from the lesson (`app.py` staged, no changelog):

```
$ echo '{"tool_input":{"command":"git commit -m tweak"}}' | .claude/hooks/changelog-with-app.sh
BLOCKED: this commit changes app.py without CHANGELOG.md. Instead: add a line under the newest version in CHANGELOG.md, stage it, and commit again.
exit=2
$ bash .claude/hooks/test-hooks.sh | tail -1
Result: 295 passed, 0 failed
```

## 3. `/dev-harness-perf:perf-loop` (headless)

Prompt: `/dev-harness-perf:perf-loop make variance() in stats.py faster. Measured by `python3 bench.py` (prints milliseconds; lower is better), target none, correctness `python3 -m unittest -q`, budget 2 variants. I cannot answer questions in this run: this message is my approval of these choices, of filling the Metric section of docs/perf.md, and of code changes in stats.py. Use the dev-harness-perf:profiler agent before each change.` Tools passed: `Edit, Write, Agent, Bash(python3 *), Bash(mktemp *)` and the plugin's `explore.sh`.

```
Variant 2 did not run. The profiler's second pass was denied permission to run its repeated timing and cProfile commands, so there is no profiler evidence for a second change, and the loop doesn't allow a change without it. I did not rerun those commands myself, since the denial was a refusal I shouldn't route around.

## Report

**Baseline, best, target:** The baseline was 915.7 ms (median of 5 runs, spread 5.02%, so I set Noise to 6%). The best is 0.44 ms. There is no target.

| Variant | Result | Why |
|---|---|---|
| hoist `mean(xs)` out of the loop in `variance` | 915.7 → 0.44 ms, kept | `mean(xs)` was recomputed for each of the 4000 elements |
| second variant | not run | no profiler evidence |

**What the profiler showed:** Under cProfile, `mean()` was called 4000 times from `stats.py:8`, about 100% of cumulative time. That made the work O(n²), about 16M inner steps. The hypothesis held. The one-line fix in `stats.py` (`m = mean(xs)` before the loop) gave roughly a 2000x speedup.

**Correctness:** `explore.sh keep` accepted the variant, so the check `python3 -m unittest -q` passed. `docs/perf.md` has the full log, and the work is on branch `explore/variance-speed`.

**Remaining work:** After the first variant, the profiler's second pass could only read the code. Its untested guesses are that `mean`'s per-element slice plus `sum` call (`stats.py:3-4`) is now the larger loop, and that `sum(xs) / len(xs)` would speed it up. To continue, grant the profiler permission to run the timeit and cProfile commands, then rerun the loop for variant 2. The budget allows one more variant.

**NOT VERIFIED:**
- **Run-to-run noise:** the 0.44 ms result has a 31.8% spread across its 5 runs (0.38–0.52 ms). The baseline's 5.02% spread would not have caught this, so the improvement is real but the exact figure is imprecise.
- **Single-call timing:** `bench.py` times one cold call.
- **Other conditions:** other input sizes, machines and Python versions were not measured.

**Keeping the gain:** I can offer the `perf-guard` hook, installed with `/dev-harness:forge install <repo>/plugins/dev-harness-perf/parts/perf-guard`. It would need the `PERF_*` settings in `.claude/hooks/harness.conf`, which only you edit. With the noise level above, a benchmark with more repeats would be needed first.
```

`docs/perf.md` afterwards (Metric and Log):

```markdown
## Metric

- Name: variance() of 4000 ints, wall time in milliseconds
- Measured by: `python3 bench.py`
- Direction: lower is better
- Target: none
- Runs: 5
- Noise: 6%
- Correctness: `python3 -m unittest -q`
- Evidence: required

## Log

| Date | Variant | Metric | Result | Kept or reverted | Note |
|---|---|---|---|---|---|
| 2026-11-11 | baseline | `915.7` | — | baseline | Starting point |
| 2026-11-11 | hoist mean(xs) out of the loop | `0.44` | -915.26 | kept | mean(xs) recomputed per element is ~100% of time (O(n^2)); computing once should cut it ~4000x; evidence: <tmp>/perf-variance-speed-1.txt |
```

## 4. The same loop with a broken correctness check (an earlier run)

In an earlier run the test folder had no `__init__.py`, so the agreed `python3 -m unittest -q` ran 0 tests and exited 5. `explore.sh keep` refused the 800x-faster variant, and the loop stopped instead of changing the check:

```
I stopped the loop before the first variant was kept. The agreed correctness command, `python3 -m unittest -q`, runs 0 tests in this repo, so the referee refused the keep.

**Cause.** `tests/` has no `__init__.py`, so `unittest` discovery finds nothing and exits 5 ("NO TESTS RAN"). Running the tests by name, `python3 -m unittest -q tests.test_stats`, runs 2 tests and both pass on the changed code. The agreed command was never a working check, even before my change.

**Why I stopped.** The fix would be adding `tests/__init__.py` or changing the Correctness command. You approved changes to `stats.py` only, and the loop rules forbid changing the tests or the check mid-loop. I also didn't run `revert`, because the change isn't wrong.

**Where things stand.** The work is on branch `explore/variance-speed`.

```
