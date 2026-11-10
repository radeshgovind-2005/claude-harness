#!/usr/bin/env bash
# PreToolUse (Edit|Write|NotebookEdit), registered by the discover skill.
# While docs/intent.md has "status: discovering", block edits to every file
# except docs/intent.md. Discover is for understanding, not building.
# Does nothing when docs/intent.md is absent or "status: decided".
# Exit 2 = block (stderr goes to Claude).

input=$(cat)
file=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$input" 2>/dev/null)
[ -z "$file" ] && exit 0

root="${CLAUDE_PROJECT_DIR:-$(jq -r '.cwd // empty' <<<"$input")}"
root="${root:-$PWD}"
intent="$root/docs/intent.md"
[ -f "$intent" ] || exit 0

# status from the frontmatter only (between the first two '---' lines)
status=$(tr -d '\r' < "$intent" | awk 'NR==1 && $0!="---" {exit} NR>1 && /^---[[:space:]]*$/ {exit}
  /^status[[:space:]]*:/ {sub(/^status[[:space:]]*:[[:space:]]*/,""); sub(/[[:space:]]+$/,""); gsub(/["'"'"']/,""); print tolower($0); exit}')
[ "$status" = "discovering" ] || exit 0

case "$file" in /*) abs="$file" ;; *) abs="$root/$file" ;; esac
# Compare physical paths (symlinks like /tmp -> /private/tmp).
phys() { local d; d=$(cd "$(dirname "$1")" 2>/dev/null && pwd -P) && printf '%s/%s' "$d" "$(basename "$1")" || printf '%s' "$1"; }
[ "$(phys "$abs")" = "$(phys "$intent")" ] && exit 0

{
  echo "BLOCKED by dev-harness discover: discovery is still open (docs/intent.md has 'status: discovering')."
  echo "Do not build yet. Only docs/intent.md may change until the user picks a direction."
  echo "To finish: agree on a direction with the user, then set 'status: decided' in docs/intent.md."
  echo "To abandon: tell the user; they can set 'status: decided' or delete docs/intent.md."
} >&2
exit 2
