---
name: explore
description: Experiment loop. Agree a metric, try one change at a time, measure it with a command, keep what improves and revert what does not, and log every variant in docs/experiments.md. Stops at the target or after 2 variants in a row with no improvement.
when_to_use: The user wants to make something measurably better and the best change is not obvious ("cut p95 latency", "raise the test pass rate", "shrink the bundle"). Not for a known fix: just make it.
argument-hint: "<what to improve and how it is measured>"
disable-model-invocation: true
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/explore.sh *) Edit(docs/experiments.md) Bash(git status *) Bash(git diff *) Bash(git log *)
---

Run an experiment loop. Input from the user: $ARGUMENTS

Bold, but measured: try variants, measure each one, keep what improves, revert what gets worse. A script decides keep or revert from a real number. You propose and implement variants; you never decide by argument.

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/explore.sh start <slug>
bash ${CLAUDE_PLUGIN_ROOT}/scripts/explore.sh baseline [--runs N]
bash ${CLAUDE_PLUGIN_ROOT}/scripts/explore.sh measure  [--runs N]
bash ${CLAUDE_PLUGIN_ROOT}/scripts/explore.sh keep   "<variant>" <value> ["<note>"]
bash ${CLAUDE_PLUGIN_ROOT}/scripts/explore.sh revert "<variant>" <value> ["<note>"]
bash ${CLAUDE_PLUGIN_ROOT}/scripts/explore.sh status
```

## 1. Agree the metric (ask, do not guess)

Work out with the user, in one round:
- **What to improve**, and the **command** that measures it. It must be re-runnable, print a number as the last number on its last line, and finish in under a minute or two. If no such command exists, write a small one first, then commit it (the working tree must be clean before `start`; ask before committing).
- **Direction**: higher or lower is better.
- **Target** (optional): the number at which to stop.
- **Noise**: if the same code gives different numbers, use `--runs 5` (median) for every measurement.
- **Scope**: which files may change.

Show the exact command and get an explicit yes (AskUserQuestion). The script runs it on every measurement.

## 2. Start and baseline

1. `explore.sh start <slug>` creates `docs/experiments.md` and, if you are on `main`, a branch `explore/<slug>`.
2. Fill the Metric section with Edit: Name, Measured by (command in backticks), Direction (`higher is better` or `lower is better`), Target (a number or `none`). Change nothing else in that file by hand: the script writes the log rows.
3. `explore.sh baseline [--runs N]`. If `explore.sh status` already says `STOP=yes` (the baseline meets the target), stop and say so.

## 3. Variants

Before the first variant, propose 2–3 ideas, one of them **bold** (more ambitious than the obvious change, still feasible, with its risk named). Let the user pick or adjust once; after that, work through the variants without asking again.

For each variant:
1. Make **one change** for one idea. Stay in the agreed scope.
2. `explore.sh measure [--runs N]` and read `VALUE=`.
3. If the value beats the best (`status` shows `BEST` and `DIRECTION`), run `keep "<variant>" <value> "<why it helped>"`. Otherwise run `revert "<variant>" <value> "<what you learned>"`. The script refuses a `keep` that is not an improvement. If it refuses, run `revert`.
4. `explore.sh status`. If `STOP=yes`, stop. Otherwise think about what the log has taught you and try the next variant. Do not repeat a variant that is already in `docs/experiments.md`.

## Rules

- **Never change the measurement to get a better number**: not the `Measured by` command, not the test data or the files it reads, not the Target. If the metric turns out to be wrong, stop and tell the user.
- Never edit the log table by hand, never use `git reset` or `git checkout` yourself to undo a variant: use `revert`.
- A failed measurement (`FAIL` from the script) is not a result. Fix the cause or stop; do not log a guess.
- If a command prints `FAIL`, say so in your report. Do not say the loop finished.
- State facts about the branch, commits and working tree from `git log --oneline` and `git status --short`, run just before you report, not from memory. `keep` commits the variant; a clean tree after it is expected.

## Report

When `STOP=yes` (or the user stops you), report: baseline → best and the change; the variants as a short table (kept or reverted, value, why); the stop reason; the branch name. Then say what is **not** verified: single-run noise, whether the metric reflects what the user cares about, and any variant you could not measure. Do not merge the branch; ask the user. If something instructive went wrong, suggest `/dev-harness:lesson`.
