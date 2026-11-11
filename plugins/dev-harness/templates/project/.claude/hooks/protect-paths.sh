#!/usr/bin/env bash
# PreToolUse (Edit|Write|MultiEdit|NotebookEdit)
# Blocks edits to protected paths, and all edits on protected branches.
# Exit 2 = block. The stderr message goes back to Claude.

# Profile settings live in harness.conf next to this script (written by dev-harness). harness-conf.sh,
# also next to it, parses that file (never sources it) and is shared with the CI workflow. Without the
# parser this guard cannot tell which profile is on, so it fails closed (blocks) and says how to fix it.
# Builtins only (no dirname): this must work even when PATH is broken, so the jq check below can speak.
case "${BASH_SOURCE[0]}" in */*) here="${BASH_SOURCE[0]%/*}" ;; *) here=. ;; esac; here=$(cd "$here" && pwd)
if ! { [ -f "$here/harness-conf.sh" ] && . "$here/harness-conf.sh" && type main_protected >/dev/null 2>&1; }; then
  echo "BLOCKED: .claude/hooks/harness-conf.sh (the dev-harness config parser) is missing or broken, so this guard cannot read the profile. Ask the user to restore it (run /dev-harness:add guardrails, or copy it from the plugin's templates): Claude cannot, because .claude/hooks/ is protected." >&2
  exit 2
fi

# jq reads the tool input. Without it this guard cannot see what Claude is about to do, so it fails closed
# (blocks) and says how to fix that. It never lets a command through unchecked.
nojq_msg="BLOCKED: the dev-harness guard needs jq to read the tool input, and jq is missing or not working. Ask the user to install it (brew install jq, or apt install jq): Claude cannot, because this guard blocks every command until then."
command -v jq >/dev/null 2>&1 || { echo "$nojq_msg" >&2; exit 2; }

input=$(cat)
file=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$input") || { echo "$nojq_msg" >&2; exit 2; }
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

# Lower-case BOTH sides before the root is stripped: bash's `pwd -P` keeps the case it was given, so a
# project dir spelled /Users/me/App and a file path /users/me/app/... would not share a prefix and the
# folder rules below would never match.
root=$(lower "$(normpath "${CLAUDE_PROJECT_DIR:-$PWD}")")
file=$(normpath "$file")
rel=$(lower "$file"); rel="${rel#"$root"/}"
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
  # symbolic-ref also names a branch that has no commit yet (rev-parse --abbrev-ref fails there).
  branch=$(git -C "$dir" symbolic-ref -q HEAD 2>/dev/null | sed "s,^refs/heads/,,")
  case "$branch" in
    main|master)
      echo "BLOCKED: you are on '$branch'. Create a branch or worktree first (git switch -c <name>)." >&2
      exit 2 ;;
  esac
fi

exit 0
