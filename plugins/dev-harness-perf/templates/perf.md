# Performance

What is measured, what it may cost, and every change tried. Written by `/dev-harness-perf:perf-loop`; the Metric lines are enforced by `explore.sh`.

## Metric

- Name: <what is measured, with its unit>
- Measured by: `<command that prints the number last, run from the project root>`
- Direction: lower is better
- Target: none
- Runs: 5
- Noise: <set from the baseline SPREAD before the first variant, as a percent>
- Correctness: `<the test command that must still pass>`
- Evidence: required

`Runs` refuses a single cold run. `Noise` refuses a "gain" inside run-to-run noise. `Correctness` refuses a faster wrong answer. `Evidence: required` refuses a change without the profiler output that motivated it.

## Budgets

| Metric | Budget | Why |
|---|---|---|
| <name> | <the limit, e.g. p50 under 120 ms> | <who notices when it is exceeded> |

## Baselines

<Date, commit, machine, the median and the SPREAD of the baseline runs. Re-baseline after a change of machine or data.>

## Log

| Date | Variant | Metric | Result | Kept or reverted | Note |
|---|---|---|---|---|---|
| YYYY-MM-DD | baseline | `<value>` | — | baseline | Starting point |
