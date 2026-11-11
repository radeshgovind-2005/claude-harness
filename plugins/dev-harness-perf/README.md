# dev-harness-perf

Performance work done like an experiment. A pack in the `claude-harness` marketplace; it needs `dev-harness` (installed with it as a dependency).

```
/plugin install dev-harness-perf@claude-harness
```

| Part | Type | What it does |
|---|---|---|
| `perf-loop` | skill | `/dev-harness-perf:perf-loop <what to make faster>`: baseline with repeated runs and a noise threshold, profiler evidence, one change at a time, kept only if it beats the noise and the tests still pass, logged in `docs/perf.md` |
| `profiler` | agent | `dev-harness-perf:profiler`: names the top hotspots, each with evidence (the command, its output, file:line). Read-only tools |
| `perf-guard` | hook (installed per project) | blocks a stop when the benchmark is worse than the baseline by more than the threshold. Install it with `/dev-harness:forge install <plugin>/parts/perf-guard` |

What the loop refuses (enforced by `explore.sh`, not by prose): a change without a baseline, a single cold run, a kept change while the correctness check fails, and an optimization without profiler evidence.

Every part has a filled part spec in `parts/<name>/spec.md` and tests that `forge.sh check` accepts, so this pack is the reference example for `/dev-harness:forge`.

**Limits.** `scripts/explore.sh` is a symlink to dev-harness's. Installed from a git marketplace, Claude Code copies its target into the cache; a marketplace added from a local folder skips such links, and `perf-loop` then says the script is missing. `perf-guard` reads its settings through dev-harness's `harness-conf.sh`, so the project needs dev-harness guardrails.
