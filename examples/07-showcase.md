# `showcase` on a small project

- Plugin version: 1.0.0
- Date: 2026-11-10
- Command: `/dev-harness:showcase tutor demo`
- How it was run: headless `claude -p` with `--plugin-dir`. A headless run cannot answer prompts or approve tools, so the confirmations are in the prompt and the tools are passed with `--allowedTools`. `claude -p` prints only Claude's final message, so text from earlier in the session is not shown (which is why a report can refer to something "above").
- Project: a toy Python word-count CLI with two tests and an `experiments.md` log that claims a 410 to 95 ms speed-up.

Claude ran the demo and could not reproduce the logged speed-up (the history does not contain the slow baseline), so it kept that number out of the README draft and listed it under what not to claim. It wrote no file and stopped at the question about the README.

Absolute paths were shortened (`<scratch>`, `~`). Nothing else was edited.

## What Claude reported

````
I've finished the checks. One result matters for the pitch: the "use Counter" commit changes no files, and the original commit already used Counter. I'm writing up the proposal now.

```
PICK: Correct punctuation/case handling, shown by the CLI and its two unit tests. The performance claim is not ready to show.
FOR: the course tutor grading a small CLI assignment (from docs/intent.md, status: decided)

WHY:
The tutor "cares about: correct counts, tests that mean something, and evidence the student measured performance". The student asked to "push hardest on" (1) "Correct handling of punctuation and case" and (2) "A measured performance improvement".
Candidate 2, the 410 -> 95 ms speed-up, lost. The only recorded evidence is prose (docs/experiments.md and a commit subject). The history does not back it up. Commit 3db7318 "use Counter" has an empty diff, and the first commit 93af857 already uses Counter. I could not rebuild a 410 ms baseline.
Candidate 3, the test suite, lost. It has only 2 tests, and neither covers an edge case.

DEMO (at most 6 steps, about 60 seconds):
1. python3 -m unittest discover -s tests
   You see: "Ran 2 tests in 0.000s  OK"
2. echo "Hello, hello! HELLO. World? to be or not to be" | python3 wc.py 3
   You see:
      3  hello
      2  to
      2  be
   (Hello, hello! and HELLO. are counted as one word.)
3. printf 'Don'"'"'t stop -- "quoted" word... [bracket] “smart” smart\n' | python3 wc.py 10
   You see: don't is kept whole, and "quoted" and word... lose their punctuation. But "--" counts as a word, "[bracket]" keeps its brackets, and "“smart”" is a different word from "smart".

README SECTION (draft, not written yet):
## Usage
Count the most frequent words, ignoring case and surrounding punctuation:

    echo "Hello, hello! HELLO. World?" | python3 wc.py 1
    #    3  hello

Run the tests: `python3 -m unittest discover -s tests`

Words are lowercased and have `. , ; : ! ? " ' ( )` stripped from both ends, so `don't` stays whole. Known limits: `--`, `[...]` and curly quotes are not stripped.

TALKING POINTS:
1. Case and trailing punctuation are folded, so "Hello, hello! HELLO." counts as 3 × hello. [VERIFIED: the step 2 command]
2. Apostrophes inside a word survive, so "don't" stays one word. [VERIFIED: the step 3 command]
3. The two unit tests pass and cover stripping and ordering. [VERIFIED: python3 -m unittest discover -s tests; READ: tests/test_wc.py:6-9]
4. The punctuation set is a fixed list applied to the ends of each word. [READ: wc.py:5]
5. A benchmark script exists and runs. On this machine it prints 22-23 ms for the current code. [VERIFIED: python3 bench.py, 3 runs, all 23]

DO NOT CLAIM:
- "410 -> 95 ms, 4.3x faster". The numbers come only from prose (docs/experiments.md, the commit subject). Commit 3db7318 is empty. The original code at 93af857 already uses Counter. I ran that original code through the bench workload and got 22, 22 and 26 ms. So no Counter-versus-baseline gain can be reproduced from this repo's history. The "list-based" 410 ms baseline and the reverted groupby variant are not in git. Also, 23 ms here is not 95 ms, so the figures were taken on another machine or setup.
- "Handles all punctuation". Verified counter-examples: "--" is counted as a word, "[bracket]" keeps its brackets, and “smart” (curly quotes) differs from smart.
- "Well tested". There are 2 tests, and none cover those edge cases, empty input, or a missing or non-numeric N.

NOT VERIFIED:
- The 410 ms baseline and the groupby variant. They are not in the repo, so they can't be run.
- Behaviour on empty input, bad arguments, or non-English text. I did not run these.
- The demo left two untracked files: __pycache__/wc.cpython-314.pyc and tests/__pycache__/test_wc.cpython-314.pyc. I wrote no project file myself.
```

What would make the performance story strong is to re-measure it honestly. Keep the old list-based implementation as a committed variant, run `bench.py` against both, and log the real numbers. Two or three tests for the failing edge cases would help too.

Do you want me to add the README section above? It has no usage section, so nothing would be overwritten. It would be the only change, and I'll show the `git diff` afterwards.
````

