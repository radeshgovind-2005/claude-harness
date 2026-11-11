#!/usr/bin/env bash
# The one parser for .claude/hooks/harness.conf (written by dev-harness). Not a hook: nothing registers it.
# Used by protect-paths.sh, guard-bash.sh and verify.sh, and by the dev-harness-hooks CI workflow, so CI
# reads the file exactly the way the hooks do.
#
#   Sourced:  . .claude/hooks/harness-conf.sh      defines conf and main_protected
#   Run:      bash .claude/hooks/harness-conf.sh KEY DEFAULT    prints the value of KEY
#
# harness.conf is parsed, never sourced. Rules: CR is dropped; spaces before the key and around '=' are
# allowed; the value is trimmed and one pair of surrounding double quotes is removed; the last line for a
# key wins. A missing file or key gives DEFAULT.

case "${BASH_SOURCE[0]}" in */*) _harness_conf_file="${BASH_SOURCE[0]%/*}" ;; *) _harness_conf_file=. ;; esac
_harness_conf_file="$(cd "$_harness_conf_file" && pwd)/harness.conf"   # builtins only: no dirname

conf() { # key default -> value
  local v
  grep -Eq "^[[:space:]]*$1[[:space:]]*=" "$_harness_conf_file" 2>/dev/null || { printf '%s' "$2"; return; }
  v=$(tr -d '\r' < "$_harness_conf_file" | grep -E "^[[:space:]]*$1[[:space:]]*=" | tail -n 1 | cut -d= -f2-)
  v="${v#"${v%%[![:space:]]*}"}"; v="${v%"${v##*[![:space:]]}"}"
  case "$v" in \"*\") v="${v#\"}"; v="${v%\"}" ;; esac
  printf '%s' "$v"
}

# Main-branch protection is off only for an explicit 0. Anything else (typo, "true", empty) keeps it on.
main_protected() { [ "$(conf BLOCK_MAIN 1)" != 0 ]; }

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  [ $# -eq 2 ] || { echo "usage: bash $0 KEY DEFAULT" >&2; exit 2; }
  conf "$1" "$2"
fi
