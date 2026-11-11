---
name: perf-guard
type: hook
status: experimental
uses: 0
event: Stop
matcher:
timeout: 300
---

# perf-guard

## Purpose
A performance gain from `/dev-harness-perf:perf-loop` slips back unnoticed: a later change makes the measured command slower, the unit tests still pass, and Claude reports the task as done. Text in `CLAUDE.md` ("keep it fast") does not stop that; a check on every stop does.

## Which type and why
A hook: "do not finish while the benchmark regresses past the agreed limit" is a rule that must never break, so code enforces it. Not a skill (it must run without anyone remembering it) and not an agent (the judge is a number, not an opinion).

## Trigger
The Stop event (no matcher), when `PERF_CMD` is set in `.claude/hooks/harness.conf` and there is something new to judge: uncommitted or untracked changes, or a HEAD other than the last one that passed (so a regression that was already committed is still caught). A clean tree at the HEAD that last passed, or no `PERF_CMD`: it does nothing.

## Inputs and outputs
Input: the Stop hook JSON (only `stop_hook_active` is read); the keys `PERF_CMD`, `PERF_BASELINE`, `PERF_MAX_REGRESSION_PCT` (default 10), `PERF_DIRECTION` (`lower` or `higher`, default lower) and `PERF_RUNS` (default 5), read through `harness-conf.sh`. Output: exit 0 (allowed, no output), or exit 2 with one of: `PERF REGRESSION: the median of N runs is M against the baseline B (P% worse; the limit is L%, D is better).` plus the runs; `PERF GUARD: the benchmark failed (exit N)`; `PERF GUARD: ... printed no number`; `PERF GUARD: ... did not finish N runs within T s`; `PERF GUARD DID NOT RUN: invalid settings ...` or `... harness-conf.sh ... is missing`.

## Method or loop
1. If `stop_hook_active` is true, allow (the loop guard: it blocks at most once in a row).
2. Read the settings; validate them (a bad value is reported, not ignored).
3. Skip only a clean tree at the HEAD that last passed (remembered in `.git/dev-harness-perf-guard.ok`).
4. Run `PERF_CMD` `PERF_RUNS` times within one time limit, each in its own process group; take the last number of the last output line of each run.
5. Take the median; compute how much worse it is than the baseline in the stated direction, in percent of the baseline; block if it is above the limit.

## Unacceptable
- Blocking without saying why and what to do (every block names the numbers and the next step).
- Judging from a single run, or from the mean (one outlier must not decide).
- Changing `PERF_BASELINE` or the threshold itself: only the user edits `harness.conf`.
- Running past its registered timeout and being cut off silently (it has its own limit, below 300 s).
- Blocking twice in a row on the same stop (the loop guard).

## Success check
`tests/guard.sh` exits 0: a +20% regression blocks with exit 2 and names median, baseline and percent; +5% passes; the higher-is-better direction works both ways; one outlier run does not decide; bad settings, a failing benchmark, no number, a time-out and a missing parser each block with a message; a regression that was committed (clean tree, new HEAD) blocks; a clean tree at the HEAD that last passed and an empty `PERF_CMD` do nothing. With the hook file emptied, the blocking cases fail.

## Tests
`tests/guard.sh` (18 cases, listed in Success check). It copies `files/perf-guard.sh` and the dev-harness `harness-conf.sh` (`tests/fixtures/`) into a temporary git repository and drives the hook with JSON on stdin.

## Budget
`PERF_RUNS` runs (default 5) within `DH_PERF_TIMEOUT` seconds (default 240) for all runs together; over the limit it blocks once with a message instead of being cut off. It blocks at most once per stop (the loop guard).
