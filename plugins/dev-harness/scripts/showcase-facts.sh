#!/usr/bin/env bash
# dev-harness showcase-facts: evidence for choosing what to show off in a project.
# Usage: showcase-facts.sh [project-dir]
# Prints one line per fact:  FACT  <name> — <value>   (a name can repeat, one line per item)
# then:                      SUMMARY facts=N
# Exit 1 only if the project dir does not exist. A missing source is a line that says so, never a guess.
# It reads files and git history only; it runs none of the project's commands and writes nothing.
# bash 3.2 compatible (macOS).

# -h / --help prints the comment block at the top of this file (the usage).
case "${1:-}" in -h|--help) sed -n '2,/^[^#]/{/^#/s/^# \{0,1\}//p;}' "$0"; exit 0 ;; esac

DEST="${1:-.}"
[ -d "$DEST" ] || { echo "FAIL    project dir not found: $DEST" >&2; exit 1; }
cd -- "$DEST" || exit 1
export LC_ALL=C

n=0
fact() { # name value
  local v="$2"
  # Cut at 200 bytes, then drop a UTF-8 character that the cut split (LC_ALL=C counts bytes).
  if [ "${#v}" -gt 200 ]; then v="$(printf '%.200s' "$v" | { iconv -c -f UTF-8 -t UTF-8 2>/dev/null || cat; })..."; fi
  printf 'FACT  %-11s — %s\n' "$1" "$v"; n=$((n+1))
}
clean() { tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/`//g' -e 's/\*\*//g'; }

# 1. History. Everything is limited to this folder (`-- .`, `--relative`), so a project inside a larger
# repository (a monorepo, a dotfiles repo) does not report its parent's history.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1 && git rev-parse --verify -q HEAD >/dev/null 2>&1; then
  total=$(git rev-list --count HEAD -- .)
  first=$(git log --reverse --format=%ad --date=short -- . | head -n1)
  last=$(git log -1 --format=%ad --date=short -- .)
  note=""
  [ -n "$(git rev-parse --show-prefix)" ] && note=" (this folder is inside a larger git repository: only commits that touch it are counted)"
  [ "$(git rev-parse --is-shallow-repository 2>/dev/null)" = true ] && note="$note (shallow clone: older history is missing)"
  if [ "$total" = 0 ]; then fact history "no commit touches this folder yet$note"
  else fact history "$total commit(s), first $first, last $last$note"; fi
  while IFS= read -r s; do fact recent "$s"; done < <(git log -5 --format=%s -- .)
  # Most-changed files that still exist. Docs and lockfiles are left out: they change often and show nothing.
  # core.quotePath=false keeps non-ASCII names readable; a name with a newline or a double quote is skipped.
  while IFS= read -r line; do
    c=${line%% *}; f=${line#* }
    [ -e "$f" ] && fact churn "$c commit(s) touched $f"
  done < <(git -c core.quotePath=false log --relative --name-only --format= -- . | grep -v '^$' | grep -Ev '^docs/|(^|/)(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|Cargo\.lock|poetry\.lock|go\.sum)$' \
           | sort | uniq -c | sort -k1,1nr -k2 | sed -E 's/^ *([0-9]+) /\1 /' | head -8)
else
  fact history "not a git repository, or no commits yet: no history to read"
fi

# 2. Tests. In a git repo the list comes from git (tracked and untracked, minus .gitignore), so a
# virtualenv or build folder that is ignored is not counted; elsewhere from find. Dependency and build
# folders are left out either way.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  files=$(git -c core.quotePath=false ls-files -co --exclude-standard 2>/dev/null)
else
  files=$(find . \( -name .git -o -name node_modules \) -prune -o -type f -print | sed 's|^\./||')
fi
tests=0
while IFS= read -r f; do
  [ -n "$f" ] && [ -e "$f" ] && tests=$((tests+1))
done < <(printf '%s\n' "$files" | grep -E '(^|/)(test_[^/]*\.py|[^/]*_test\.py|[^/]*\.(test|spec)\.(js|jsx|ts|tsx)|[^/]*_test\.go|[^/]*-test\.sh|test-[^/]*\.sh|[^/]*_test\.rb|[^/]*Test\.java)$' \
         | grep -Ev '(^|/)(node_modules|vendor|\.venv|venv|env|__pycache__|target|dist|build|\.tox)/')
if [ "$tests" = 0 ]; then fact tests "no test files found by the usual name patterns"
else fact tests "$tests test file(s) by name pattern (not run, not counted for cases)"; fi

# 3. README headings (Markdown only; headings inside code fences are skipped)
readme=""
for r in README.md readme.md README.rst README; do [ -f "$r" ] && { readme="$r"; break; }; done
if [ -z "$readme" ]; then
  fact readme "no README found"
else
  case "$readme" in
    *.md)
      mdheads=$(tr -d '\r' < "$readme" | awk '/^(```|~~~)/ {f=!f; next} !f && /^#+ / {print}')
      heads=$(grep -E '^#{1,3} ' <<<"$mdheads" | sed -E 's/^#+ +//' | head -12 | tr '\n' '|' | sed 's/|$//; s/|/ | /g')
      fact readme "$readme: ${heads:-no headings}"
      grep -Eqi '^#{2,3} +(demo|use|usage|quick ?start|examples?|getting started)([[:space:]]|$)' <<<"$mdheads" \
        && fact readme-demo "$readme has a demo, usage or quickstart heading" \
        || fact readme-demo "$readme has no demo, usage or quickstart heading" ;;
    *)
      fact readme "$readme exists but is not Markdown: its headings were not read"
      fact readme-demo "unknown: $readme is not Markdown, so it was not checked for a demo heading" ;;
  esac
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
    # best = the best baseline or kept value in the stated direction (the last one if the direction is unstated)
    case "$dir" in
      *igher*) best=$(awk -F'\t' '($3 == "baseline" || $3 == "kept") && (b == "" || $2 + 0 > b + 0) {b = $2} END {print b}' <<<"$rows") ;;
      *ower*)  best=$(awk -F'\t' '($3 == "baseline" || $3 == "kept") && (b == "" || $2 + 0 < b + 0) {b = $2} END {print b}' <<<"$rows") ;;
      *)       best=$(awk -F'\t' '$3 == "baseline" || $3 == "kept" {b = $2} END {print b}' <<<"$rows") ;;
    esac
    skipped=$(awk -F'|' '
      function trim(s) { gsub(/^[ \t`]+|[ \t`]+$/, "", s); return s }
      /^\|/ { st = tolower(trim($6)); v = trim($4)
        if ((st == "baseline" || st == "kept" || st == "reverted") && v !~ /^-?[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?$/) c++ } END {print c + 0}' docs/experiments.md)
    kept=$(awk -F'\t' '$3 == "kept"' <<<"$rows" | wc -l | tr -d ' ')
    rev=$(awk -F'\t' '$3 == "reverted"' <<<"$rows" | wc -l | tr -d ' ')
    case "$name" in ''|'<'*) name="(metric not named)" ;; esac
    if [ -z "$base" ]; then fact experiment "$name: no baseline row, so no gain can be claimed ($kept kept, $rev reverted)"
    else fact experiment "$name: baseline $base, best $best, $kept kept, $rev reverted; direction: ${dir:-unstated}$([ "$skipped" != 0 ] && echo "; $skipped row(s) skipped because the metric is not a plain number")"; fi
  fi
else
  fact experiment "no docs/experiments.md: no measured gains"
fi

# 7. Lessons (what went wrong and was fixed: honest material for talking points)
if [ -f docs/lessons.md ]; then
  l=$(tr -d '\r' < docs/lessons.md | awk '/^(```|~~~)/ {f=!f; next} !f && /^### / {c++} END {print c + 0}')
  fact lessons "$l lesson entr$([ "$l" = 1 ] && echo y || echo ies) in docs/lessons.md (the template's example counts as one)"
else
  fact lessons "no docs/lessons.md"
fi

echo "SUMMARY facts=$n"
