---
name: perf-loop
type: skill
status: experimental
uses: 0
---

# perf-loop

## Purpose
Performance work done by intuition: a change is made because it "should be faster", measured once on a cold machine, kept although the tests broke or the difference is noise, and nothing records what was tried. The result is regressions that look like gains and gains nobody can repeat.

## Which type and why
A skill: a repeatable procedure with a loop (profile, hypothesis, change, measure, keep or revert) that the user starts on purpose. Not a hook (it is not a rule on every action) and not an agent (it changes code; the read-only judgment it needs is delegated to the `profiler` agent). The decisions are made by `explore.sh`, so the bar holds even when the text is skimmed.

## Trigger
The user runs `/dev-harness-perf:perf-loop <what to make faster, how it is measured>`. User-invoked only (`disable-model-invocation: true`).

## Inputs and outputs
Input: the metric command, its direction, a target or none, the correctness command, a variant budget. Output: an `explore/<slug>` branch; `docs/perf.md` with the Metric section (Runs, Noise, Correctness, Evidence), Budgets, Baselines and one log row per variant (`| Date | Variant | Metric | Result | Kept or reverted | Note |`, the note naming the evidence file); one commit per kept variant; a final report with baseline, best, every variant and what is NOT verified.

## Method or loop
1. Agree the metric, direction, target, correctness command and budget with the user.
2. `explore.sh --file docs/perf.md --template <plugin>/templates/perf.md start <slug>`; fill the Metric section.
3. `baseline --runs 5`; set `Noise:` above the printed SPREAD; refuse to continue above 10% spread.
4. Each variant: profiler evidence, one hypothesis, one change, `measure --runs 5`, then `keep ... --evidence <file>` or `revert`.
5. `status`; stop on `STOP=yes` or the budget.

## Unacceptable
- A change without a baseline (explore.sh refuses keep without a baseline row).
- A single cold run (`Runs: 5` makes baseline and measure refuse fewer runs).
- A kept change while the correctness command fails (`Correctness:` makes keep refuse).
- An optimization without profiler evidence (`Evidence: required` makes keep refuse without a non-empty `--evidence` file).
- A "gain" inside the run-to-run noise (`Noise:` makes keep refuse).
- Changing the measurement, the noise threshold or the tests during the loop.

## Success check
`tests/loop.sh` exits 0: the skill names each enforced step, and the shipped `templates/perf.md`, driven through the real `explore.sh`, refuses a keep without a baseline, a single-run baseline, a 3% gain under `Noise: 5%`, a keep without evidence and a keep with a failing correctness check, then keeps a real gain and logs it. With `SKILL.md` emptied, the skill checks fail.

## Tests
`tests/loop.sh` (17 checks): 7 on the skill's text (the enforced steps it must name) and 10 on behaviour, using `tests/fixtures/scripts/explore.sh` (dev-harness's script) and `tests/fixtures/perf.md` (this plugin's template) in a temporary git repository.

## Budget
A variant budget agreed with the user (default 6) and the explore.sh stop rule: the target is reached, or 2 variants in a row without a kept gain. Each measurement is 5 runs; each run has explore.sh's time limit (`EXPLORE_TIMEOUT`, default 600 s).
