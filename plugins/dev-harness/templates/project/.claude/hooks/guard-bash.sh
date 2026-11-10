#!/usr/bin/env bash
# PreToolUse (Bash)
# Blocks dangerous shell commands. Asks the user for risky ones.
# Exit 2 = block (stderr goes to Claude). JSON "ask" = prompt the user.

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

# These catch common mistakes, not deliberate bypass (enforce on the Git host too).
# `git` may carry global options before the subcommand: git -C dir / -c k=v / --no-pager ...
G='git([[:space:]]+(-[Cc][[:space:]]+[^[:space:]]+|--?[a-z][a-z-]*(=[^[:space:]]*)?))*[[:space:]]+'
E='([[:space:]]|$|[;&|)"'"'"'])'          # end of a word
cwd=$(jq -r '.cwd // empty' <<<"$input"); cwd="${cwd:-$PWD}"
branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)

# --- Hard blocks (every profile) ---
grep -Eq -- '--no-verify' <<<"$cmd" && block "Do not skip git hooks (--no-verify)."
grep -Eq "${G}push.*([[:space:]]--force|[[:space:]]-[a-zA-Z]*f[a-zA-Z]*$E|[[:space:]]\+[^[:space:]])" <<<"$cmd" && block "Force push is not allowed (this includes -f, --force-with-lease and +refspec)."
grep -Eq '(^|[;&|[:space:]])rm[[:space:]]' <<<"$cmd" \
  && grep -Eq '[[:space:]](-[a-zA-Z]*[rR][a-zA-Z]*|--recursive)([[:space:]]|$)' <<<"$cmd" \
  && grep -Eq "[[:space:]][\"']?(/|/\\*|\\*|~|~/|~/\\*|\\\$HOME|\\\$\\{HOME\\}|\\\$HOME/|\\\$HOME/\\*)[\"']?$E" <<<"$cmd" \
  && block "Recursive delete of root, home, or * is not allowed."
grep -Eq '(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z)?sh' <<<"$cmd" && block "Do not pipe downloads into a shell."
grep -Eq '(ba|z)?sh[^;&|]*(\$\(|<\()[[:space:]]*(curl|wget)' <<<"$cmd" && block "Do not run downloaded scripts."
grep -Eq "(^|[[:space:]/\"'=])\.env(\.(local|dev|development|prod|production|staging|test))?$E" <<<"$cmd" && block "Do not read or print .env files. Ask the user for the variable NAME you need."
grep -Eqi 'core\.hookspath' <<<"$cmd" && block "Do not change or override the git hooks path."

# --- Profile: main/master kept for reviewed merges only (BLOCK_MAIN, default on) ---
if main_protected; then
  if grep -Eq "${G}push" <<<"$cmd"; then
    grep -Eq "[[:space:]:/](main|master)$E" <<<"$cmd" && block "Do not push to main/master. Push a branch and open a PR."
    if [ "$branch" = main ] || [ "$branch" = master ]; then
      # On main: a push with no explicit branch (or HEAD) pushes main.
      # (No case/esac here: bash 3.2 misparses parentheses inside $() in a case arm.)
      args=$(sed -E "s/.*${G}push//" <<<"$cmd" | tr ' ' '\n' | grep -v '^-' | grep -c .)
      if [ "$args" -le 1 ] || grep -Eq "[[:space:]]HEAD$E" <<<"$cmd"; then
        block "You are on '$branch': this push would update '$branch'. Push a branch and open a PR."
      fi
    fi
  fi
  if grep -Eq "${G}commit" <<<"$cmd"; then
    case "$branch" in main|master) block "Do not commit on '$branch'. Create a branch first." ;; esac
  fi
fi

# --- Guardrail config: only the user changes it ---
P='\.claude/(hooks/|settings\.json)'
if grep -Eqi "$P" <<<"$cmd" && grep -Eqi "(>|(^|[;&|[:space:]])(sed[[:space:]]+-[a-z]*i|perl[[:space:]]+-[a-z]*i|rm|mv|cp|tee|truncate|chmod|ln|install|dd)[[:space:]])" <<<"$cmd"; then
  ask "This command may change .claude/hooks/ or .claude/settings.json (the guardrails). Only the user should approve that."
fi

# --- Ask the user first ---
grep -Eq 'git[[:space:]]+reset[[:space:]]+--hard'   <<<"$cmd" && ask "git reset --hard deletes uncommitted work."
grep -Eq 'git[[:space:]]+clean[[:space:]]+-[a-z]*f' <<<"$cmd" && ask "git clean deletes untracked files."
grep -Eiq '(drop|truncate)[[:space:]]+(table|database)' <<<"$cmd" && ask "This command deletes database data."

exit 0
