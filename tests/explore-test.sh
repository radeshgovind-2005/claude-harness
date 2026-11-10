#!/usr/bin/env bash
# Tests scripts/explore.sh (the experiment loop's referee) against throwaway git repos.
# Run from anywhere:  /bin/bash tests/explore-test.sh
# shellcheck disable=SC2319  # `[ test ]; check name $?` reads the test's status on purpose

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EX="$ROOT/plugins/dev-harness/scripts/explore.sh"
pass=0; fail=0
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT

check() { if [ "$2" = 0 ]; then echo "  PASS  $1"; pass=$((pass+1)); else echo "  FAIL  $1"; fail=$((fail+1)); fi; }
g() { git -C "$D" -c user.email=t@t -c user.name=t "$@"; }
ex() { (cd "$D" && bash "$EX" "$@" 2>&1); }          # run explore.sh in the project; stdout+stderr
exs() { (cd "$D" && bash "$EX" "$@" >/dev/null 2>&1); echo $?; }  # exit code only

# newproj [direction] [target] [metric-cmd]: a repo with value.txt=10, started on explore/test, Metric filled in.
newproj() {
  D=$(mktemp -d "$W/p.XXXX"); git -C "$D" init -q -b main
  echo 10 > "$D/value.txt"; echo "ignored.log" > "$D/.gitignore"
  g add -A; g commit -q -m init
  ex start test >/dev/null
  local dir="${1:-higher}" tgt="${2:-none}" cmd="${3:-cat value.txt}"
  setline "Measured by" "\`$cmd\`"; setline Direction "$dir is better"; setline Target "$tgt"
}
val() { echo "$1" > "$D/value.txt"; }
rowcount() { awk -F'|' -v s="$1" '{ c = $6; gsub(/ /, "", c) } c == s' "$D/docs/experiments.md" | wc -l | tr -d ' '; }   # rows whose state column is $1
# setline LABEL TEXT: replace the "- LABEL:" line of the Metric section (TEXT may hold | and \n; passed via ENVIRON)
setline() { T="$2" awk -v l="$1" 'BEGIN { t = ENVIRON["T"] } $0 ~ "^- " l ":" { print "- " l ": " t; next } { print }' "$D/docs/experiments.md" > "$D/.exp.tmp" && mv "$D/.exp.tmp" "$D/docs/experiments.md"; }

echo "start"
D=$(mktemp -d "$W/p.XXXX"); git -C "$D" init -q -b main; echo 10 > "$D/value.txt"; g add -A; g commit -q -m init
out=$(ex start cut-latency)
[ "$(git -C "$D" branch --show-current)" = "explore/cut-latency" ]; check "start on main creates explore/<slug>" $?
[ -f "$D/docs/experiments.md" ]; check "start creates docs/experiments.md from the template" $?
grep -q 'never commits to main' <<<"$out"; check "start says it left main" $?
out=$(ex start cut-latency); [ "$(git -C "$D" branch --show-current)" = "explore/cut-latency" ] && grep -q 'skip .*experiments.md' <<<"$out"; check "start again: stays on the branch, skips the file" $?
D=$(mktemp -d "$W/p.XXXX"); git -C "$D" init -q -b main; echo 10 > "$D/value.txt"; g add -A; g commit -q -m init; echo 11 > "$D/value.txt"
[ "$(exs start x)" != 0 ]; check "start refuses a dirty tree" $?
[ "$(git -C "$D" branch --show-current)" = main ]; check "a refused start does not switch branch" $?
D=$(mktemp -d "$W/p.XXXX"); git -C "$D" init -q -b main
[ "$(exs start x)" != 0 ]; check "start refuses a repo with no commits" $?
D=$(mktemp -d "$W/p.XXXX"); git -C "$D" init -q -b main; echo 1 > "$D/f"; g add -A; g commit -q -m i
[ "$(exs start 'Bad Slug')" != 0 ]; check "start refuses a non-kebab slug" $?
D=$(mktemp -d "$W/nogit.XXXX"); [ "$(exs start x)" != 0 ]; check "outside a git repo: fails" $?

echo "measure"
newproj
[ "$(ex measure)" = "VALUE=10" ]; check "measure reads the metric command" $?
newproj higher none 'echo "latency: 3.5 ms"'
[ "$(ex measure)" = "VALUE=3.5" ]; check "measure takes the last number on the line" $?
newproj higher none 'printf "12\nsummary 7\n\n"'
[ "$(ex measure)" = "VALUE=7" ]; check "measure takes the last non-empty line" $?
newproj higher none 'n=$(cat count 2>/dev/null || echo 0); n=$((n+1)); echo $n > count; case $n in 1) echo 9;; 2) echo 1;; *) echo 5;; esac'
out=$(ex measure --runs 3); grep -q '^VALUE=5$' <<<"$out"; check "measure --runs 3 reports the median (5 of 9,1,5)" $?
newproj higher none 'echo no digits here'
out=$(ex measure); [ "$(exs measure)" != 0 ] && grep -q 'printed no number' <<<"$out"; check "a metric with no number fails loudly" $?
newproj higher none 'echo 5; exit 3'
out=$(ex measure); [ "$(exs measure)" != 0 ] && grep -q 'exit 3' <<<"$out"; check "a failing metric command fails loudly" $?
newproj; setline Direction "<higher or lower> is better"
out=$(ex measure); [ "$(exs measure)" != 0 ] && grep -q 'Direction' <<<"$out"; check "an unset Direction placeholder is refused" $?
newproj; setline "Measured by" '`<command>`'
[ "$(exs measure)" != 0 ]; check "an unset Measured by placeholder is refused" $?
newproj; [ "$(exs measure --runs 0)" != 0 ] && [ "$(exs measure --runs x)" != 0 ]; check "--runs must be a positive integer" $?
newproj higher none 'sleep 5; echo 1'
start=$(date +%s); out=$(EXPLORE_TIMEOUT=1 ex measure); el=$(( $(date +%s) - start ))
grep -q 'timed out' <<<"$out" && [ "$el" -lt 5 ]; check "a hung metric is killed by the watchdog (${el}s)" $?
newproj higher none "(sleep 3; touch $W/orphan-marker) & echo 1; sleep 10"
EXPLORE_TIMEOUT=1 ex measure >/dev/null; sleep 4
[ ! -e "$W/orphan-marker" ]; check "the watchdog kills the whole process group" $?

echo "baseline / keep"
newproj
out=$(ex baseline); grep -q 'baseline row: 10' <<<"$out"; check "baseline records the measured value" $?
[ "$(rowcount baseline)" = 1 ]; check "baseline row is in the log" $?
[ "$(exs baseline)" != 0 ]; check "a second baseline is refused" $?
newproj; [ "$(exs keep v 12)" != 0 ]; check "keep before a baseline is refused" $?
newproj; ex baseline >/dev/null; val 12
out=$(ex keep "raise to 12" 12 "first try"); st=$?
grep -q 'kept .*10 -> 12' <<<"$out"; check "keep reports best -> value" $?
[ "$(g log -1 --format=%s)" = "explore: raise to 12 (10 -> 12)" ]; check "keep commits the variant" $?
[ -z "$(g status --porcelain)" ]; check "keep leaves a clean tree (log row committed with the variant)" $?
[ "$(rowcount kept)" = 1 ]; check "keep logs a kept row" $?
val 12; echo extra > "$D/x.txt"
[ "$(exs keep "same" 12)" != 0 ]; check "keep refuses a value equal to the best" $?
[ "$(exs keep "worse" 9)" != 0 ]; check "keep refuses a regression (higher is better)" $?
[ "$(rowcount kept)" = 1 ]; check "a refused keep logs nothing" $?
out=$(ex keep v abc); [ "$(exs keep v abc)" != 0 ] && grep -q 'as a number' <<<"$out"; check "keep refuses a non-numeric value, and says why" $?
newproj; ex baseline >/dev/null
[ "$(exs keep "nothing changed" 99)" != 0 ]; check "keep refuses when the tree equals HEAD" $?
newproj higher none 'cat value.txt'; ex baseline >/dev/null; val 12; g switch -q main 2>/dev/null
[ "$(exs keep v 12)" != 0 ]; check "keep refuses on main" $?
[ "$(exs revert v 9)" != 0 ]; check "revert refuses on main" $?
[ "$(cat "$D/value.txt")" = 12 ]; check "a refused revert on main leaves the files alone" $?

echo "lower is better"
newproj lower none; ex baseline >/dev/null; val 7
out=$(ex keep "faster" 7); [ $? -eq 0 ] && grep -q 'kept .*10 -> 7' <<<"$out"; check "keep accepts a lower value" $?
val 8; [ "$(exs keep "slower" 8)" != 0 ]; check "keep refuses a higher value" $?
out=$(ex status); grep -q '^BEST=7$' <<<"$out" && grep -q '^DIRECTION=lower$' <<<"$out"; check "status: BEST is the lowest kept value" $?

echo "revert"
newproj; ex baseline >/dev/null
val 9; echo new > "$D/new.txt"; echo staged > "$D/staged.txt"; g add staged.txt; echo log > "$D/ignored.log"; mkdir -p "$D/sub/deep"; echo d > "$D/sub/deep/f.txt"
out=$(ex revert "bad idea" 9 "slower"); st=$?
[ $st -eq 0 ] && [ "$(cat "$D/value.txt")" = 10 ]; check "revert restores tracked files" $?
[ ! -e "$D/new.txt" ] && [ ! -e "$D/sub/deep/f.txt" ]; check "revert removes untracked files and folders" $?
[ ! -e "$D/staged.txt" ]; check "revert removes files that were staged but never committed" $?
[ -e "$D/ignored.log" ]; check "revert leaves ignored files alone" $?
[ -f "$D/docs/experiments.md" ] && [ "$(rowcount reverted)" = 1 ]; check "revert keeps docs/experiments.md and logs the row" $?
[ "$(g status --porcelain -uall | grep -v 'docs/experiments.md' | wc -l | tr -d ' ')" = 0 ]; check "after revert only the log differs from HEAD" $?
val 12; ex keep "good" 12 >/dev/null
[ "$(rowcount baseline)" = 1 ] && [ "$(rowcount reverted)" = 1 ] && [ "$(rowcount kept)" = 1 ]; check "an earlier uncommitted reverted row survives the next keep" $?
newproj; ex baseline >/dev/null; val 5
out=$(ex revert "pipes | in | text" 5 "a|b"); [ "$(rowcount reverted)" = 1 ]; check "pipes in variant text do not break the table" $?
out=$(ex status); grep -q '^NO_PROGRESS=1$' <<<"$out"; check "status still parses the row after pipes" $?

echo "status / stop rule"
newproj; out=$(ex status); grep -q '^STOP=no$' <<<"$out" && grep -q 'no baseline' <<<"$out"; check "status before a baseline: STOP=no" $?
ex baseline >/dev/null
out=$(ex status); grep -q '^BASELINE=10$' <<<"$out" && grep -q '^STOP=no$' <<<"$out" && grep -q '^NO_PROGRESS=0$' <<<"$out"; check "status after baseline: continue" $?
val 8; ex revert a 8 >/dev/null
out=$(ex status); grep -q '^NO_PROGRESS=1$' <<<"$out" && grep -q '^STOP=no$' <<<"$out"; check "1 non-improving variant: continue" $?
val 7; ex revert b 7 >/dev/null
out=$(ex status); grep -q '^NO_PROGRESS=2$' <<<"$out" && grep -q '^STOP=yes$' <<<"$out" && grep -q '2 variants in a row' <<<"$out"; check "2 non-improving variants in a row: STOP=yes" $?
newproj; ex baseline >/dev/null
val 8; ex revert a 8 >/dev/null; val 11; ex keep b 11 >/dev/null; val 6; ex revert c 6 >/dev/null
out=$(ex status); grep -q '^NO_PROGRESS=1$' <<<"$out" && grep -q '^STOP=no$' <<<"$out"; check "a kept variant resets the no-progress count" $?
newproj higher 12; ex baseline >/dev/null
out=$(ex status); grep -q '^STOP=no$' <<<"$out"; check "target not reached: continue" $?
val 12; ex keep hit 12 >/dev/null
out=$(ex status); grep -q '^STOP=yes$' <<<"$out" && grep -q 'target reached' <<<"$out"; check "target reached: STOP=yes" $?
newproj lower 5; ex baseline >/dev/null; val 4; ex keep fast 4 >/dev/null
out=$(ex status); grep -q '^STOP=yes$' <<<"$out" && grep -q 'target reached' <<<"$out"; check "lower is better: target reached when best <= target" $?

echo
echo "Result: $pass passed, $fail failed"
[ $fail -eq 0 ]
