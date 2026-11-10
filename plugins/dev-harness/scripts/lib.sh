#!/usr/bin/env bash
# Shared helpers for explore.sh and goal-stop.sh. Source it; it runs nothing by itself.
# bash 3.2 compatible (macOS): no `timeout` command, no `;;&`, no associative arrays.

# run_limited SECS COMMAND
# Runs COMMAND with `bash -c` in the current directory, stdin closed, output captured.
# Sets: RUN_OUT (stdout+stderr), RUN_RC (exit code), RUN_TIMED_OUT (1 if the watchdog killed it).
# The command runs in its own process group, so the whole tree is killed on timeout.
# shellcheck disable=SC2034  # the RUN_* variables are read by the caller
run_limited() {
  local secs="$1" cmd="$2" tmp pid wd
  tmp=$(mktemp "${TMPDIR:-/tmp}/dh-run.XXXXXX") || return 1
  RUN_TIMED_OUT=0
  set -m
  bash -c "$cmd" >"$tmp" 2>&1 </dev/null &
  pid=$!
  set +m
  (
    sleep "$secs"
    : > "$tmp.timeout"
    kill -TERM -- "-$pid" 2>/dev/null
    sleep 1
    kill -KILL -- "-$pid" 2>/dev/null
  ) >/dev/null 2>&1 &
  wd=$!
  wait "$pid" 2>/dev/null
  RUN_RC=$?
  kill "$wd" 2>/dev/null
  wait "$wd" 2>/dev/null
  if [ -e "$tmp.timeout" ]; then RUN_TIMED_OUT=1; rm -f "$tmp.timeout"; fi
  RUN_OUT=$(cat "$tmp")
  rm -f "$tmp"
  return 0
}

# last_number TEXT: the last number on the last non-empty line, or nothing.
last_number() {
  printf '%s\n' "$1" | awk '
    NF { line = $0 }
    END {
      n = ""; s = line
      while (match(s, /-?[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?/)) {
        n = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
      }
      if (n != "") print n
    }'
}

# num_cmp A OP B: numeric comparison through awk (OP is one of > >= < <= ==).
num_cmp() { awk -v a="$1" -v b="$3" "BEGIN { exit !(a+0 $2 b+0) }"; }
