#!/usr/bin/env bash
# PreToolUse (Edit|Write|MultiEdit|NotebookEdit)
# Blocks edits to protected paths, and all edits on protected branches.
# Exit 2 = block. The stderr message goes back to Claude.

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
file=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$input")
[ -z "$file" ] && exit 0

root="${CLAUDE_PROJECT_DIR:-$PWD}"
rel="${file#"$root"/}"
base=$(basename "$file")

# --- 1. Allowed exceptions (checked first) ---
case "$base" in
  .env.example|.env.sample|.env.template) exit 0 ;;
esac

# --- 2. Protected paths ---
protected=(
  ".env" ".env.*"                                   # secrets
  "*.pem" "*.key" "id_rsa*"                         # keys
  "package-lock.json" "pnpm-lock.yaml" "yarn.lock"  # lockfiles: change only via the package manager
  "poetry.lock" "uv.lock" "Cargo.lock"
)
for p in "${protected[@]}"; do
  # shellcheck disable=SC2053
  if [[ "$base" == $p ]]; then
    echo "BLOCKED: '$rel' is a protected file ($p). Do not edit it. Tell the user what change is needed." >&2
    exit 2
  fi
done

# Protected folders (relative to project root)
case "$rel" in
  .git/*|.claude/hooks/*|.claude/settings.json|secrets/*)
    echo "BLOCKED: '$rel' is in a protected location. Only the user edits this." >&2
    exit 2 ;;
esac

# --- 3. Protected branches (profile: BLOCK_MAIN=1) ---
# Check the branch where the file lives (works inside git worktrees).
[ "$(conf BLOCK_MAIN 1)" = 1 ] || exit 0
dir=$(dirname "$file")
while [ ! -d "$dir" ] && [ "$dir" != "/" ]; do dir=$(dirname "$dir"); done
if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
  case "$branch" in
    main|master)
      echo "BLOCKED: you are on '$branch'. Create a branch or worktree first (git switch -c <name>)." >&2
      exit 2 ;;
  esac
fi

exit 0
