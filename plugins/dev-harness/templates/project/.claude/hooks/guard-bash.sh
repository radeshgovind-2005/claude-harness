#!/usr/bin/env bash
# PreToolUse (Bash)
# Blocks dangerous shell commands. Asks the user for risky ones.
# Exit 2 = block (stderr goes to Claude). JSON "ask" = prompt the user.

# Profile settings live in harness.conf next to this script (written by dev-harness).
# Parsed, never sourced. Missing file or key = safe default.
conf() { # key default
  local f v
  f="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/harness.conf"
  v=$(grep -E "^$1=" "$f" 2>/dev/null | tail -n 1 | cut -d= -f2-)
  v="${v#\"}"; v="${v%\"}"
  if [ -n "$v" ] || grep -Eq "^$1=" "$f" 2>/dev/null; then printf '%s' "$v"; else printf '%s' "$2"; fi
}

input=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<<"$input")
[ -z "$cmd" ] && exit 0

block() {
  echo "BLOCKED: $1" >&2
  echo "Command: $cmd" >&2
  exit 2
}

ask() {
  jq -n --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}'
  exit 0
}

# --- Hard blocks ---
grep -Eq -- '--no-verify'                                  <<<"$cmd" && block "Do not skip git hooks (--no-verify)."
grep -Eq 'git[[:space:]]+push.*(--force|[[:space:]]-f([[:space:]]|$))' <<<"$cmd" && block "Force push is not allowed."
grep -Eq 'rm[[:space:]]+-[a-zA-Z]*r[a-zA-Z]*f?[a-zA-Z]*[[:space:]]+(/|~|\$HOME|\*)([[:space:]]|$)' <<<"$cmd" && block "Recursive delete of root, home, or * is not allowed."
grep -Eq '(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z)?sh' <<<"$cmd" && block "Do not pipe downloads into a shell."
grep -Eq '(^|[[:space:]/])\.env([[:space:]]|$|\.(local|dev|development|prod|production|staging|test))' <<<"$cmd" && block "Do not read or print .env files. Ask the user for the variable NAME you need."
grep -Eq 'git[[:space:]]+config.*core\.hooksPath' <<<"$cmd" && block "Do not change the git hooks path."

# --- Profile: BLOCK_MAIN=1 keeps main/master for reviewed merges only ---
if [ "$(conf BLOCK_MAIN 1)" = 1 ]; then
  grep -Eq 'git[[:space:]]+push.*[[:space:]:](main|master)([[:space:]]|$)' <<<"$cmd" && block "Do not push to main/master. Push a branch and open a PR."
fi

# --- Commit only on a feature branch (profile: BLOCK_MAIN=1) ---
if [ "$(conf BLOCK_MAIN 1)" = 1 ] && grep -Eq 'git[[:space:]]+commit' <<<"$cmd"; then
  cwd=$(jq -r '.cwd // empty' <<<"$input")
  branch=$(git -C "${cwd:-$PWD}" rev-parse --abbrev-ref HEAD 2>/dev/null)
  case "$branch" in
    main|master) block "Do not commit on '$branch'. Create a branch first." ;;
  esac
fi

# --- Ask the user first ---
grep -Eq 'git[[:space:]]+reset[[:space:]]+--hard'   <<<"$cmd" && ask "git reset --hard deletes uncommitted work."
grep -Eq 'git[[:space:]]+clean[[:space:]]+-[a-z]*f' <<<"$cmd" && ask "git clean deletes untracked files."
grep -Eiq '(drop|truncate)[[:space:]]+(table|database)' <<<"$cmd" && ask "This command deletes database data."

exit 0
