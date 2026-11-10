# Experiments

Log of variants you tried against a metric: what changed, what was measured, and whether it was kept.
Read it before you try something, so you do not repeat a variant that already failed.
`/dev-harness:explore` (from dev-harness v0.4.0) writes here. Until then, add rows by hand.

## Rules

1. Define the metric and how to measure it before the first variant. Use a command that can be run again.
2. Record the baseline first. A result with no baseline means nothing.
3. One change per variant. Keep what improves; revert what does not, and log the revert too.
4. Stop on success, or after 2 rounds with no progress. Say which.

## Metric

- Name: `<metric>`
- Measured by: `<command>`
- Baseline: `<value>` (YYYY-MM-DD, commit `<hash>`)

## Log

| Date | Variant (one change) | Metric | Result | Kept or reverted | Note |
|---|---|---|---|---|---|
| YYYY-MM-DD | baseline | `<value>` | — | — | Starting point |
