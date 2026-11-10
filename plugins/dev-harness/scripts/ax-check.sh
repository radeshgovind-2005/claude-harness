#!/usr/bin/env bash
# dev-harness ax-check: facts about how well a project works for an AI agent (agent experience).
# Usage: ax-check.sh [project-dir]
# Prints one line per check:  PASS|WARN|FAIL  <name> — <detail>
# then:                       SUMMARY pass=N warn=N fail=N
# Exit 1 if any check is FAIL. WARN means "worth fixing", FAIL means "an agent will hit this".
# It reads files only; it runs none of the project's commands.

DEST="${1:-.}"
[ -d "$DEST" ] || { echo "FAIL    project dir not found: $DEST" >&2; exit 1; }
cd "$DEST" || exit 1

p=0; w=0; f=0
say() { printf '%-5s %s — %s\n' "$1" "$2" "$3"; case "$1" in PASS) p=$((p+1)) ;; WARN) w=$((w+1)) ;; FAIL) f=$((f+1)) ;; esac; }

# conf KEY: value from .claude/hooks/harness.conf (CR, spaces and quotes stripped); empty if absent.
conf() {
  [ -f .claude/hooks/harness.conf ] || return 0
  tr -d '\r' < .claude/hooks/harness.conf | grep -E "^[[:space:]]*$1[[:space:]]*=" | tail -n 1 | cut -d= -f2- \
    | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//'
}

# 1. The router
if [ ! -f CLAUDE.md ]; then
  say FAIL "CLAUDE.md" "missing: an agent starts with no project rules"
else
  n=$(wc -l < CLAUDE.md | tr -d ' ')
  if [ "$n" -lt 100 ]; then say PASS "CLAUDE.md length" "$n lines (limit 100)"
  else say FAIL "CLAUDE.md length" "$n lines; the router must stay under 100 or it is skimmed"; fi

  # 2. Every routed path exists (docs/intent.md has its own check below: only discover creates it)
  missing=""; count=0
  # Candidates: backticked docs/ and .claude/ paths. Not checked: globs (docs/plans/*.md), placeholders,
  # docs/intent.md (own check below), and files that are optional by design (local settings).
  # A trailing #anchor or :line is stripped first.
  while IFS= read -r path; do
    count=$((count+1))
    [ -e "$path" ] || missing="$missing $path"
  done < <(grep -o '`[^` ]*`' CLAUDE.md | tr -d '`' | sed -E 's/#.*$//; s/:[0-9]+(-[0-9]+)?$//' \
           | grep -E '^(docs/|\.claude/)' | grep -v '[<*?[]' | grep -vx 'docs/intent.md' \
           | grep -vx '\.claude/settings\.local\.json' | sort -u)
  if [ -z "$missing" ]; then say PASS "routed paths exist" "$count path(s) in CLAUDE.md checked"
  else say FAIL "routed paths exist" "CLAUDE.md points at missing:$missing"; fi

  # 3. Placeholders still in the file
  ph=$(grep -cE '<(cmd|project-name|one-line purpose|language>, <framework|one project-specific)' CLAUDE.md)
  if [ "$ph" = 0 ]; then say PASS "CLAUDE.md placeholders" "none left"
  else say WARN "CLAUDE.md placeholders" "$ph line(s) still have <placeholders>: an agent cannot run '<cmd>'"; fi
fi

# 4. Guardrails wired to files that exist and run
if [ -f .claude/settings.json ] && command -v jq >/dev/null && ! jq empty .claude/settings.json 2>/dev/null; then
  say FAIL "hooks registered" ".claude/settings.json is not valid JSON: Claude Code ignores it, so no guardrail runs"
elif [ -f .claude/settings.json ]; then
  bad=""; n=0
  while IFS= read -r h; do
    n=$((n+1))
    [ -x "$h" ] || bad="$bad $h"
  done < <(grep -o '\.claude/hooks/[A-Za-z0-9._-]*\.sh' .claude/settings.json | sort -u)
  if [ "$n" = 0 ]; then say WARN "hooks registered" ".claude/settings.json registers no .claude/hooks scripts"
  elif [ -z "$bad" ]; then say PASS "hooks registered" "$n hook script(s) exist and are executable"
  else say FAIL "hooks registered" "settings.json names hooks that are missing or not executable:$bad"; fi
else
  say WARN "hooks registered" "no .claude/settings.json: no guardrails in this project"
fi

# 5. Profile config
if [ -f .claude/hooks/harness.conf ]; then
  prof=$(conf PROFILE)
  case "$prof" in
    prototype|product|assignment) say PASS "harness.conf profile" "$prof" ;;
    *) say WARN "harness.conf profile" "PROFILE is '${prof:-unset}', expected prototype, product or assignment" ;;
  esac
  case "$prof" in
    product|assignment)
      if [ -n "$(conf VERIFY_CMD)" ]; then say PASS "VERIFY_CMD" "set: $(conf VERIFY_CMD)"
      else say WARN "VERIFY_CMD" "empty for the $prof profile: nothing checks the work when the agent stops"; fi ;;
  esac
else
  say WARN "harness.conf profile" "no .claude/hooks/harness.conf"
fi

# 6. Memory files
if [ -f docs/intent.md ]; then
  st=$(tr -d '\r' < docs/intent.md | awk 'NR==1 && $0!="---" {exit} NR>1 && /^---[[:space:]]*$/ {exit} /^status[[:space:]]*:/ {sub(/^status[[:space:]]*:[[:space:]]*/,""); gsub(/["'"'"']/,""); print tolower($0); exit}')
  if [ "$st" = decided ]; then say PASS "docs/intent.md" "status: decided"
  else say WARN "docs/intent.md" "status is '${st:-unset}': agents are told to read a decision that is not made"; fi
else
  say WARN "docs/intent.md" "missing: agents do not know who this is for (run /dev-harness:discover)"
fi
for doc in docs/progress.md docs/lessons.md; do
  if [ -f "$doc" ]; then say PASS "$doc" "present"
  else say WARN "$doc" "missing: a new session cannot resume or learn from past mistakes"; fi
done

echo "SUMMARY pass=$p warn=$w fail=$f"
[ "$f" -eq 0 ]
