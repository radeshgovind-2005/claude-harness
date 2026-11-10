# `goal`: a failing test suite fixed in one round

- Plugin version: 1.0.0
- Date: 2026-11-10
- Command: `/dev-harness:goal python3 -m unittest discover -s tests passes (5 rounds, 10 minutes)`
- How it was run: headless `claude -p` with `--plugin-dir`. A headless run cannot answer prompts or approve tools, so the confirmations are in the prompt and the tools are passed with `--allowedTools`.
- Project: a toy Python project with two bugs in `stats.py` and three unit tests.

The Stop hook ran the check after Claude tried to finish and found it passing, so the loop ended after one round. Claude's report lists what was not verified. There was no `docs/progress.md`, so no checkpoint was written.

Absolute paths were shortened (`<scratch>`, `~`). Nothing else was edited.

## What Claude reported

```
The goal was met: the hook ran `python3 -m unittest discover -s tests` and it exited 0 after 1 round and under 1 minute. `docs/progress.md` doesn't exist, so I didn't add a checkpoint there.

**Done**
- `stats.py`, `mean`: removed the stray `- 1`, so it now returns `sum(xs) / len(xs)`.
- `stats.py`, `median`: for even-length lists it now returns the average of the two middle values. Odd-length lists behave as before.
- I left the tests and the check command alone.

**Verified**
- Before the change, the check exited 1 with two failures: `test_mean` (1.0 ≠ 2) and `test_median_even` (3 ≠ 2.5).
- After the change, the check ran 3 tests, OK, exit 0. I ran it myself, and the stop hook then ran it and confirmed.
- I ran nothing else.

**Not verified**
- Empty lists: `mean([])` raises a division-by-zero error and `median([])` raises an index error. No test covers this and I didn't change it.
- Inputs the tests don't use, such as a single element, negative numbers, floats, or unsorted even-length lists. The code handles these by inspection but no test exercises them.
- No type checking, linting, or anything outside `tests/` was run.
```


## The fix

```
$ git diff -- stats.py
diff --git a/stats.py b/stats.py
index 85bcd50..5c5ffc7 100644
--- a/stats.py
+++ b/stats.py
@@ -1,7 +1,9 @@
 def mean(xs):
-    return sum(xs) / len(xs) - 1
+    return sum(xs) / len(xs)
 
 def median(xs):
     xs = sorted(xs)
     n = len(xs)
+    if n % 2 == 0:
+        return (xs[n // 2 - 1] + xs[n // 2]) / 2
     return xs[n // 2]
```

