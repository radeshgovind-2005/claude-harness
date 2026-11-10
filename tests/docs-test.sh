#!/usr/bin/env bash
# Tests the documentation, examples, line endings and icon of the repository.
# Run from anywhere:  /bin/bash tests/docs-test.sh
# shellcheck disable=SC2319  # `[ test ]; check name $?` reads the test's status on purpose

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
P=plugins/dev-harness
pass=0; fail=0
check() { if [ "$2" = 0 ]; then echo "  PASS  $1"; pass=$((pass+1)); else echo "  FAIL  $1"; fail=$((fail+1)); fi; }
command -v jq >/dev/null || { echo "Error: jq is required."; exit 1; }
VER=$(jq -r .version "$P/.claude-plugin/plugin.json")

# Markdown files whose relative links must resolve. docs/progress.md and docs/brief.md are history: left out.
DOCS="README.md docs/getting-started.md docs/reference.md docs/how-it-works.md docs/stability.md docs/contributing.md CLAUDE.md"
EXAMPLES=$(find examples -name '*.md' 2>/dev/null | sort)

echo "Links"
for f in $DOCS $EXAMPLES; do
  [ -f "$f" ] || { check "$f exists" 1; continue; }
  bad=""
  # [text](target): skip absolute URLs, mailto and pure #anchors; strip a #anchor from the target.
  while IFS= read -r t; do
    case "$t" in http://*|https://*|mailto:*|\#*|'') continue ;; esac
    t="${t%%#*}"; [ -n "$t" ] || continue
    [ -e "$(dirname "$f")/$t" ] || bad="$bad $t"
  done < <(grep -o ']([^)]*)' "$f" | sed -e 's/^](//' -e 's/)$//')
  [ -z "$bad" ]; check "$f: every relative link resolves${bad:+ (broken:$bad)}" $?
done

echo "Versions and counts"
ns=$(find "$P/skills" -mindepth 2 -maxdepth 2 -name SKILL.md | wc -l | tr -d ' ')
na=$(find "$P/agents" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')
rv=$(grep -Eo 'Status: v[0-9]+\.[0-9]+\.[0-9]+' README.md | head -n1 | sed 's/Status: v//')
[ "$rv" = "$VER" ]; check "README status version ($rv) equals plugin.json ($VER)" $?
word() { case "$1" in 1) echo one ;; 2) echo two ;; 3) echo three ;; 4) echo four ;; 5) echo five ;; 6) echo six ;; 7) echo seven ;; 8) echo eight ;; 9) echo nine ;; 10) echo ten ;; 11) echo eleven ;; 12) echo twelve ;; *) echo "$1" ;; esac; }
sw=$(word "$ns"); aw=$(word "$na")
grep -Eqi "\b$sw skills and $aw agents\b" README.md; check "README says '$sw skills and $aw agents' ($ns skills, $na agents on disk)" $?
top=$(grep -Eom1 '^## [0-9]+\.[0-9]+\.[0-9]+' CHANGELOG.md | cut -c4-)
[ "$top" = "$VER" ]; check "CHANGELOG top entry ($top) equals plugin.json ($VER)" $?

echo "Every skill and agent is documented"
miss=""
for d in "$P"/skills/*/; do s=$(basename "$d"); grep -q "^### $s\$" docs/reference.md || miss="$miss $s"; done
for f in "$P"/agents/*.md; do a=$(basename "$f" .md); grep -q "^| \`$a\` " docs/reference.md || miss="$miss $a"; done
[ -z "$miss" ]; check "docs/reference.md has a section for every skill and a row for every agent${miss:+ (missing:$miss)}" $?
miss=""
srow=$(grep '^| Skill names and arguments' docs/stability.md); arow=$(grep '^| Agent names' docs/stability.md)
for d in "$P"/skills/*/; do s=$(basename "$d"); grep -q "\`$s\`" <<<"$srow" || miss="$miss $s"; done
for f in "$P"/agents/*.md; do a=$(basename "$f" .md); grep -q "\`$a\`" <<<"$arow" || miss="$miss $a"; done
[ -z "$miss" ]; check "docs/stability.md lists every skill (in its skill row) and every agent (in its agent row)${miss:+ (missing:$miss)}" $?
miss=""
for f in "$P"/agents/*.md; do a=$(basename "$f" .md); grep -q "\`$a\`" README.md || miss="$miss $a"; done
for d in "$P"/skills/*/; do s=$(basename "$d"); grep -q "\`$s\`\|\`$s <" README.md || miss="$miss $s"; done
[ -z "$miss" ]; check "README names every skill and agent${miss:+ (missing:$miss)}" $?

echo "No stale status text"
! grep -Eq '\| *planned' "$P/skills/help/SKILL.md"; check "help has no 'planned' row" $?
stale=$(grep -nEi 'arrives in v[0-9]|planned v[0-9]|coming in v[0-9]|not yet implemented' README.md docs/getting-started.md docs/reference.md docs/how-it-works.md docs/stability.md docs/contributing.md "$P"/skills/*/SKILL.md "$P"/agents/*.md 2>/dev/null)
[ -z "$stale" ]; st=$?; first=$(head -n1 <<<"$stale"); check "no 'arrives in vX', 'planned vX' or 'coming in vX' text in the docs, skills or agents${stale:+ ($first)}" $st

echo "Fork guide"
# Every file that names the owner or the author (outside history) must be one the fork guide tells you to change.
# Files are matched by their full path; the pages in docs/ are covered by one mention of docs/.
miss=""
while IFS= read -r f; do
  case "$f" in CHANGELOG.md|docs/brief.md|docs/progress.md|docs/contributing.md|examples/*|tests/docs-test.sh) continue ;; esac
  case "$f" in
    docs/*) grep -q 'docs/' docs/contributing.md || miss="$miss $f" ;;
    *) grep -qF "$f" docs/contributing.md || miss="$miss $f" ;;
  esac
done < <(git grep -l -e 'radeshgovind-2005' -e 'Radesh Govind' 2>/dev/null)
[ -z "$miss" ]; check "docs/contributing.md names (by path) every file that contains the owner or author name${miss:+ (not named:$miss)}" $?

echo "Dogfood: the repository's own CLAUDE.md"
[ "$(wc -l < CLAUDE.md | tr -d ' ')" -lt 100 ]; check "CLAUDE.md is under 100 lines" $?
out=$(bash "$P/scripts/ax-check.sh" . 2>&1); rc=$?
[ $rc -eq 0 ]; st=$?; nfail=$(grep -c '^FAIL' <<<"$out"); check "ax-check.sh finds no FAIL in this repository ($nfail FAIL)" $st
grep -q '^PASS .*routed paths exist' <<<"$out"; check "every path CLAUDE.md routes to exists" $?

echo "Examples"
if [ -z "$EXAMPLES" ]; then check "examples/ has files" 1; else
  for f in $EXAMPLES; do
    [ "$(basename "$f")" = README.md ] && continue
    head -n 14 "$f" | grep -Eq '^- Plugin version: [0-9]+\.[0-9]+\.[0-9]+$' \
      && head -n 14 "$f" | grep -q '^- Date: [0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}$' \
      && head -n 14 "$f" | grep -q '^- Command: ' \
      && head -n 14 "$f" | grep -q '^- How it was run: '; check "$f has its header (plugin version, date, command, how it was run)" $?
  done
  miss=""
  for f in $EXAMPLES; do b=$(basename "$f"); [ "$b" = README.md ] && continue; grep -q "($b)" examples/README.md || miss="$miss $b"; done
  [ -z "$miss" ]; check "examples/README.md links every example${miss:+ (missing:$miss)}" $?
fi

echo "Progress notes and scripts"
grep -q "^## Checkpoint v$VER\b" docs/progress.md; check "docs/progress.md has a checkpoint for v$VER (a new session can resume from it)" $?
first=$(grep -m1 '^## Checkpoint v' docs/progress.md | sed -E 's/^## Checkpoint v([0-9.]+).*/\1/')
[ "$first" = "$VER" ]; check "the newest checkpoint in docs/progress.md ($first) is the current version ($VER)" $?
for sc in scaffold explore goal ax-check showcase-facts; do
  out=$(bash "$P/scripts/$sc.sh" --help 2>&1); rc=$?
  [ $rc -eq 0 ] && grep -q '^Usage' <<<"$out"; check "$sc.sh --help prints a Usage line and exits 0" $?
done

echo "Line endings"
cr=$(git ls-files '*.sh' '*.json' '*.yml' '*.md' 2>/dev/null | while IFS= read -r f; do [ -f "$f" ] && grep -q $'\r' "$f" && echo "$f"; done)
[ -z "$cr" ]; st=$?; first=$(head -n1 <<<"$cr"); check "no carriage return in any tracked .sh, .json, .yml or .md file${cr:+ ($first)}" $st
[ -f .gitattributes ] && grep -q '^\*\.sh text eol=lf$' .gitattributes; check ".gitattributes forces LF for *.sh" $?
eol=$(git ls-files --eol '*.sh' 2>/dev/null | grep -v 'attr/text eol=lf' | head -n1)
[ -z "$eol" ]; check "every tracked .sh has the text eol=lf attribute${eol:+ ($eol)}" $?

echo "Icon"
ic="$P/.claude-plugin/icon.png"
if [ -f "$ic" ]; then
  sig=$(od -An -tx1 -N8 "$ic" | tr -d ' \n')
  [ "$sig" = 89504e470d0a1a0a ]; check "icon.png is a PNG" $?
  w=$(od -An -tu1 -j16 -N4 "$ic" | head -n1 | awk '{print $1*16777216+$2*65536+$3*256+$4}')
  h=$(od -An -tu1 -j20 -N4 "$ic" | head -n1 | awk '{print $1*16777216+$2*65536+$3*256+$4}')
  [ "$w" = "$h" ] && [ "$w" -ge 512 ] && [ "$w" -le 2048 ]; check "icon.png is square and 512 to 2048 px (${w}x${h})" $?
  [ "$(wc -c < "$ic" | tr -d ' ')" -lt 2097152 ]; check "icon.png is under 2 MB" $?
else
  check "icon.png exists" 1
fi

echo
echo "Result: $pass passed, $fail failed"
[ $fail -eq 0 ]
