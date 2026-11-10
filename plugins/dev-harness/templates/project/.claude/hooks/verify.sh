#!/usr/bin/env bash
# Stop
# Runs a FAST check (typecheck + lint) when Claude tries to finish.
# If the check fails, exit 2: Claude cannot stop and must fix the errors.
# This enforces "never say done without verification".

# The command comes from VERIFY_CMD in harness.conf (next to this script).
# Empty or missing = off. Keep it fast (< 60 s). Examples:
#   VERIFY_CMD="npm run typecheck && npm run lint"
#   VERIFY_CMD="ruff check . && mypy ."

# Profile settings live in harness.conf next to this script (written by dev-harness).
# Parsed, never sourced. Missing file or key = safe default.
conf() { # key default
  local f v
  f="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/harness.conf"
  v=$(grep -E "^$1=" "$f" 2>/dev/null | tail -n 1 | cut -d= -f2-)
  v="${v#\"}"; v="${v%\"}"
  if [ -n "$v" ] || grep -Eq "^$1=" "$f" 2>/dev/null; then printf '%s' "$v"; else printf '%s' "$2"; fi
}
VERIFY_CMD=$(conf VERIFY_CMD "")

input=$(cat)

# Prevent an infinite loop: if Claude is already continuing because of
# this hook, let it stop. It must report the failure to the user.
[ "$(jq -r '.stop_hook_active // false' <<<"$input")" = "true" ] && exit 0

[ -z "$VERIFY_CMD" ] && exit 0

root="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$root" || exit 0

# Skip if nothing changed in this repo.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  [ -z "$(git status --porcelain 2>/dev/null)" ] && exit 0
fi

output=$(bash -c "$VERIFY_CMD" 2>&1)
status=$?

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
