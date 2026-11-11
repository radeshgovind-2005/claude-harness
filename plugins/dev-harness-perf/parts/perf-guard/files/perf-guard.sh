#!/usr/bin/env bash
# Stop. Installed by /dev-harness:forge from the dev-harness-perf pack (part: perf-guard).
# When Claude tries to finish and the git tree has changes, run the benchmark PERF_RUNS times, take the
# median, and block the stop once if it is worse than PERF_BASELINE by more than PERF_MAX_REGRESSION_PCT.
#
# Settings: keys in .claude/hooks/harness.conf (only the user edits that file), read by harness-conf.sh,
# the dev-harness parser next to this script:
#   PERF_CMD="<command that prints the number last>"   empty or missing = this hook does nothing
#   PERF_BASELINE=<number>                              the agreed baseline (from docs/perf.md)
#   PERF_MAX_REGRESSION_PCT=<percent>                   default 10
#   PERF_DIRECTION=lower|higher                         which is better; default lower
#   PERF_RUNS=<n>                                       default 5 (a single run is noise)
# Exit 2 = block (stderr goes to Claude). The stop_hook_active loop guard lets the next stop through.
# A time limit (DH_PERF_TIMEOUT, default 240 s for all runs) keeps the hook inside its registered timeout.

input=$(cat)
grep -Eq '"stop_hook_active"[[:space:]]*:[[:space:]]*true' <<<"$input" && exit 0

case "${BASH_SOURCE[0]}" in */*) here="${BASH_SOURCE[0]%/*}" ;; *) here=. ;; esac; here=$(cd "$here" && pwd)
if ! { [ -f "$here/harness-conf.sh" ] && . "$here/harness-conf.sh" && type conf >/dev/null 2>&1; }; then
  echo "PERF GUARD DID NOT RUN: .claude/hooks/harness-conf.sh (the dev-harness config parser) is missing. Tell the user the performance is NOT checked; it needs dev-harness guardrails (/dev-harness:add guardrails)." >&2
  exit 2
fi

CMD=$(conf PERF_CMD "")
[ -z "$CMD" ] && exit 0
BASE=$(conf PERF_BASELINE ""); PCT=$(conf PERF_MAX_REGRESSION_PCT 10); DIR=$(conf PERF_DIRECTION lower); RUNS=$(conf PERF_RUNS 5)
num() { [[ "$1" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; }
bad=""
num "$BASE" || bad="$bad PERF_BASELINE='$BASE' (a number)"
num "$PCT" || bad="$bad PERF_MAX_REGRESSION_PCT='$PCT' (a number)"
case "$DIR" in lower|higher) ;; *) bad="$bad PERF_DIRECTION='$DIR' (lower or higher)" ;; esac
[[ "$RUNS" =~ ^[1-9][0-9]*$ ]] || bad="$bad PERF_RUNS='$RUNS' (a whole number)"
if [ -n "$bad" ]; then
  echo "PERF GUARD DID NOT RUN: invalid settings in .claude/hooks/harness.conf:$bad. Tell the user; only they edit that file." >&2
  exit 2
fi

root="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$root" || exit 0
# Skip only a clean tree at the commit that last passed: a regression that was already committed is
# still checked (the passing HEAD is remembered in .git/, so nothing in the project changes).
mark=""; head=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  mark="$(git rev-parse --git-dir 2>/dev/null)/dev-harness-perf-guard.ok"
  head=$(git rev-parse -q --verify HEAD 2>/dev/null)
  if [ -z "$(git status --porcelain 2>/dev/null)" ] && [ -n "$head" ] && [ "$(cat "$mark" 2>/dev/null)" = "$head" ]; then exit 0; fi
fi

LIMIT="${DH_PERF_TIMEOUT:-240}"; case "$LIMIT" in ''|*[!0-9]*|0) LIMIT=240 ;; esac
deadline=$((SECONDS + LIMIT))
# run_once: run CMD with what is left of the time limit (process group, killed on timeout). Sets out, rc.
run_once() {
  local tmp pid left
  tmp=$(mktemp "${TMPDIR:-/tmp}/dh-perf.XXXXXX") || { out="mktemp failed"; rc=1; return; }
  left=$((deadline - SECONDS)); [ "$left" -lt 1 ] && left=1
  set -m; bash -c "$CMD" >"$tmp" 2>&1 </dev/null & pid=$!; set +m
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$SECONDS" -ge "$deadline" ]; then
      kill -TERM -- "-$pid" 2>/dev/null; sleep 0.5; kill -KILL -- "-$pid" 2>/dev/null; timed_out=1; break
    fi
    sleep 0.1
  done
  wait "$pid" 2>/dev/null; rc=$?
  out=$(tail -c 20000 "$tmp"); rm -f "$tmp"
}

vals=""; timed_out=0; i=0
while [ "$i" -lt "$RUNS" ]; do
  i=$((i + 1)); run_once
  if [ "$timed_out" = 1 ]; then
    echo "PERF GUARD: the benchmark did not finish $RUNS runs within $LIMIT s. Performance is NOT checked; tell the user (PERF_CMD or PERF_RUNS should be smaller)." >&2
    exit 2
  fi
  if [ "$rc" -ne 0 ]; then
    { echo "PERF GUARD: the benchmark failed (exit $rc): $CMD. Do not report the task as done."; echo "--- last 20 lines ---"; tail -n 20 <<<"$out"; } >&2
    exit 2
  fi
  v=$(printf '%s\n' "$out" | awk 'NF {l = $0} END {n = ""; s = l; while (match(s, /-?[0-9]+(\.[0-9]+)?/)) {n = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)} print n}')
  if [ -z "$v" ]; then echo "PERF GUARD: the benchmark printed no number on its last line: $CMD" >&2; exit 2; fi
  vals="$vals$v"$'\n'
done

median=$(printf '%s' "$vals" | sort -g | awk '{a[NR] = $1} END {if (NR % 2) print a[(NR + 1) / 2]; else printf "%.10g\n", (a[NR / 2] + a[NR / 2 + 1]) / 2}')
worse=$(awk -v m="$median" -v b="$BASE" -v d="$DIR" 'BEGIN {a = (b < 0) ? -b : b; w = (d == "lower") ? m - b : b - m; if (a > 0) printf "%.2f", w / a * 100; else printf "%.2f", (w > 0) ? 100 : 0}')
if awk -v w="$worse" -v p="$PCT" 'BEGIN {exit !(w > p)}'; then
  {
    echo "PERF REGRESSION: the median of $RUNS runs is $median against the baseline $BASE ($worse% worse; the limit is $PCT%, $DIR is better)."
    echo "Do not report the task as done. Find the change that caused it (the dev-harness-perf:profiler agent), fix it, or explain to the user why the regression is acceptable (only they change PERF_BASELINE)."
    echo "Runs: $(printf '%s' "$vals" | tr '\n' ' ')"
  } >&2
  exit 2
fi
# Remember a passing clean HEAD, so the next stop with nothing new skips the benchmark.
if [ -n "$mark" ] && [ -n "$head" ] && [ -z "$(git status --porcelain 2>/dev/null)" ]; then printf '%s\n' "$head" > "$mark" 2>/dev/null; fi
exit 0
