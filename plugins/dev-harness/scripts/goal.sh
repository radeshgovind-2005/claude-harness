#!/usr/bin/env bash
# dev-harness goal: state for the command-judged goal loop. The Stop hook is skills/goal/goal-stop.sh.
#
# Usage:
#   goal.sh start  --session ID --check "CMD" [--rounds N] [--minutes M] [--replace]
#   goal.sh status --session ID
#   goal.sh stop   --session ID [--reason TEXT]
#
# State: <state dir>/goals/<session id>.json, outside the project. The state dir is
# $DEV_HARNESS_STATE_DIR, else $HOME/.claude/dev-harness. (CLAUDE_PLUGIN_DATA is not set in hook
# processes under --plugin-dir, so it cannot be used.)
#
# A "round" is one Stop event: Claude ends its turn and the check runs. Budget = rounds and minutes.
# Tokens are not a budget here: hooks get no token count. For headless runs use --max-budget-usd.
# Exit 1 on any refusal, with a "FAIL" line.

# -h / --help prints the comment block at the top of this file (the usage).
case "${1:-}" in -h|--help) sed -n -E '2,/^([^#]|$)/{/^#/s/^# ?//p;}' "$0"; exit 0 ;; esac

set -u
die() { echo "FAIL    $*" >&2; exit 1; }
command -v jq >/dev/null || die "jq is required (brew install jq / apt install jq)"

STATE_DIR="${DEV_HARNESS_STATE_DIR:-$HOME/.claude/dev-harness}/goals"

cmd="${1:-}"; [ $# -gt 0 ] && shift
SESSION=""; CHECK=""; ROUNDS=10; MINUTES=30; REPLACE=0; REASON=""
while [ $# -gt 0 ]; do
  case "$1" in --session|--check|--rounds|--minutes|--reason) [ $# -ge 2 ] || die "$1 needs a value" ;; esac
  case "$1" in
    --session) SESSION="$2"; shift 2 ;;
    --check) CHECK="$2"; shift 2 ;;
    --rounds) ROUNDS="$2"; shift 2 ;;
    --minutes) MINUTES="$2"; shift 2 ;;
    --reason) REASON="$2"; shift 2 ;;
    --replace) REPLACE=1; shift ;;
    *) die "unknown option: $1" ;;
  esac
done

[[ "$SESSION" =~ ^[A-Za-z0-9_-]+$ ]] || die "--session is required (letters, digits, - and _ only)"
F="$STATE_DIR/$SESSION.json"

case "$cmd" in
  start)
    case "$CHECK" in ""|*[![:print:]]*) die "--check must be one non-empty line of printable text" ;; esac
    case "$ROUNDS" in ""|*[!0-9]*|0) die "--rounds must be a positive integer" ;; esac
    case "$MINUTES" in ""|*[!0-9]*|0) die "--minutes must be a positive integer" ;; esac
    [ "$ROUNDS" -le 100 ] || die "--rounds is limited to 100"
    [ "$MINUTES" -le 720 ] || die "--minutes is limited to 720 (12 hours)"
    mkdir -p "$STATE_DIR" || die "cannot create $STATE_DIR"
    # Forget goals that ended long ago. Only files in the state dir.
    find "$STATE_DIR" -name '*.json' -type f -mtime +14 -exec rm -f {} + 2>/dev/null
    if [ -f "$F" ] && [ "$REPLACE" = 0 ]; then
      st=$(jq -r '.status // empty' "$F" 2>/dev/null)
      [ "$st" = finished ] || die "this session already has a goal (status: ${st:-unreadable}). Use: goal.sh stop, or start with --replace"
    fi
    tmp=$(mktemp "$STATE_DIR/.tmp.XXXXXX") || die "cannot write in $STATE_DIR"
    jq -n --arg session "$SESSION" --arg check "$CHECK" --arg project "$PWD" \
          --argjson rounds "$ROUNDS" --argjson minutes "$MINUTES" --argjson started "$(date +%s)" '
      { session: $session, project: $project, check: $check, rounds_max: $rounds, minutes_max: $minutes,
        started: $started, rounds: 0, status: "active", outcome: null }' > "$tmp" && mv "$tmp" "$F" || { rm -f "$tmp"; die "cannot write $F"; }
    echo "  add     goal for this session: check \`$CHECK\`, up to $ROUNDS rounds / $MINUTES minutes"
    echo "  note    a round is one time Claude ends its turn. Tokens are not budgeted (no token count reaches hooks)."
    ;;

  status)
    [ -f "$F" ] || { echo "no goal for this session"; exit 0; }
    jq -r '"status: \(.status)  outcome: \(.outcome // "none")\ncheck: \(.check)\nrounds: \(.rounds) of \(.rounds_max)\nminutes: \(((now - .started) / 60) | floor) of \(.minutes_max)"' "$F" 2>/dev/null \
      || die "state file is unreadable: $F"
    ;;

  stop)
    [ -f "$F" ] || { echo "no goal for this session"; exit 0; }
    tmp=$(mktemp "$STATE_DIR/.tmp.XXXXXX") || die "cannot write in $STATE_DIR"
    jq --arg r "$REASON" '.status = "finished" | .outcome = "stopped" | .reason = $r' "$F" > "$tmp" && mv "$tmp" "$F" || { rm -f "$tmp"; die "cannot update $F"; }
    echo "  stop    goal ended (${REASON:-no reason given})"
    ;;

  *) sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; [ -z "$cmd" ] || die "unknown subcommand: $cmd"; exit 1 ;;
esac
