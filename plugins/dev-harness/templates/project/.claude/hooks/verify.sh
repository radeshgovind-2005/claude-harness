#!/usr/bin/env bash
# Stop
# Runs a FAST check (typecheck + lint) when Claude tries to finish.
# If the check fails, exit 2: Claude cannot stop and must fix the errors.
# This enforces "never say done without verification".

# >>> EDIT THIS: a fast command (< 60 s). Leave empty to disable. <<<
VERIFY_CMD=""
# Examples:
# VERIFY_CMD="npm run typecheck && npm run lint"
# VERIFY_CMD="ruff check . && mypy ."

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
