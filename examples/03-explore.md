# `explore`: one measured variant kept

- Plugin version: 1.0.0
- Date: 2026-11-10
- Command: `/dev-harness:explore reduce the milliseconds that python3 bench.py prints (lower is better, target 50) ...`
- How it was run: headless `claude -p` with `--plugin-dir`. A headless run cannot answer prompts or approve tools, so the confirmations are in the prompt and the tools are passed with `--allowedTools`. `claude -p` prints only Claude's final message, so text from earlier in the session is not shown (which is why a report can refer to something "above").
- Project: a toy Python project: `dedupe()` with a quadratic list scan, and a `bench.py` that prints a number.

The script measured the baseline, Claude made one change, the script saw the target met and stopped the loop, so the bold second variant was never tried. The log, the commit and the branch are the script's, not Claude's claims. The report also lists what is not verified (a single run, unhashable items, how well the metric fits real inputs).

Absolute paths were shortened (`<scratch>`, `~`). Nothing else was edited.

## What Claude reported

```
The loop stopped after one variant because the target was met. `python3 bench.py` went from 434 ms to 0 ms, against a target of 50.

I did not try the bold `dict.fromkeys` variant. The script reported `STOP=yes` (target reached), and the rules say to stop then.

| Variant | Value | Result | Why |
|---|---|---|---|
| baseline | 434 | — | `x not in out` scans a list, so the function is quadratic |
| `seen` set instead of list membership | 0 | kept | Set lookups are O(1), so the function is linear |

- **Branch:** `explore/dedupe-speed`. Commit `60c079d` holds the change, and the working tree is clean. I did not merge it. Say if you want me to.
- **Behaviour check:** `dedupe([3,1,3,2,1])` returns `[3, 1, 2]`, so first-seen order is preserved.

**Not verified:**
- **Noise:** each measurement was a single run. 0 ms is below the resolution of `int(ms)`, so the real time is somewhere between 0 and 1 ms. The margin over the target is large either way.
- **Hashable items:** the new `dedupe` raises `TypeError` on unhashable items such as lists or dicts. The original accepted them. If callers pass those, this change is a regression.
- **Metric fit:** `bench.py` only exercises 60,000 ints with 3,000 distinct values. I did not check that this matches your real inputs.
- **Tests:** the repo has no tests, so only that one manual check covers behaviour.
```


## What is in the project afterwards

```
$ git log --oneline
60c079d explore: seen set instead of list membership (434 -> 0)
990a101 dedupe

$ cat docs/experiments.md (the log section)
## Metric

The script reads these lines. Keep the labels.

- Name: `dedupe_ms`
- Measured by: `python3 bench.py` (run from the project root; the last number on its last output line is the value)
- Direction: lower is better
- Target: 50

## Log

| Date | Variant (one change) | Metric | Result | Kept or reverted | Note |
|---|---|---|---|---|---|
| 2026-11-10 | baseline | `434` | — | baseline | Starting point |
| 2026-11-10 | seen set instead of list membership | `0` | -434 | kept | O(1) set lookup replaces O(n) list scan; quadratic to linear. Requires hashable items |

$ cat dedupe.py
def dedupe(items):
    seen = set()
    out = []
    for x in items:
        if x not in seen:
            seen.add(x)
            out.append(x)
    return out
```

