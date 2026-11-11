#!/usr/bin/env bash
# Stop
# Runs a FAST check (typecheck + lint, or tests) when Claude tries to finish.
# If the check fails, exit 2: Claude cannot stop and must fix the errors.
# This enforces "never say done without verification".
#
# When it runs: on every Stop, if VERIFY_CMD is set AND the git working tree has uncommitted or
# untracked changes (`git status --porcelain` is not empty). A clean tree is skipped, so work that is
# already committed is not checked again. Outside a git repository it runs on every Stop.
#
# Time limit: VERIFY_CMD gets VERIFY_LIMIT seconds (240), below the 300 s this hook is registered with.
# Claude Code discards the output of a hook that hits its own timeout, so without this limit a slow check
# would let Claude stop unverified and silently. Over the limit the check is killed and the stop is blocked
# once with a "TIMED OUT" message. Test-only (test-hooks.sh): DH_VERIFY_TIMEOUT overrides the limit, and
# DH_VERIFY_NO_TIMEOUT_CMD=1 forces the bash fallback even where `timeout` exists.

# The command comes from VERIFY_CMD in harness.conf (next to this script), read by harness-conf.sh.
# Empty or missing = off. Keep it fast (< 60 s). Examples:
#   VERIFY_CMD="npm run typecheck && npm run lint"
#   VERIFY_CMD="ruff check . && mypy ."

input=$(cat)

# Prevent an infinite loop: if Claude is already continuing because of
# this hook, let it stop. It must report the failure to the user.
# (No jq needed: a stop hook that fails because jq is missing must not trap Claude in a loop.)
grep -Eq '"stop_hook_active"[[:space:]]*:[[:space:]]*true' <<<"$input" && exit 0

# Builtins only (no dirname): this must work even when PATH is broken, so the jq check below can speak.
case "${BASH_SOURCE[0]}" in */*) here="${BASH_SOURCE[0]%/*}" ;; *) here=. ;; esac; here=$(cd "$here" && pwd)
if ! { [ -f "$here/harness-conf.sh" ] && . "$here/harness-conf.sh" && type conf >/dev/null 2>&1; }; then
  echo "VERIFICATION DID NOT RUN: .claude/hooks/harness-conf.sh (the dev-harness config parser) is missing or broken. Tell the user the work is NOT verified and that they should restore it (run /dev-harness:add guardrails)." >&2
  exit 2
fi
VERIFY_CMD=$(conf VERIFY_CMD "")
LIMIT="${DH_VERIFY_TIMEOUT:-240}"
case "$LIMIT" in ''|*[!0-9]*|0) LIMIT=240 ;; esac

[ -z "$VERIFY_CMD" ] && exit 0

root="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$root" || exit 0

# Skip if nothing changed in this repo.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  [ -z "$(git status --porcelain 2>/dev/null)" ] && exit 0
fi

# run_check: runs VERIFY_CMD with the time limit. Sets output, status, timed_out.
# GNU timeout (or gtimeout from Homebrew coreutils) when present; otherwise a bash 3.2 fallback that runs
# the check in its own process group and polls every 0.1 s, so the whole tree is killed on timeout.
# (A check that detaches itself with setsid escapes the fallback's kill.)
run_check() {
  local t tmp pid ticks=0 start=$SECONDS
  timed_out=0
  t=$(command -v timeout 2>/dev/null || command -v gtimeout 2>/dev/null)
  if [ -n "$t" ] && [ -z "${DH_VERIFY_NO_TIMEOUT_CMD:-}" ]; then
    output=$("$t" -k 5 "$LIMIT" bash -c "$VERIFY_CMD" 2>&1 </dev/null)
    status=$?
    # 124/137 also come from a check that exits that way itself (or is OOM-killed): only a run that
    # lasted the whole limit counts as a time-out. Either way the stop is blocked.
    if { [ $status -eq 124 ] || [ $status -eq 137 ]; } && [ $((SECONDS - start)) -ge "$LIMIT" ]; then timed_out=1; fi
    return 0
  fi
  tmp=$(mktemp "${TMPDIR:-/tmp}/dh-verify.XXXXXX") || { output="mktemp failed"; status=1; return 0; }
  set -m
  bash -c "$VERIFY_CMD" >"$tmp" 2>&1 </dev/null &
  pid=$!
  set +m
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$ticks" -ge $((LIMIT * 10)) ]; then
      timed_out=1
      kill -TERM -- "-$pid" 2>/dev/null
      ticks=0; while kill -0 "$pid" 2>/dev/null && [ $ticks -lt 10 ]; do sleep 0.1; ticks=$((ticks + 1)); done
      kill -KILL -- "-$pid" 2>/dev/null
      break
    fi
    sleep 0.1; ticks=$((ticks + 1))
  done
  wait "$pid" 2>/dev/null
  status=$?
  output=$(tail -c 20000 "$tmp"); rm -f "$tmp"
}
run_check

if [ "$timed_out" = 1 ]; then
  {
    echo "VERIFICATION TIMED OUT after $LIMIT s and was stopped. Do not report the task as done."
    echo "Tell the user the check did not finish. VERIFY_CMD in .claude/hooks/harness.conf should take under 60 s;"
    echo "only the user edits that file."
    echo "--- last 40 lines ---"
    tail -n 40 <<<"$output"
  } >&2
  exit 2
fi

if [ $status -ne 0 ]; then
  {
    echo "VERIFICATION FAILED (exit $status). Do not report the task as done."
    echo "Fix the errors below, or explain to the user why you cannot."
    echo "--- last 40 lines ---"
    tail -n 40 <<<"$output"
  } >&2
  exit 2
fi

exit 0
