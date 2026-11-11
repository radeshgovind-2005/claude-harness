#!/usr/bin/env bash
# Tests scripts/tasks.sh: card checks, scope overlap (glob intersection and dependencies), the index,
# the active card, and worktrees.
# Run from anywhere:  /bin/bash tests/tasks-test.sh
# shellcheck disable=SC2319  # `[ test ]; check name $?` reads the test's status on purpose

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
P="$ROOT/plugins/dev-harness"
TS="$P/scripts/tasks.sh"
TPL="$P/templates/project/docs/tasks"
pass=0; fail=0
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

check() { if [ "$2" = 0 ]; then echo "  PASS  $1"; pass=$((pass+1)); else echo "  FAIL  $1"; fail=$((fail+1)); fi; }
# proj: a fresh project with docs/tasks from the template (a git repo with one commit), in $D.
proj() {
  D=$(mktemp -d "$W/p.XXXX"); git -C "$D" init -q -b main; mkdir -p "$D/docs/tasks"; cp "$TPL"/*.md "$D/docs/tasks/"
  printf '.claude/active-task\n' > "$D/.gitignore"; git -C "$D" add -A; git -C "$D" commit -q -m init
}
t() { TASKS_ROOT="$D" bash "$TS" "$@"; }
card() { # title scope [depends]
  t new "$1" --scope "$2" ${3:+--depends "$3"} --goal "g" --done-when "true" --read-first "a, b, c" --next "n" >/dev/null 2>&1; }
# meets A B: 0 if two cards with scopes A and B (no dependency) overlap.
meets() { proj; card one "$1"; card two "$2"; t overlap 2>&1 | grep -q '^FAIL  overlap'; }
setfm() { # file key value
  awk -v k="$2" -v v="$3" 'NR==1 {print; next} !e && /^---/ {e=1} !e && index($0, k ":") == 1 {print k ": " v; next} {print}' "$1" > "$1.tmp" && mv "$1.tmp" "$1"; }

echo "Glob intersection (both orders)"
for pair in 'src/**|src/a/b.ts' 'src/**|src' '**/test_*.py|tests/test_a.py' 'src/*.ts|src/a?.ts' 'src/a?.ts|src/ab.ts' 'src/*|src/*.md' \
            'src/api|src/api/client.ts' 'src/{a,b}/x.ts|src/c/x.ts' 'src/[ab]/x|src/z/x' 'docs/tasks/|docs/tasks/001-a.md' \
            './src/a.ts|src/a.ts' 'src/v1.0/|src/v1.0/a.ts' 'a/**/z.ts|a/b/c/z.ts' '**|anything/at/all'; do
  a=${pair%%|*}; b=${pair##*|}
  meets "$a" "$b"; check "'$a' meets '$b'" $?
  meets "$b" "$a"; check "'$b' meets '$a'" $?
done
for pair in 'src/*.ts|src/*.md' 'src/api/**|src/ui/**' 'src/a.ts|src/b.ts' 'src/*/x.ts|src/x.ts' 'a/**/z.ts|a/b/y.ts' \
            'tests/*.py|tests/unit/a.py' 'src/a?.ts|src/abc.ts' 'docs/x.md|docs/x.mdx'; do
  a=${pair%%|*}; b=${pair##*|}
  ! meets "$a" "$b"; check "'$a' and '$b' are disjoint" $?
  ! meets "$b" "$a"; check "'$b' and '$a' are disjoint" $?
done

echo "Dependencies"
proj; card api 'src/api/**'; card form 'src/api/client.ts' 001
t overlap >/dev/null 2>&1; check "overlap with a dependency passes" $?
proj; card a 'src/**'; card b 'lib/**' 001; card c 'src/x.ts' 002
t overlap >/dev/null 2>&1; check "a transitive dependency (003 -> 002 -> 001) passes" $?
proj; card a 'src/**'; card b 'src/x.ts'; card c 'lib/**'
out=$(t overlap 2>&1); [ $? -ne 0 ] && grep -q '001-a and 002-b overlap' <<<"$out" && ! grep -q '003' <<<"$out"; check "only the overlapping pair is named" $?
setfm "$D/docs/tasks/002-b.md" status "done"
t overlap >/dev/null 2>&1; check "a done card is ignored" $?
setfm "$D/docs/tasks/002-b.md" status blocked
! t overlap >/dev/null 2>&1; check "a blocked card still counts" $?
proj; card a 'src/**'; card b 'lib/**'
setfm "$D/docs/tasks/001-a.md" depends 002-b; setfm "$D/docs/tasks/002-b.md" depends 001-a
out=$(t check 2>&1); [ $? -ne 0 ] && grep -q 'cycle' <<<"$out"; check "a dependency cycle fails check" $?
proj; card a 'src/**'; setfm "$D/docs/tasks/001-a.md" depends 009-ghost
out=$(t check 2>&1); [ $? -ne 0 ] && grep -q '009-ghost, which is not a card' <<<"$out"; check "an unknown dependency fails check" $?
proj; card a 'src/**'
! card b 'lib/**' 042; check "new refuses an unknown --depends" $?
card b 'lib/**' 1 2>/dev/null; [ ! -e "$D/docs/tasks/002-b.md" ]; check "a number that matches no card (1) is refused" $?
card b 'lib/**' 001; grep -qx 'depends: 001-a' "$D/docs/tasks/002-b.md"; check "--depends 001 is written as the full id" $?

echo "Cards and the index"
proj; card "First thing" 'a/**'; card "Second: thing" 'b/**'
[ -f "$D/docs/tasks/001-first-thing.md" ] && [ -f "$D/docs/tasks/002-second-thing.md" ]; check "new numbers cards 001, 002 with a slug" $?
grep -qx 'depends:' "$D/docs/tasks/001-first-thing.md"; check "an empty depends has no trailing space" $?
t check >/dev/null 2>&1; check "two complete cards with disjoint scopes pass check" $?
grep -q '^| 002-second-thing | Second: thing | open | unassigned |  |$' "$D/docs/tasks/INDEX.md"; check "INDEX has a row per card" $?
grep -q 'State lives in files' "$D/docs/tasks/INDEX.md"; check "index keeps the text outside the markers" $?
setfm "$D/docs/tasks/001-first-thing.md" status in-progress
out=$(t check 2>&1); [ $? -ne 0 ] && grep -q 'tasks.sh index' <<<"$out"; check "INDEX drift fails check" $?
t index >/dev/null; t check >/dev/null 2>&1; check "after index, check passes again" $?
setfm "$D/docs/tasks/001-first-thing.md" status doing; t index >/dev/null
out=$(t check 2>&1); [ $? -ne 0 ] && grep -q 'status(open' <<<"$out"; check "an invalid status fails check" $?
setfm "$D/docs/tasks/001-first-thing.md" status open
setfm "$D/docs/tasks/001-first-thing.md" scope '<glob>, <glob>'; t index >/dev/null
out=$(t check 2>&1); [ $? -ne 0 ] && grep -q 'card 001-first-thing.*scope' <<<"$out"; check "a placeholder scope fails check" $?
proj; t new "x" --scope 'a/**' >/dev/null 2>&1
out=$(t check 2>&1); [ $? -ne 0 ] && grep -q 'section:Goal' <<<"$out" && grep -q 'section:Done when' <<<"$out"; check "an empty Goal or Done when fails check" $?
proj; card a 'a/**'; printf '\nList<String> is fine in a goal\n' >> "$D/docs/tasks/001-a.md"
t check >/dev/null 2>&1; check "angle brackets inside text are not a placeholder" $?
proj; ! t new "no scope" --goal g >/dev/null 2>&1; check "new without --scope fails" $?
cp "$TPL/INDEX.md" "$D/docs/tasks/INDEX.md"; printf '# x\n' > "$D/docs/tasks/INDEX.md"
! t index >/dev/null 2>&1; check "index refuses an INDEX.md without markers" $?

echo "Active card"
proj; card a 'a/**'; card b 'b/**'
[ "$(t active)" = none ]; check "no active card: 'none'" $?
t active 002 >/dev/null 2>&1; [ "$(cat "$D/.claude/active-task")" = 002-b ]; check "active 002 writes the full id to .claude/active-task" $?
[ "$(t active)" = "002-b docs/tasks/002-b.md" ]; check "active shows it" $?
t active 2>&1 >/dev/null | grep -q WARN; [ $? -ne 0 ]; check "a gitignored active file gives no warning" $?
! t active 9 >/dev/null 2>&1; check "an unknown id is refused" $?
t active --clear >/dev/null; [ ! -e "$D/.claude/active-task" ]; check "--clear removes it" $?
printf '../../etc/passwd\n' > "$D/.claude/active-task"; ! t active >/dev/null 2>&1; check "a bad id in the active file is reported, not followed" $?
printf '' > "$D/.gitignore"; out=$(t active 001 2>&1); grep -q 'not gitignored' <<<"$out"; check "a non-ignored active file is warned about" $?

echo "Worktrees"
proj; card api 'src/api/**'; card ui 'src/ui/**'; card both 'src/**'
git -C "$D" add -A; git -C "$D" commit -q -m cards
out=$(t worktree 002 2>&1); [ $? -ne 0 ] && grep -q '002-ui and 003-both overlap' <<<"$out"; check "worktree refuses a card that overlaps another" $?
setfm "$D/docs/tasks/003-both.md" depends "001-api, 002-ui"; t index >/dev/null; git -C "$D" commit -qam deps
out=$(t worktree 002 2>&1); st=$?
WT="$(dirname "$D")/$(basename "$D")-002-ui"
[ $st = 0 ] && [ -d "$WT" ] && [ "$(git -C "$WT" symbolic-ref --short HEAD)" = task/002-ui ]; check "worktree creates ../<repo>-<id> on branch task/<id>" $?
grep -qx 'status: in-progress' "$WT/docs/tasks/002-ui.md" && grep -qx 'owner: task/002-ui' "$WT/docs/tasks/002-ui.md"; check "the card is in-progress and owned by the branch there" $?
grep -qx 'status: open' "$D/docs/tasks/002-ui.md"; check "the main checkout's card is unchanged" $?
[ "$(cat "$WT/.claude/active-task")" = 002-ui ] && [ ! -e "$D/.claude/active-task" ]; check "the card is active in the new worktree only" $?
TASKS_ROOT="$WT" bash "$TS" check >/dev/null 2>&1; check "check passes in the new worktree (index updated)" $?
! t worktree 002 >/dev/null 2>&1; check "a second worktree for the same card is refused" $?
out=$(t worktree 003 2>&1); [ $? -ne 0 ] && grep -q 'depends on 001-api, which is not done' <<<"$out"; check "a card whose dependency is not done is refused" $?
card late 'docs/**'
out=$(t worktree 004 2>&1); [ $? -ne 0 ] && grep -q 'not committed' <<<"$out"; check "an uncommitted card is refused" $?
git -C "$D" add -A; git -C "$D" commit -qm late; printf 'x\n' >> "$D/docs/tasks/004-late.md"
out=$(t worktree 004 2>&1); [ $? -ne 0 ] && grep -q 'uncommitted changes' <<<"$out"; check "a card with uncommitted changes is refused" $?
git -C "$D" worktree remove --force "$WT" >/dev/null 2>&1

echo "Usage"
bash "$TS" --help | grep -q 'tasks.sh worktree <id>'; check "--help prints the usage" $?
! bash "$TS" bogus >/dev/null 2>&1; check "an unknown command fails" $?
E=$(mktemp -d "$W/e.XXXX"); ! TASKS_ROOT="$E" bash "$TS" check >/dev/null 2>&1; check "no docs/tasks/ fails" $?

echo
echo "Result: $pass passed, $fail failed"
[ $fail -eq 0 ]
