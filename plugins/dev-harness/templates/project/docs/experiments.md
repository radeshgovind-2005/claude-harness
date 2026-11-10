# Experiments

Log of variants you tried against a metric: what changed, what was measured, and whether it was kept.
Read it before you try something, so you do not repeat a variant that already failed.
`/dev-harness:explore` writes here through `scripts/explore.sh`, which also decides keep or revert. You can add rows by hand.

## Rules

1. Define the metric and how to measure it before the first variant. Use a command that can be run again.
2. Record the baseline first. A result with no baseline means nothing.
3. One change per variant. Keep what improves; revert what does not, and log the revert too.
4. Stop on the target, or after 2 variants in a row with no improvement. Say which.

## Metric

The script reads these lines. Keep the labels.

- Name: `<metric>`
- Measured by: `<command>` (run from the project root; the last number on its last output line is the value)
- Direction: <higher or lower> is better
- Target: <number, or none>

## Log

| Date | Variant (one change) | Metric | Result | Kept or reverted | Note |
|---|---|---|---|---|---|
| YYYY-MM-DD | baseline | `<value>` | — | — | Starting point |
