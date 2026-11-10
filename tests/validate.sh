#!/usr/bin/env bash
# Validates the marketplace and every plugin in it.
# Run from anywhere:  bash tests/validate.sh
# Exit 0 only if every check passed. Skipped checks are reported loudly.
# Set REQUIRE_CLAUDE=1 to make a missing `claude` CLI a failure (not a skip).
# shellcheck disable=SC2319  # `[ test ]; check name $?` reads the test's status on purpose

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
pass=0; fail=0; skip=0

ok()   { echo "  PASS  $1"; pass=$((pass+1)); }
bad()  { echo "  FAIL  $1"; fail=$((fail+1)); }
skp()  { echo "  SKIP  $1"; skip=$((skip+1)); }
check() { if [ "$2" = 0 ]; then ok "$1"; else bad "$1"; fi; }  # name status

command -v jq >/dev/null || { echo "Error: jq is required."; exit 1; }

MKT=".claude-plugin/marketplace.json"

echo "JSON syntax"
while IFS= read -r f; do
  jq empty "$f" 2>/dev/null; check "$f parses" $?
done < <(find . -name '*.json' -not -path './.git/*' -not -path '*/node_modules/*' | sort)

echo "Marketplace"
[ -f "$MKT" ]; check "$MKT exists" $?
[ "$(jq -r '.owner.name // empty' "$MKT")" != "" ]; check "owner.name is set" $?
n=$(jq '.plugins | length' "$MKT"); [ "${n:-0}" -gt 0 ]; check "lists at least one plugin ($n)" $?
v=$(jq '[.plugins[] | select(has("version"))] | length' "$MKT")
[ "$v" = 0 ]; check "no version in marketplace entries (plugin.json owns it)" $?

plugins=()
while IFS=$'\t' read -r name src; do
  plugins+=("$src")
  echo "Plugin '$name' ($src)"
  pj="$src/.claude-plugin/plugin.json"
  [ -f "$pj" ]; check "plugin.json exists" $?
  [ "$(jq -r '.name // empty' "$pj" 2>/dev/null)" = "$name" ]; check "plugin.json name matches entry" $?
  [[ "$(jq -r '.version // empty' "$pj" 2>/dev/null)" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; check "plugin.json version is semver" $?

  extra=$(find "$src/.claude-plugin" -mindepth 1 -not -name plugin.json -not -name 'icon.png')
  [ -z "$extra" ]; check ".claude-plugin/ holds only plugin.json${extra:+ (found: $extra)}" $?

  [ ! -e "$src/hooks" ]; check "plugin ships no hooks/ (strict hooks go into projects only)" $?

  for d in "$src"/skills/*/; do
    [ -d "$d" ] || continue
    s="${d%/}"; sn=$(basename "$s")
    if [ -f "$s/SKILL.md" ] && head -1 "$s/SKILL.md" | grep -qx -- '---' \
       && sed -n '2,/^---$/p' "$s/SKILL.md" | grep -Eq '^description:[[:space:]]*[^[:space:]]'; then
      ok "skill '$sn' has SKILL.md with description"
    else
      bad "skill '$sn' has SKILL.md with frontmatter description"
    fi
  done

  for a in "$src"/agents/*.md; do
    [ -f "$a" ] || continue
    sed -n '2,/^---$/p' "$a" | grep -Eq '^description:'; check "agent '$(basename "$a" .md)' has description" $?
  done

  # kebab-case: lowercase letters, digits, hyphens (dots for extensions).
  # Allowed exceptions: SKILL.md, README.md, CHANGELOG.md, LICENSE, leading-dot names.
  badnames=$(find "$src" -mindepth 1 \
    -not -name 'SKILL.md' -not -name 'README.md' -not -name 'CHANGELOG.md' -not -name 'LICENSE' \
    -not -name '.*' -not -name '.DS_Store' \
    | while IFS= read -r p; do b=$(basename "$p"); [[ "$b" =~ ^[a-z0-9]+(-[a-z0-9]+)*(\.[a-z0-9]+)*$ ]] || echo "$p"; done)
  [ -z "$badnames" ]; check "all file and folder names are kebab-case${badnames:+ (bad: $badnames)}" $?
done < <(jq -r '.plugins[] | [.name, .source] | @tsv' "$MKT")

echo "Claude Code validator"
if command -v claude >/dev/null; then
  run_validate() { # label args...
    local label="$1"; shift
    local out st
    out=$(claude plugin validate "$@" 2>&1); st=$?
    check "$label" $st
    [ $st -ne 0 ] && echo "$out" | tail -30
  }
  run_validate "claude plugin validate --strict . (marketplace)" --strict .
  for src in "${plugins[@]}"; do
    run_validate "claude plugin validate --strict $src" --strict "$src"
    # Directory profile: fails on problems the public catalog refuses (e.g. missing README).
    # Not combined with --strict, because that would also fail on the optional icon warning.
    run_validate "claude plugin validate --profile directory $src" --profile directory "$src"
  done
elif [ "${REQUIRE_CLAUDE:-0}" = 1 ]; then
  bad "claude CLI not found and REQUIRE_CLAUDE=1"
else
  skp "claude CLI not found: claude plugin validate NOT RUN"
fi

echo
echo "Result: $pass passed, $fail failed, $skip skipped"
[ "$skip" -gt 0 ] && echo "WARNING: $skip check(s) skipped. This run does not prove the plugin is valid."
[ "$fail" -eq 0 ]
