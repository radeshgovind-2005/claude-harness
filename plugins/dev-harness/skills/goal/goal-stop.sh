#!/usr/bin/env bash
# Stop hook, registered by the goal skill (so it stays registered for the rest of that session).
# State-gated: with no active goal for this session it does nothing (exit 0).
#
# Active goal, each time Claude tries to stop (one "round"):
#   run the success check (watchdog-limited)
#   passes            -> block ONCE: ask for the final report; the next stop is allowed
#   fails, budget ok  -> block: say the exit code and output; ask for a checkpoint, then the next step
#   fails, budget out -> block ONCE: ask for a report of what is unfinished; the next stop is allowed
# Exit 2 = block (stderr goes to Claude). Exit 0 = allow the stop.
# A corrupt state file fails open (exit 0, message on stderr): it only ends the loop.

input=$(cat)
sid=$(jq -r '.session_id // empty' <<<"$input" 2>/dev/null)
[[ "$sid" =~ ^[A-Za-z0-9_-]+$ ]] || exit 0

STATE_DIR="${DEV_HARNESS_STATE_DIR:-$HOME/.claude/dev-harness}/goals"
F="$STATE_DIR/$sid.json"
[ -f "$F" ] || exit 0

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "${CLAUDE_PLUGIN_ROOT:-$HERE/../..}" 2>/dev/null && pwd)"
LIB="$PLUGIN_DIR/scripts/lib.sh"
GOALSH="$PLUGIN_DIR/scripts/goal.sh"
# shellcheck source=../../scripts/lib.sh
. "$LIB" 2>/dev/null || { echo "dev-harness goal: cannot load $LIB; the goal loop is off" >&2; exit 0; }

state=$(jq -c . "$F" 2>/dev/null) || { echo "dev-harness goal: state file $F is unreadable; the goal loop is off. Run goal.sh stop." >&2; exit 0; }
field() { jq -r "$1" <<<"$state"; }
status=$(field '.status // empty')
check=$(field '.check // empty')
project=$(field '.project // empty')
rounds=$(field '.rounds // 0'); rmax=$(field '.rounds_max // 0'); mmax=$(field '.minutes_max // 0'); started=$(field '.started // 0')
[[ "$rounds" =~ ^[0-9]+$ && "$rmax" =~ ^[0-9]+$ && "$mmax" =~ ^[0-9]+$ && "$started" =~ ^[0-9]+$ && -n "$check" ]] \
  || { echo "dev-harness goal: state file $F is malformed; the goal loop is off. Run goal.sh stop." >&2; exit 0; }

save() { # jq filter -> state file (atomic)
  local tmp; tmp=$(mktemp "$STATE_DIR/.tmp.XXXXXX") || return 1
  jq "$1" "$F" > "$tmp" && mv "$tmp" "$F" || { rm -f "$tmp"; return 1; }
}

case "$status" in
  active) ;;
  reporting) save '.status = "finished"'; exit 0 ;;   # the report turn is over; let Claude stop
  *) exit 0 ;;                                         # finished, or unknown: do nothing
esac

rounds=$((rounds + 1))
elapsed=$(( ($(date +%s) - started) / 60 ))
save ".rounds = $rounds" || { echo "dev-harness goal: cannot write $F; the goal loop is off" >&2; exit 0; }

[ -d "$project" ] && cd "$project" || cd "${CLAUDE_PROJECT_DIR:-$PWD}" || exit 0
run_limited "${GOAL_CHECK_TIMEOUT:-120}" "$check"

if [ "$RUN_TIMED_OUT" = 0 ] && [ "$RUN_RC" -eq 0 ]; then
  save '.status = "reporting" | .outcome = "met"'
  {
    echo "GOAL MET after $rounds round(s), $elapsed min: the check \`$check\` exited 0."
    echo "Write the final report now. Do not start new work. Include:"
    echo "  - Done: what changed"
    echo "  - Verified: the check command and its exit code (0), plus anything else you ran"
    echo "  - NOT verified: anything the check does not cover"
    echo "Add it as a checkpoint to docs/progress.md if that file exists."
  } >&2
  exit 2
fi

if [ "$RUN_TIMED_OUT" = 1 ]; then why="timed out after ${GOAL_CHECK_TIMEOUT:-120}s"; else why="exited $RUN_RC"; fi

if [ "$rounds" -ge "$rmax" ] || [ "$elapsed" -ge "$mmax" ]; then
  save '.status = "reporting" | .outcome = "budget"'
  {
    echo "GOAL BUDGET REACHED without meeting the check: $rounds of $rmax round(s), $elapsed of $mmax min."
    echo "The check \`$check\` $why. Last output:"
    tail -n 15 <<<"$RUN_OUT"
    echo "---"
    echo "Do not start new work. Write the final report: Done, Verified (the check failed), what is left and your best guess at why,"
    echo "and the next step. Add it to docs/progress.md if that file exists. Do not claim the goal is done."
  } >&2
  exit 2
fi

{
  echo "GOAL NOT MET: round $rounds of $rmax ($elapsed of $mmax min). The check \`$check\` $why."
  [ "$rounds" -ge $((rmax - 1)) ] && echo "THIS IS THE LAST ROUND: if the check still fails when you stop again, the goal ends."
  echo "--- last 30 lines of output ---"
  tail -n 30 <<<"$RUN_OUT"
  echo "---"
  echo "1. Append a short checkpoint to docs/progress.md (create it if missing): Done / Verified / Next."
  echo "2. Take the next smallest step toward making the check pass, then try to finish again."
  echo "If you cannot continue without the user, run: bash $GOALSH stop --session $sid --reason \"<what you need>\" and tell the user what you need."
} >&2
exit 2
