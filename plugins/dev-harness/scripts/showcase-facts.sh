#!/usr/bin/env bash
# dev-harness showcase-facts: evidence for choosing what to show off in a project.
# Usage: showcase-facts.sh [project-dir]
# Prints one line per fact:  FACT  <name> — <value>   (a name can repeat, one line per item)
# then:                      SUMMARY facts=N
# Exit 1 only if the project dir does not exist. A missing source is a line that says so, never a guess.
# It reads files and git history only; it runs none of the project's commands and writes nothing.
# bash 3.2 compatible (macOS).

DEST="${1:-.}"
[ -d "$DEST" ] || { echo "FAIL    project dir not found: $DEST" >&2; exit 1; }
cd "$DEST" || exit 1
export LC_ALL=C

n=0
fact() { # name value
  local v="$2"
  [ "${#v}" -gt 200 ] && v="$(printf '%.200s' "$v")..."
  printf 'FACT  %-11s — %s\n' "$1" "$v"; n=$((n+1))
}
clean() { tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/`//g' -e 's/\*\*//g'; }

# 1. History
if git rev-parse --is-inside-work-tree >/dev/null 2>&1 && git rev-parse --verify -q HEAD >/dev/null 2>&1; then
  total=$(git rev-list --count HEAD)
  first=$(git log --reverse --format=%ad --date=short | head -n1)
  last=$(git log -1 --format=%ad --date=short)
  fact history "$total commit(s), first $first, last $last"
  while IFS= read -r s; do fact recent "$s"; done < <(git log -5 --format=%s)
  # Most-changed files that still exist. Docs and lockfiles are left out: they change often and show nothing.
  while IFS= read -r line; do
    c=${line%% *}; f=${line#* }
    [ -e "$f" ] && fact churn "$c commit(s) touched $f"
  done < <(git log --name-only --format= | grep -v '^$' | grep -Ev '^docs/|(^|/)(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|Cargo\.lock|poetry\.lock|go\.sum)$' \
           | sort | uniq -c | sort -k1,1nr -k2 | sed -E 's/^ *([0-9]+) /\1 /' | head -8)
else
  fact history "not a git repository, or no commits yet: no history to read"
fi

# 2. Tests
tests=$(find . \( -name .git -o -name node_modules -o -name vendor -o -name .venv -o -name __pycache__ \) -prune -o -type f \
  \( -name 'test_*.py' -o -name '*_test.py' -o -name '*.test.js' -o -name '*.test.jsx' -o -name '*.test.ts' -o -name '*.test.tsx' \
     -o -name '*.spec.js' -o -name '*.spec.ts' -o -name '*_test.go' -o -name '*-test.sh' -o -name 'test-*.sh' -o -name '*_test.rb' -o -name '*Test.java' \) -print | wc -l | tr -d ' ')
if [ "$tests" = 0 ]; then fact tests "no test files found by the usual name patterns"
else fact tests "$tests test file(s) by name pattern (not run, not counted for cases)"; fi

# 3. README headings
readme=""
for r in README.md readme.md README.rst README; do [ -f "$r" ] && { readme="$r"; break; }; done
if [ -n "$readme" ]; then
  heads=$(grep -E '^#{1,3} ' "$readme" | sed -E 's/^#+ +//' | head -12 | tr '\n' '|' | sed 's/|$//; s/|/ | /g')
  fact readme "$readme: ${heads:-no headings}"
  grep -Eqi '^#{2,3} +(demo|use|usage|quick ?start|examples?|getting started)([[:space:]]|$)' "$readme" \
    && fact readme-demo "$readme has a demo, usage or quickstart heading" \
    || fact readme-demo "$readme has no demo, usage or quickstart heading"
else
  fact readme "no README found"
fi

# 4. Commands an agent or visitor would run (from the CLAUDE.md Commands section; unfilled placeholders skipped)
if [ -f CLAUDE.md ]; then
  cmds=$(tr -d '\r' < CLAUDE.md | awk '/^## Commands/ {on=1; next} /^## / {on=0} on && /^- / {print}' | grep -v '<cmd>' | clean)
  if [ -n "$cmds" ]; then while IFS= read -r l; do fact command "$l"; done <<<"$cmds"
  else fact command "CLAUDE.md lists no filled-in commands"; fi
else
  fact command "no CLAUDE.md"
fi

# 5. Intent: who receives the work and what to push hardest on
if [ -f docs/intent.md ]; then
  st=$(tr -d '\r' < docs/intent.md | awk 'NR==1 && $0!="---" {exit} NR>1 && /^---[[:space:]]*$/ {exit} /^status[[:space:]]*:/ {sub(/^status[[:space:]]*:[[:space:]]*/,""); gsub(/["'"'"']/,""); print tolower($0); exit}')
  fact intent "docs/intent.md status: ${st:-unset}$([ "$st" = decided ] || echo ' (not decided: treat what follows as a draft)')"
  field() { # label -> value of "- **label:** value", empty if absent or still a <placeholder>
    local v
    v=$(tr -d '\r' < docs/intent.md | grep -m1 -i "^- *\*\*$1:\*\*" | sed -E 's/^[^:]*:\*\* *//' | clean)
    case "$v" in ''|'<'*) return 0 ;; esac
    printf '%s\n' "$v"
  }
  for lab in "Receiver" "What the receiver cares about" "Deliverable" "Direction"; do
    v=$(field "$lab"); [ -n "$v" ] && fact "intent-$(echo "$lab" | tr 'A-Z ' 'a-z-' | cut -c1-9)" "$lab: $v"
  done
  push=$(tr -d '\r' < docs/intent.md | awk '/^## Push hardest on/ {on=1; next} /^## / {on=0} on && /^[0-9]+\. / {sub(/^[0-9]+\. */,""); print}' | clean | grep -v '^<' | head -3)
  if [ -n "$push" ]; then while IFS= read -r l; do fact push-on "$l"; done <<<"$push"; fi
else
  fact intent "no docs/intent.md: who this is for is unknown (run /dev-harness:discover)"
fi

# 6. Measured gains from the explore loop: the strongest evidence a project has
if [ -f docs/experiments.md ]; then
  rows=$(awk -F'|' '
    function trim(s) { gsub(/^[ \t`]+|[ \t`]+$/, "", s); return s }
    /^\|/ { st = tolower(trim($6)); v = trim($4)
      if ((st == "baseline" || st == "kept" || st == "reverted") && v ~ /^-?[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?$/) printf "%s\t%s\t%s\n", trim($3), v, st }' docs/experiments.md)
  if [ -z "$rows" ]; then fact experiment "docs/experiments.md has no measured rows"
  else
    name=$(tr -d '\r' < docs/experiments.md | grep -m1 -i '^- *Name *:' | sed -E 's/^[^:]*: *//' | clean)
    dir=$(tr -d '\r' < docs/experiments.md | grep -m1 -i '^- *Direction *:' | sed -E 's/^[^:]*: *//' | clean)
    base=$(awk -F'\t' '$3 == "baseline" {print $2; exit}' <<<"$rows")
    best=$(awk -F'\t' '$3 == "baseline" || $3 == "kept" {b = $2} END {print b}' <<<"$rows")
    kept=$(awk -F'\t' '$3 == "kept"' <<<"$rows" | wc -l | tr -d ' ')
    rev=$(awk -F'\t' '$3 == "reverted"' <<<"$rows" | wc -l | tr -d ' ')
    case "$name" in ''|'<'*) name="(metric not named)" ;; esac
    if [ -z "$base" ]; then fact experiment "$name: no baseline row, so no gain can be claimed ($kept kept, $rev reverted)"
    else fact experiment "$name: baseline $base, best $best, $kept kept, $rev reverted; direction: ${dir:-unstated}"; fi
  fi
else
  fact experiment "no docs/experiments.md: no measured gains"
fi

# 7. Lessons (what went wrong and was fixed: honest material for talking points)
if [ -f docs/lessons.md ]; then
  l=$(grep -c '^### ' docs/lessons.md)
  fact lessons "$l lesson entr$([ "$l" = 1 ] && echo y || echo ies) in docs/lessons.md (the template's example counts as one)"
else
  fact lessons "no docs/lessons.md"
fi

echo "SUMMARY facts=$n"
