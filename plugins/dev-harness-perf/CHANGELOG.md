# Changelog: dev-harness-perf

Versions match `version` in `.claude-plugin/plugin.json`. This plugin depends on `dev-harness` (its `explore.sh` and `forge`).

## 0.1.0 — 2026-11-11

The first pack in the marketplace, and the reference example for `dev-harness:forge`: every part ships with a filled part spec and tests that `forge.sh check` accepts.

### Added
- `perf-loop` skill: baseline (repeated runs, median, a noise threshold from the measured spread), profiler evidence, one hypothesis, one change, measure, keep or revert, log in `docs/perf.md`. It drives `explore.sh` from dev-harness (a symlink, copied into the plugin cache on install).
- `profiler` agent (read-only): the top hotspots, each with evidence.
- `perf-guard` part: a Stop hook that blocks a stop when the benchmark regresses past `PERF_MAX_REGRESSION_PCT` (keys in `.claude/hooks/harness.conf`). Installed into a project with `/dev-harness:forge install`.
- `docs/perf.md` template: metric, budgets, baselines and the results log.
