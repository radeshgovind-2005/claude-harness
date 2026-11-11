#!/usr/bin/env bash
# SessionStart (registered without a matcher: startup, resume, clear, compact, fork).
# If this worktree has an active task card (.claude/active-task, set by tasks.sh active or
# /dev-harness:resume), print the card and the newest 5 lessons from docs/lessons.md. Claude Code adds a
# SessionStart hook's stdout to Claude's context, so after /clear or a compaction the card comes back.
# No active card, or one that names no card: prints nothing. Never blocks: always exit 0. No jq needed.
# Output is capped below Claude Code's 10,000-character limit for hook output.

cat >/dev/null   # the hook input is not needed
root="${CLAUDE_PROJECT_DIR:-$PWD}"
LIMIT="${DH_TASK_CONTEXT_LIMIT:-9000}"

[ -f "$root/.claude/active-task" ] || exit 0
id=$(tr -d '\r\n' < "$root/.claude/active-task")
# Only a real card id: the file is not trusted to name a path.
[[ "$id" =~ ^[0-9]{3}-[a-z0-9]+(-[a-z0-9]+)*$ ]] || exit 0
card="$root/docs/tasks/$id.md"
[ -f "$card" ] || exit 0

# lessons: the newest 5 "### " entries under "## Entries", without the template's [example] placeholder.
lessons() {
  [ -f "$root/docs/lessons.md" ] || return 0
  tr -d '\r' < "$root/docs/lessons.md" | awk '
    /^## Entries/ { on = 1; next }
    on && /^## / { exit }
    on && /^### / { keep = ($0 !~ /\[example\]/); if (keep) n++; if (n > 5) exit }
    on && keep && n >= 1 { print }'
}

text=$(
  echo "ACTIVE TASK CARD (dev-harness): docs/tasks/$id.md. The card, not this conversation, holds the state of this work: its goal, scope, decisions and next step."
  echo "Before you stop or the user runs /clear, update it with /dev-harness:handoff."
  echo
  tr -d '\r' < "$card"
  l=$(lessons)
  if [ -n "$l" ]; then echo; echo "NEWEST LESSONS (docs/lessons.md):"; echo "$l"; fi
)
if [ "${#text}" -gt "$LIMIT" ]; then
  printf '%s\n' "${text:0:$LIMIT}"
  echo "[truncated at $LIMIT characters: read docs/tasks/$id.md and docs/lessons.md]"
else
  printf '%s\n' "$text"
fi
exit 0
