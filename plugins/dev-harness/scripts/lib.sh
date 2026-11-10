#!/usr/bin/env bash
# Shared helpers for explore.sh and goal-stop.sh. Source it; it runs nothing by itself.
# bash 3.2 compatible (macOS): no `timeout` command, no `;;&`, no associative arrays.

# run_limited SECS COMMAND
# Runs COMMAND with `bash -c` in the current directory, stdin closed, output captured.
# Sets: RUN_OUT (the last 20000 bytes of stdout+stderr), RUN_RC (exit code),
#       RUN_TIMED_OUT (1 if it was killed for running longer than SECS).
# The command runs in its own process group, so the whole tree is killed on timeout (a command that
# detaches itself with setsid escapes this). It polls every 0.1 s instead of starting a watchdog
# process, so nothing is left sleeping behind it.
# shellcheck disable=SC2034  # the RUN_* variables are read by the caller
run_limited() {
  local secs="$1" cmd="$2" tmp pid ticks=0 limit
  tmp=$(mktemp "${TMPDIR:-/tmp}/dh-run.XXXXXX") || return 1
  RUN_TIMED_OUT=0
  limit=$((secs * 10))
  set -m
  bash -c "$cmd" >"$tmp" 2>&1 </dev/null &
  pid=$!
  set +m
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$ticks" -ge "$limit" ]; then
      RUN_TIMED_OUT=1
      kill -TERM -- "-$pid" 2>/dev/null
      sleep 1
      kill -KILL -- "-$pid" 2>/dev/null
      break
    fi
    sleep 0.1
    ticks=$((ticks + 1))
  done
  wait "$pid" 2>/dev/null
  RUN_RC=$?
  RUN_OUT=$(tail -c 20000 "$tmp")
  rm -f "$tmp"
  return 0
}

# last_number TEXT: the last number on the last non-empty line, or nothing.
last_number() {
  printf '%s\n' "$1" | awk '
    NF { line = $0 }
    END {
      n = ""; s = line
      while (match(s, /-?([0-9]+(\.[0-9]*)?|\.[0-9]+)([eE][-+]?[0-9]+)?/)) {
        n = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
      }
      if (n != "") print n
    }'
}

# num_cmp A OP B: numeric comparison through awk (OP is one of > >= < <= ==).
num_cmp() { awk -v a="$1" -v b="$3" "BEGIN { exit !(a+0 $2 b+0) }"; }

# count_numbers TEXT: how many numbers are on the last non-empty line (0 if none).
count_numbers() {
  printf '%s\n' "$1" | awk '
    NF { line = $0 }
    END {
      n = 0; s = line
      while (match(s, /-?([0-9]+(\.[0-9]*)?|\.[0-9]+)([eE][-+]?[0-9]+)?/)) { n++; s = substr(s, RSTART + RLENGTH) }
      print n
    }'
}

# has_thousands_sep TEXT: true if the last non-empty line has a number like 1,234 (ambiguous).
has_thousands_sep() { printf '%s\n' "$1" | awk 'NF { line = $0 } END { exit !(line ~ /[0-9],[0-9][0-9][0-9]([^0-9]|$)/) }'; }
