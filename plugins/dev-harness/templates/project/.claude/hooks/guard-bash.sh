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

# jq reads the tool input. Without it this guard cannot see what Claude is about to do, so it fails closed
# (blocks) and says how to fix that. It never lets a command through unchecked.
nojq_msg="BLOCKED: the dev-harness guard needs jq to read the tool input, and jq is missing or not working. Ask the user to install it (brew install jq, or apt install jq): Claude cannot, because this guard blocks every command until then."
command -v jq >/dev/null 2>&1 || { echo "$nojq_msg" >&2; exit 2; }

input=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<<"$input") || { echo "$nojq_msg" >&2; exit 2; }
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
cwd=$(jq -r '.cwd // empty' <<<"$input") || { echo "$nojq_msg" >&2; exit 2; }; cwd="${cwd:-$PWD}"
# symbolic-ref also names a branch that has no commit yet (rev-parse --abbrev-ref fails there), and the
# refs/heads/ prefix is cut by hand because --short gives "heads/main" when a tag is also called main.
branch=$(git -C "$cwd" symbolic-ref -q HEAD 2>/dev/null | sed "s,^refs/heads/,,")

# --- Hard blocks (every profile) ---
grep -Eq -- '--no-verify' <<<"$cmd" && block "Do not skip git hooks (--no-verify). Instead: fix what the hook reports, or ask the user to commit themselves."
# -n is the short form of --no-verify on git commit (also inside a group such as -nm or -anm). Quoted text
# (a commit message, an echo) is removed first, so "refactor -nested" or "$(git log -n 1)" in a message is fine.
# A message that spans several lines can still trigger this: reword it.
unquoted=$(sed -E "s/\"[^\"]*\"//g; s/'[^']*'//g" <<<"$cmd")
grep -Eq "${G}commit([[:space:]]+[^|;&]*)?[[:space:]]-[a-zA-Z]*n[a-zA-Z]*$E" <<<"$unquoted" && block "git commit -n skips the git hooks, like --no-verify. Instead: fix what the hook reports, or ask the user to commit themselves."
grep -Eq "${G}push.*([[:space:]]--force|[[:space:]]-[a-zA-Z]*f[a-zA-Z]*$E|[[:space:]]\+[^[:space:]])" <<<"$cmd" && block "Force push is not allowed (this includes -f, --force-with-lease and +refspec). Instead: push a new commit, or ask the user to force push themselves."
grep -Eq '(^|[;&|[:space:]])rm[[:space:]]' <<<"$cmd" \
  && grep -Eq '[[:space:]](-[a-zA-Z]*[rR][a-zA-Z]*|--recursive)([[:space:]]|$)' <<<"$cmd" \
  && grep -Eq "[[:space:]][\"']?(/|/\\*|\\*|~|~/|~/\\*|\\\$HOME|\\\$\\{HOME\\}|\\\$HOME/|\\\$HOME/\\*)[\"']?$E" <<<"$cmd" \
  && block "Recursive delete of root, home, or * is not allowed. Instead: delete the specific folder by name (for example rm -rf build)."
grep -Eq '(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z)?sh' <<<"$cmd" && block "Do not pipe downloads into a shell. Instead: download the script to a file, read it, and ask the user before running it."
grep -Eq '(ba|z)?sh[^;&|]*(\$\(|<\()[[:space:]]*(curl|wget)' <<<"$cmd" && block "Do not run downloaded scripts. Instead: download the script to a file, read it, and ask the user before running it."
grep -Eq "(^|[[:space:]/\"'=])\.env(\.(local|dev|development|prod|production|staging|test))?$E" <<<"$cmd" && block "Do not read or print .env files. Ask the user for the variable NAME you need."
grep -Eqi 'core\.hookspath' <<<"$cmd" && block "Do not change or override the git hooks path. Instead: ask the user to change it."

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
# A redirect to /dev/null or a file-descriptor copy (2>/dev/null, &>/dev/null, 2>&1) writes nothing,
# so it must not make a read-only command look like a write.
safe=$(sed -E 's/[0-9]*>&[0-9-]+//g; s/(&|[0-9]+)?>>?[[:space:]]*\/dev\/null//g' <<<"$cmd")
# Commands that write, move, delete or fetch into files. A best-effort list, not a sandbox: a command that
# is not on it (a script, an unusual tool) can still change the guardrails. Branch protection and CI on the
# Git host are the real backstop.
V='sed[[:space:]]+(-[a-zA-Z]*i|--in-place)[^[:space:]]*|perl[[:space:]]+-[a-zA-Z]*i[^[:space:]]*|awk[[:space:]].*inplace|rm|mv|cp|tee|truncate|chmod|ln|install|dd|touch|mkdir|patch|rsync|tar|unzip|cpio|vi|vim|nano|ed|ex|emacs|xargs|find[[:space:]].*(-delete|-exec)|(curl|wget)[[:space:]].*(-o|-O|--output|--output-document)|git[[:space:]]+(checkout|restore|apply|am|stash|merge|rebase|pull|cherry-pick|revert|reset|clean)|(python[0-9.]*|node|ruby|perl|php)[[:space:]]+-[a-zA-Z]*[ce]'
if grep -Eqi "$P" <<<"$cmd" && grep -Eqi "(>|(^|[;&|[:space:]])($V)([[:space:]]|$))" <<<"$safe"; then
  ask "This command may change .claude/hooks/ or .claude/settings.json (the guardrails). Only the user should approve that."
fi

# --- Ask the user first ---
grep -Eq 'git[[:space:]]+reset[[:space:]]+--hard'   <<<"$cmd" && ask "git reset --hard deletes uncommitted work."
grep -Eq 'git[[:space:]]+clean[[:space:]]+-[a-z]*f' <<<"$cmd" && ask "git clean deletes untracked files."
grep -Eiq '(drop|truncate)[[:space:]]+(table|database)' <<<"$cmd" && ask "This command deletes database data."

exit 0
