#!/usr/bin/env bash
# perf-guard: blocks a regression past the threshold, in both directions; passes within it; does nothing
# without PERF_CMD or on a clean tree; loud on bad settings, a failing benchmark or a missing parser.
# Run by forge.sh check with FILES_DIR (the hook) and PART_DIR (this part, with tests/fixtures).
pass=0; fail=0
c() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else echo "FAIL $1 (expected $2, got $3)"; fail=$((fail+1)); fi; }
T=$(mktemp -d); E=$(mktemp -d); trap 'rm -rf "$T" "$E"' EXIT
git -C "$T" init -q -b main; mkdir -p "$T/.claude/hooks"
cp "$FILES_DIR/perf-guard.sh" "$T/.claude/hooks/"; cp "$PART_DIR/tests/fixtures/harness-conf.sh" "$T/.claude/hooks/"
conf() { printf '%s\n' "$@" > "$T/.claude/hooks/harness.conf"; }
run() { echo "${1:-{\}}" | CLAUDE_PROJECT_DIR="$T" bash "$T/.claude/hooks/perf-guard.sh" 2>"$E/err"; echo $?; }
echo 105 > "$T/value.txt"
conf 'PERF_CMD="cat value.txt"' PERF_BASELINE=100 PERF_MAX_REGRESSION_PCT=10 PERF_DIRECTION=lower PERF_RUNS=3
c "within the threshold (+5% of 10%): allows"           0 "$(run)"
echo 120 > "$T/value.txt"
c "past the threshold (+20%): blocks"                   2 "$(run)"
grep -q 'PERF REGRESSION: the median of 3 runs is 120 against the baseline 100 (20.00% worse' "$E/err"; c "the message names median, baseline and percent" 0 $?
c "loop guard: the next stop is allowed"                0 "$(run '{"stop_hook_active":true}')"
conf 'PERF_CMD="cat value.txt"' PERF_BASELINE=150 PERF_DIRECTION=higher PERF_RUNS=3
c "higher is better: 120 vs 150 (-20%) blocks"          2 "$(run)"
conf 'PERF_CMD="cat value.txt"' PERF_BASELINE=125 PERF_DIRECTION=higher PERF_RUNS=3
c "higher is better: 120 vs 125 (-4%) allows"           0 "$(run)"
printf 'n=$(cat c 2>/dev/null || echo 0); n=$((n+1)); echo $n > c; case $n in 1) echo 300;; *) echo 101;; esac\n' > "$T/bench.sh"
conf 'PERF_CMD="bash bench.sh"' PERF_BASELINE=100 PERF_RUNS=3
c "one slow outlier run: the median decides (allows)"   0 "$(run)"
conf PERF_BASELINE=100
c "no PERF_CMD: does nothing"                           0 "$(run)"
conf 'PERF_CMD="cat value.txt"' PERF_BASELINE=fast
c "a baseline that is not a number: says so (blocks)"   2 "$(run)"
grep -q "PERF_BASELINE='fast'" "$E/err"; c "... and names the key" 0 $?
conf 'PERF_CMD="cat value.txt"' PERF_BASELINE=100 PERF_DIRECTION=faster
c "an invalid direction: blocks"                        2 "$(run)"
conf 'PERF_CMD="exit 3"' PERF_BASELINE=100
c "a failing benchmark: blocks"                         2 "$(run)"
conf 'PERF_CMD="echo no number"' PERF_BASELINE=100
c "a benchmark that prints no number: blocks"           2 "$(run)"
conf 'PERF_CMD="sleep 30"' PERF_BASELINE=100 PERF_RUNS=2
c "a benchmark over the time limit: blocks"             2 "$(echo '{}' | DH_PERF_TIMEOUT=1 CLAUDE_PROJECT_DIR="$T" bash "$T/.claude/hooks/perf-guard.sh" 2>/dev/null; echo $?)"
conf 'PERF_CMD="cat value.txt"' PERF_BASELINE=100
gc() { git -C "$T" add -A >/dev/null; git -C "$T" -c user.email=t@t -c user.name=t commit -q -m "$1"; }
echo 120 > "$T/value.txt"; gc "slower, committed"
c "a committed regression (clean tree, new HEAD) blocks" 2 "$(run)"
echo 101 > "$T/value.txt"; gc "fast again"
c "a clean tree at a new HEAD is checked and passes"     0 "$(run)"
echo 300 > "$T/value.txt"; git -C "$T" update-index --assume-unchanged value.txt
c "a clean tree at the HEAD that last passed is skipped" 0 "$(run)"
git -C "$T" update-index --no-assume-unchanged value.txt; git -C "$T" checkout -q -- value.txt
touch "$T/new"; rm "$T/.claude/hooks/harness-conf.sh"
c "no parser: says so (blocks once)"                    2 "$(run)"
echo "perf-guard tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
