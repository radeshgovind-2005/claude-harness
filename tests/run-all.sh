#!/usr/bin/env bash
# Runs every test suite and prints one summary. Exit 0 only if every suite passed.
# Usage:  /bin/bash tests/run-all.sh [--fast]
#   --fast  skips tests/scaffold-test.sh (about 4 minutes); the summary says it was skipped.
# Each suite's own output is shown only when it fails. Needs jq, git and (for validate.sh) the claude CLI.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
FAST=0
case "${1:-}" in --fast) FAST=1 ;; '') ;; *) echo "usage: run-all.sh [--fast]" >&2; exit 2 ;; esac

W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
rows=""; bad=0; skipped=0

run() { # name script [skip-reason]
  local name="$1" script="$2" log="$W/$1.log" res pass failed st
  if [ -n "${3:-}" ]; then
    rows="$rows$(printf '%-10s %-8s %s' "$name" SKIPPED "$3")"$'\n'; skipped=$((skipped+1)); return
  fi
  echo "running $name ..." >&2
  if [ "$name" = validate ]; then bash "$script" >"$log" 2>&1; st=$?; else /bin/bash "$script" >"$log" 2>&1; st=$?; fi
  res=$(grep -E '^Result: ' "$log" | tail -n1)
  pass=$(sed -nE 's/^Result: ([0-9]+) passed.*/\1/p' <<<"$res")
  failed=$(sed -nE 's/^Result: [0-9]+ passed, ([0-9]+) failed.*/\1/p' <<<"$res")
  if [ -z "$res" ]; then
    rows="$rows$(printf '%-10s %-8s %s' "$name" FAILED 'no "Result:" line: the suite did not finish')"$'\n'; bad=$((bad+1))
    tail -n 15 "$log" >&2
  elif [ "$st" -ne 0 ] || [ "${failed:-1}" != 0 ]; then
    rows="$rows$(printf '%-10s %-8s %s' "$name" FAILED "$pass passed, $failed failed (exit $st)")"$'\n'; bad=$((bad+1))
    grep -E '^  FAIL' "$log" >&2
  else
    rows="$rows$(printf '%-10s %-8s %s' "$name" ok "$pass checks")"$'\n'
  fi
}

run validate tests/validate.sh
run docs     tests/docs-test.sh
run explore  tests/explore-test.sh
run lens     tests/lens-test.sh
run goal     tests/goal-test.sh
run showcase tests/showcase-test.sh
if [ "$FAST" = 1 ]; then run scaffold tests/scaffold-test.sh "skipped by --fast: the scaffold and project hook tests did NOT run"
else run scaffold tests/scaffold-test.sh; fi

echo
printf '%-10s %-8s %s\n' SUITE STATUS DETAIL
printf '%s' "$rows"
echo
if [ "$bad" -gt 0 ]; then echo "FAILED: $bad suite(s) did not pass."; exit 1; fi
if [ "$skipped" -gt 0 ]; then echo "PASSED, but $skipped suite(s) were skipped: this run does not prove everything."; exit 0; fi
echo "PASSED: all suites."
