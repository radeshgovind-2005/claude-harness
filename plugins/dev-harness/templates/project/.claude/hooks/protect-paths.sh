#!/usr/bin/env bash
# PreToolUse (Edit|Write|MultiEdit|NotebookEdit)
# Blocks edits to protected paths, and all edits on protected branches.
# Exit 2 = block. The stderr message goes back to Claude.

# Profile settings live in harness.conf next to this script (written by dev-harness).
# Parsed, never sourced. Missing file or key = safe default.
conf() { # key default -> value (CR, surrounding spaces and quotes stripped)
  local f v
  f="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/harness.conf"
  grep -Eq "^[[:space:]]*$1[[:space:]]*=" "$f" 2>/dev/null || { printf '%s' "$2"; return; }
  v=$(tr -d '\r' < "$f" | grep -E "^[[:space:]]*$1[[:space:]]*=" | tail -n 1 | cut -d= -f2-)
  v="${v#"${v%%[![:space:]]*}"}"; v="${v%"${v##*[![:space:]]}"}"
  case "$v" in \"*\") v="${v#\"}"; v="${v%\"}" ;; esac
  printf '%s' "$v"
}
# Main-branch protection is off only for an explicit 0. Anything else (typo, "true", empty) keeps it on.
main_protected() { [ "$(conf BLOCK_MAIN 1)" != 0 ]; }

input=$(cat)
file=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$input")
[ -z "$file" ] && exit 0

# Normalize: resolve . and .., duplicate slashes and symlinks, then compare in
# lower case (macOS file systems are case-insensitive by default).
normpath() { # path -> absolute physical path (works for files that do not exist yet)
  local p="$1" out="" part rest=""
  case "$p" in /*) ;; *) p="$PWD/$p" ;; esac
  local IFS=/
  for part in $p; do
    case "$part" in ""|.) ;; ..) out="${out%/*}" ;; *) out="$out/$part" ;; esac
  done
  p="${out:-/}"
  while [ ! -d "$p" ] && [ "$p" != "/" ]; do rest="/${p##*/}$rest"; p="${p%/*}"; p="${p:-/}"; done
  p=$(cd "$p" 2>/dev/null && pwd -P) || p="${out:-/}"
  printf '%s%s' "${p%/}" "$rest"
}
lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

root=$(normpath "${CLAUDE_PROJECT_DIR:-$PWD}")
file=$(normpath "$file")
rel=$(lower "${file#"$root"/}")
base=$(lower "$(basename "$file")")

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
main_protected || exit 0
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
