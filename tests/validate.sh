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
SKILL_HOOK_ALLOW="discover goal"   # skills allowed to declare frontmatter hooks (each is state-gated)
AGENT_EDIT_ALLOW=""                # agents allowed to have edit tools (none: every agent in this plugin is a read-only reviewer)

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

# Every entry must have a local "./" string source; otherwise this script cannot check it.
nonlocal=$(jq -r '.plugins[] | select((.source | type) != "string" or (.source | startswith("./") | not)) | .name' "$MKT")
[ -z "$nonlocal" ]; check "every plugin source is a local ./ path${nonlocal:+ (not checkable: $nonlocal)}" $?

# frontmatter FILE: print lines between the opening and closing '---'; exit 1 if either is missing.
frontmatter() {
  awk 'NR==1 { if ($0 != "---") exit 1; next } /^---$/ { closed=1; exit } { print } END { exit !closed }' "$1"
}
# has_description FILE: closed frontmatter with a non-empty description: line.
has_description() {
  local fm; fm=$(frontmatter "$1") || return 1
  grep -Eq '^description:[[:space:]]*[^[:space:]]' <<<"$fm"
}

plugins=()
while IFS=$'\t' read -r name src; do
  [ -n "$src" ] || continue
  plugins+=("$src")
  echo "Plugin '$name' ($src)"
  pj="$src/.claude-plugin/plugin.json"
  [ -f "$pj" ]; check "plugin.json exists" $?
  [ "$(jq -r '.name // empty' "$pj" 2>/dev/null)" = "$name" ]; check "plugin.json name matches entry" $?
  ver=$(jq -r '.version // empty' "$pj" 2>/dev/null)
  [[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; check "plugin.json version is semver" $?
  top=$(grep -Eom1 '^## [0-9]+\.[0-9]+\.[0-9]+' CHANGELOG.md 2>/dev/null | cut -c4-)
  [ "$top" = "$ver" ]; check "CHANGELOG top entry ($top) matches plugin.json version ($ver)" $?

  extra=$(find "$src/.claude-plugin" -mindepth 1 -not -name plugin.json -not -name 'icon.png')
  [ -z "$extra" ]; check ".claude-plugin/ holds only plugin.json${extra:+ (found: $extra)}" $?

  # The plugin ships no hooks in any form: hooks/ folder, any hooks.json,
  # a "hooks" key in plugin.json, or hooks: in skill/agent frontmatter.
  # Exceptions: templates/ (copied INTO projects, never loaded by Claude Code),
  # and skills listed in SKILL_HOOK_ALLOW (state-gated, documented in the skill).
  hookfiles=$(find "$src" -path "$src/templates" -prune -o \( -name hooks.json -o -type d -name hooks \) -print)
  [ -z "$hookfiles" ]; check "no hooks/ folder or hooks.json in plugin${hookfiles:+ (found: $hookfiles)}" $?
  if jq -e 'has("hooks")' "$pj" >/dev/null 2>&1; then bad "plugin.json declares no hooks"; else ok "plugin.json declares no hooks"; fi
  fmhooks=$(find "$src" -name '*.md' -path '*/skills/*' -o -name '*.md' -path '*/agents/*' | while IFS= read -r m; do
    sk=$(basename "$(dirname "$m")")
    [[ " $SKILL_HOOK_ALLOW " == *" $sk "* && "$(basename "$m")" == SKILL.md ]] && continue
    frontmatter "$m" 2>/dev/null | grep -Eq '^hooks:' && echo "$m"; done)
  [ -z "$fmhooks" ]; check "no hooks: in skill/agent frontmatter${fmhooks:+ (found: $fmhooks)}" $?

  for d in "$src"/skills/*/; do
    [ -d "$d" ] || continue
    s="${d%/}"; sn=$(basename "$s")
    # Exact-case name check: macOS file systems are case-insensitive, Linux is not.
    if find "$s" -maxdepth 1 -type f -name SKILL.md | grep -q . \
       && has_description "$s/SKILL.md"; then
      ok "skill '$sn' has SKILL.md with closed frontmatter and description"
    else
      bad "skill '$sn' has SKILL.md (exact case) with closed frontmatter and description"
    fi
    # Write(path), MultiEdit(path) and NotebookEdit(path) permission rules are accepted but never match
    # (permissions docs: "use Edit(docs/**) in place of Write(docs/**)"); an Edit(path) rule covers every
    # file-edit tool. A dead rule would make a skill look pre-approved when it is not.
    deadrules=$(frontmatter "$s/SKILL.md" 2>/dev/null | sed -n 's/^allowed-tools:[[:space:]]*//p' | grep -Eo '(Write|MultiEdit|NotebookEdit)\([^)]*\)' | tr '\n' ' ')
    [ -z "$deadrules" ]; check "skill '$sn' allowed-tools has no Write/MultiEdit/NotebookEdit path rule (use Edit(path))${deadrules:+ (found: $deadrules)}" $?
  done

  for a in "$src"/agents/*.md; do
    [ -f "$a" ] || continue
    an=$(basename "$a" .md)
    has_description "$a"; check "agent '$an' has closed frontmatter and description" $?
    afm=$(frontmatter "$a" 2>/dev/null)
    # Plugin agents ignore hooks, mcpServers and permissionMode, so they must not pretend to use them.
    ! grep -Eq '^(hooks|mcpServers|permissionMode):' <<<"$afm"; check "agent '$an' sets no hooks, mcpServers or permissionMode (ignored for plugin agents)" $?
    # An agent must list its tools. A missing list would inherit every tool, edit tools included.
    tools=$(sed -n 's/^tools:[[:space:]]*//p' <<<"$afm")
    [ -n "$tools" ]; check "agent '$an' declares a tools list" $?
    # A reviewer that must not edit gets no edit tools. This applies to EVERY agent, so a new agent cannot
    # slip in with Edit or Write; to allow one on purpose, list it in AGENT_EDIT_ALLOW above.
    if [[ " $AGENT_EDIT_ALLOW " != *" $an "* ]]; then
      ! grep -Eqi '(^|[ ,])(Edit|Write|MultiEdit|NotebookEdit)([ ,(]|$)' <<<"$tools"; check "agent '$an' has no edit tools (tools: $tools)" $?
    fi
  done

  # help must not call something "available" that does not exist, and must list every skill and agent.
  help="$src/skills/help/SKILL.md"
  if [ -f "$help" ]; then
    avail=$(awk -F'|' '/^\| `/ { st=$(NF-1); gsub(/ /, "", st); if (st == "available") { h=$2; gsub(/[` ]/, "", h); sub(/<.*/, "", h); print h } }' "$help")
    missing=""
    for hn in $avail; do
      [ -f "$src/skills/$hn/SKILL.md" ] || [ -f "$src/agents/$hn.md" ] || missing="$missing $hn"
    done
    [ -n "$avail" ] && [ -z "$missing" ]; check "help: every skill/agent marked available exists${missing:+ (missing:$missing)}" $?
    unlisted=""
    for d in "$src"/skills/*/; do hn=$(basename "$d"); grep -q "^| \`${hn}[ \`<]" "$help" || unlisted="$unlisted $hn"; done
    for f in "$src"/agents/*.md; do [ -f "$f" ] || continue; hn=$(basename "$f" .md); grep -q "^| \`$hn\`" "$help" || unlisted="$unlisted $hn"; done
    [ -z "$unlisted" ]; check "help lists every skill and agent${unlisted:+ (not listed:$unlisted)}" $?
  fi

  # kebab-case: lowercase letters, digits, hyphens (dots for extensions).
  # Allowed exceptions: names Claude Code or convention require (SKILL.md, CLAUDE.md,
  # INDEX.md, README.md, CHANGELOG.md, LICENSE) and leading-dot names.
  badnames=$(find "$src" -mindepth 1 \
    -not -name 'SKILL.md' -not -name 'CLAUDE.md' -not -name 'INDEX.md' \
    -not -name 'README.md' -not -name 'CHANGELOG.md' -not -name 'LICENSE' \
    -not -name '.*' -not -name '.DS_Store' \
    | while IFS= read -r p; do b=$(basename "$p"); [[ "$b" =~ ^[a-z0-9]+(-[a-z0-9]+)*(\.[a-z0-9]+)*$ ]] || echo "$p"; done)
  [ -z "$badnames" ]; check "all file and folder names are kebab-case${badnames:+ (bad: $badnames)}" $?
done < <(jq -r '.plugins[] | select(.source | type == "string") | [.name, .source] | @tsv' "$MKT")
[ "${#plugins[@]}" = "${n:-0}" ]; check "checked every plugin entry (${#plugins[@]} of ${n:-0})" $?

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
    pname=$(jq -r .name "$src/.claude-plugin/plugin.json")
    det=$(claude --plugin-dir "$src" plugin details "$pname" 2>&1)
    grep -Eq '^[[:space:]]*Hooks \(0\)' <<<"$det"; check "claude plugin details: $pname loads Hooks (0)" $?
    nsk=$(find "$src/skills" -mindepth 2 -maxdepth 2 -name SKILL.md 2>/dev/null | wc -l | tr -d ' ')
    nag=$(find "$src/agents" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
    grep -Eq "^[[:space:]]*Skills \($nsk\)" <<<"$det"; check "claude plugin details: $pname loads Skills ($nsk)" $?
    grep -Eq "^[[:space:]]*Agents \($nag\)" <<<"$det"; check "claude plugin details: $pname loads Agents ($nag)" $?
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
