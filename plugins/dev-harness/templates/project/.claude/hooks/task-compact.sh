#!/usr/bin/env bash
# PreCompact (registered without a matcher: manual /compact and auto-compaction).
# If this worktree has an active task card, (1) print instructions for the compaction summary (Claude Code
# uses a PreCompact hook's stdout for that) so it keeps the card's id, goal, decisions and status, and
# (2) append a timestamped "compacted" note with a git status snapshot to the card's Log.
# No active card: prints nothing. ALWAYS exits 0: exit 2 would block compaction, and an auto-compaction
# at the context limit would then fail the request. No jq needed.

input=$(cat)
root="${CLAUDE_PROJECT_DIR:-$PWD}"

[ -f "$root/.claude/active-task" ] || exit 0
id=$(tr -d '\r\n' < "$root/.claude/active-task")
[[ "$id" =~ ^[0-9]{3}-[a-z0-9]+(-[a-z0-9]+)*$ ]] || exit 0
card="$root/docs/tasks/$id.md"
[ -f "$card" ] || exit 0

trigger=$(grep -Eo '"trigger"[[:space:]]*:[[:space:]]*"[a-z]+"' <<<"$input" | sed -E 's/.*"([a-z]+)"$/\1/')
section() { tr -d '\r' < "$card" | awk -v n="## $1" '$0 == n {on = 1; next} on && /^## / {exit} on {print}' | sed 's/<!--.*-->//g' | grep -v '^[[:space:]]*$' | head -c 2500; }
status=$(tr -d '\r' < "$card" | grep -m1 '^status:')

# 1. Instructions for the summary (stdout).
cat <<EOF
The active task card is docs/tasks/$id.md. Keep these verbatim in the summary: the card id ($id), its Goal, its Decisions and its status ($status) with its Next step. Say that the card file is the source of truth for this work and must be re-read after compaction rather than trusted from this summary.
Goal:
$(section Goal)
Decisions:
$(section Decisions)
Next:
$(section Next)
EOF

# 2. The note in the card's Log (best effort; a failure is reported, never blocking).
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
if snap=$(git -C "$root" status --short 2>/dev/null); then
  n=$(grep -c . <<<"$snap")
  if [ "$n" = 0 ]; then note="- $ts compacted (${trigger:-unknown}); git status: clean"
  else
    note="- $ts compacted (${trigger:-unknown}); git status ($n changed):"
    note="$note"$'\n'"$(head -n 20 <<<"$snap" | sed 's/^/  - `/; s/$/`/')"
    [ "$n" -gt 20 ] && note="$note"$'\n'"  - ($((n - 20)) more)"
  fi
else
  note="- $ts compacted (${trigger:-unknown}); git status: not a git repository"
fi
{
  grep -q '^## Log' "$card" || printf '\n## Log\n'
  [ -n "$(tail -c 1 "$card")" ] && echo
  printf '%s\n' "$note"
} >> "$card" 2>/dev/null || echo "(dev-harness could not append the compaction note to docs/tasks/$id.md)"
exit 0
