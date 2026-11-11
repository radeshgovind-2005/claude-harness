#!/usr/bin/env bash
# Tests scripts/explore.sh (the experiment loop's referee) against throwaway git repos.
# Run from anywhere:  /bin/bash tests/explore-test.sh
# shellcheck disable=SC2319  # `[ test ]; check name $?` reads the test's status on purpose

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EX="$ROOT/plugins/dev-harness/scripts/explore.sh"
pass=0; fail=0
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
# explore.sh commits with whatever identity git has; CI has none, so give the tests one.
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

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
grep -q 'not on main' <<<"$out"; check "start says the variants are kept off main" $?
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
! grep -q 'YYYY-MM-DD' "$D/docs/experiments.md"; check "baseline removes the template's example row" $?
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

echo "review fixes (v0.4.0 skeptic)"
al=$(sed -n 's/^allowed-tools:[[:space:]]*//p' "$ROOT/plugins/dev-harness/skills/explore/SKILL.md")
! grep -q 'Edit' <<<"$al" && grep -q 'explore.sh' <<<"$al"; check "the Metric edit is not pre-approved (Claude Code asks, showing the command)" $?
# 1. a user file whose name merely starts with the log's name is not the log
for junk in docs/experiments.md.bak docs/experiments.md.old; do
  D=$(mktemp -d "$W/p.XXXX"); git -C "$D" init -q -b main; echo 10 > "$D/value.txt"; mkdir -p "$D/docs"; echo precious > "$D/$junk"
  g add -A; g commit -q -m init; echo "edited" >> "$D/$junk"
  [ "$(exs start t)" != 0 ]; check "start refuses a tree whose only dirt is $junk" $?
done
D=$(mktemp -d "$W/p.XXXX"); git -C "$D" init -q -b main; echo 10 > "$D/value.txt"; g add -A; g commit -q -m init
ex start t >/dev/null; setline "Measured by" '`cat value.txt`'; setline Direction "higher is better"; setline Target none; ex baseline >/dev/null
echo precious > "$D/docs/experiments.md.bak"; val 5
ex revert v 5 >/dev/null; [ ! -e "$D/docs/experiments.md.bak" ] && [ -n "$(g for-each-ref refs/explore/)" ]; check "revert backs up an untracked look-alike before discarding it (ref exists)" $?
tarf=$(ls "$D"/.git/explore-backups/*.tar 2>/dev/null | head -1); [ -n "$tarf" ] && tar -tf "$tarf" | grep -q 'experiments.md.bak'; check "the untracked file is in the backup tar" $?
# 4. revert saves tracked changes too
newproj; ex baseline >/dev/null; val 9
ref=$(ex revert v 9 | sed -n 's/.*refs\/explore\/backup-\([^ ;)]*\).*/\1/p' | head -1)
[ -n "$ref" ] && [ "$(g show "refs/explore/backup-$ref:value.txt")" = 9 ]; check "revert saves the discarded tracked change under refs/explore/" $?
# 2. backslashes, quotes and ampersands in text do not corrupt the log
newproj; ex baseline >/dev/null; val 12
ex keep 'replace \n with space; a & b "quoted" $HOME `tick`' 12 'note \t tab \\ end' >/dev/null
out=$(ex status); grep -q '^BEST=12$' <<<"$out" && grep -q '^VARIANTS=1 ' <<<"$out"; check "backslashes and shell characters in the variant text keep the log parseable" $?
grep -qF 'replace \n with space; a & b "quoted" $HOME `tick`' "$D/docs/experiments.md"; check "the variant text is written verbatim" $?
val 11; [ "$(exs keep next 11)" != 0 ]; check "after such a row, a worse value is still refused" $?
# 3. a failing commit rolls the log row back and can be retried
newproj; ex baseline >/dev/null; val 12
mkdir -p "$D/.git/hooks"; printf '#!/bin/sh\necho "hook says no" >&2\nexit 1\n' > "$D/.git/hooks/pre-commit"; chmod +x "$D/.git/hooks/pre-commit"
out=$(ex keep v1 12); [ "$(exs keep v1 12)" != 0 ] && grep -q 'git commit failed' <<<"$out"; check "a failing commit hook: keep fails loudly" $?
[ "$(rowcount kept)" = 0 ]; check "no 'kept' row is left behind" $?
out=$(ex status); grep -q '^BEST=10$' <<<"$out"; check "the best value did not move" $?
[ "$(cat "$D/value.txt")" = 12 ] && [ -z "$(g diff --cached --name-only)" ]; check "the variant is still in the tree and unstaged" $?
rm "$D/.git/hooks/pre-commit"; out=$(ex keep v1 12); [ $? -eq 0 ] && [ "$(rowcount kept)" = 1 ]; check "after fixing the hook, the same keep works" $?
# 12. branches
D=$(mktemp -d "$W/p.XXXX"); git -C "$D" init -q -b main; echo 10 > "$D/value.txt"; g add -A; g commit -q -m init; g switch -q -c feature/x
ex start t >/dev/null; [ "$(git -C "$D" branch --show-current)" = "explore/t" ]; check "start on a feature branch also gets an explore/ branch" $?
D=$(mktemp -d "$W/p.XXXX"); git -C "$D" init -q -b main; echo 10 > "$D/value.txt"; g add -A; g commit -q -m init; g checkout -q --detach
[ "$(exs start t)" != 0 ]; check "start refuses a detached HEAD" $?
newproj; ex baseline >/dev/null; val 12; g checkout -q --detach
o1=$(ex keep v 12); o2=$(ex revert v 12)
grep -q 'detached HEAD' <<<"$o1" && grep -q 'detached HEAD' <<<"$o2"; check "keep and revert refuse a detached HEAD, and say why" $?
newproj; ex baseline >/dev/null; val 12; g switch -q -c other
[ "$(exs keep v 12)" != 0 ]; check "keep refuses outside an explore/ branch" $?
# 5. numbers
newproj higher none 'echo ".75"'; [ "$(ex measure)" = "VALUE=.75" ]; check "a leading-dot number is read whole (.75)" $?
newproj higher none 'echo "ratio: .5"'; [ "$(ex measure)" = "VALUE=.5" ]; check "ratio: .5 is read as .5" $?
newproj higher none 'echo "p95=1,234 ms"'; out=$(ex measure); [ "$(exs measure)" != 0 ] && grep -q 'thousands separator' <<<"$out"; check "a thousands separator is refused, not misread as 234" $?
newproj higher none 'echo "done in 12 s (run 3)"'; out=$(ex measure 2>&1); grep -q 'VALUE=3' <<<"$out" && grep -q 'NOTE .*more than one number' <<<"$out"; check "a line with several numbers: uses the last and says so" $?
# the shared runner keeps only the tail of huge output
( . "$ROOT/plugins/dev-harness/scripts/lib.sh"; run_limited 20 'head -c 200000 /dev/zero | tr "\\0" "y"'; [ "${#RUN_OUT}" -le 20000 ] && [ "${#RUN_OUT}" -gt 1000 ] ); check "run_limited keeps at most the last 20000 bytes of output" $?
( . "$ROOT/plugins/dev-harness/scripts/lib.sh"; run_limited 20 'echo out; echo err >&2; exit 4'; [ "$RUN_RC" = 4 ] && [ "$RUN_TIMED_OUT" = 0 ] && grep -q err <<<"$RUN_OUT" ); check "run_limited reports exit code and merges stderr" $?
# 8. no process is left sleeping
newproj higher none 'echo 1'; EXPLORE_TIMEOUT=777 ex measure >/dev/null
sleep 1; [ -z "$(pgrep -f 'sleep 777' || true)" ]; check "no sleeping helper process is left behind" $?
start=$(date +%s); EXPLORE_TIMEOUT=600 ex measure >/dev/null; [ $(( $(date +%s) - start )) -lt 3 ]; check "a fast metric returns fast (no fixed wait)" $?

echo "Optional Metric lines (Runs, Noise, Correctness, Evidence) and --file"
# addline TEXT: add a Metric line right after "- Target:".
addline() { T="$1" awk 'BEGIN { t = ENVIRON["T"] } { print } /^- Target:/ { print t }' "$D/docs/experiments.md" > "$D/.exp.tmp" && mv "$D/.exp.tmp" "$D/docs/experiments.md"; }
newproj; addline "- Runs: 5"; g add -A; g commit -q -m metric
out=$(ex baseline); [ "$(exs baseline)" != 0 ] && grep -q "Runs: 5" <<<"$out"; check "Runs: 5 refuses a single-run baseline" $?
[ "$(exs measure --runs 3)" != 0 ]; check "Runs: 5 refuses measure --runs 3" $?
out=$(ex baseline --runs 5); grep -q '^SPREAD=0.00%' <<<"$out"; check "a 5-run baseline is recorded and prints its SPREAD" $?
newproj higher none 'n=$(cat count 2>/dev/null || echo 0); n=$((n+1)); echo $n > count; case $n in 1) echo 9;; 2) echo 11;; *) echo 10;; esac'
out=$(ex measure --runs 3); grep -q '^SPREAD=20.00%$' <<<"$out"; check "SPREAD is (max - min) / median (9..11 of 10 = 20%)" $?
newproj; addline "- Noise: 5%"; g add -A; g commit -q -m metric; ex baseline >/dev/null
val 10.3; out=$(ex keep "tiny" 10.3); [ "$(rowcount kept)" = 0 ] && grep -q 'within the noise threshold (Noise: 5%)' <<<"$out"; check "Noise: 5% refuses a 3% gain" $?
val 10.6; ex keep "real" 10.6 >/dev/null; [ "$(rowcount kept)" = 1 ]; check "Noise: 5% keeps a 6% gain" $?
newproj lower; addline "- Noise: 5%"; g add -A; g commit -q -m metric; ex baseline >/dev/null
val 9.7; [ "$(exs keep tiny 9.7)" != 0 ]; check "Noise with lower is better: a 3% drop is refused" $?
val 9; ex keep real 9 >/dev/null; [ "$(rowcount kept)" = 1 ]; check "Noise with lower is better: a 10% drop is kept" $?
newproj; addline "- Correctness: \`test -f ok.flag\`"; g add -A; g commit -q -m metric; ex baseline >/dev/null
val 12; out=$(ex keep "faster but wrong" 12); [ "$(rowcount kept)" = 0 ] && grep -q 'correctness check failed' <<<"$out"; check "Correctness failing: keep is refused" $?
[ "$(git -C "$D" log --oneline | wc -l | tr -d ' ')" = 2 ]; check "... and nothing is committed" $?
touch "$D/ok.flag"; ex keep "faster and right" 12 >/dev/null; [ "$(rowcount kept)" = 1 ]; check "Correctness passing: keep works" $?
newproj; addline "- Evidence: required"; g add -A; g commit -q -m metric; ex baseline >/dev/null
val 12; out=$(ex keep "hunch" 12); [ "$(rowcount kept)" = 0 ] && grep -q 'needs --evidence' <<<"$out"; check "Evidence: required refuses keep without --evidence" $?
: > "$W/empty.txt"; [ "$(exs keep hunch 12 --evidence "$W/empty.txt")" != 0 ]; check "... and with an empty evidence file" $?
echo "hot: parse() 80%" > "$W/prof.txt"; ex keep "cache parse" 12 "memo" --evidence "$W/prof.txt" >/dev/null
[ "$(rowcount kept)" = 1 ] && grep -q "memo; evidence: $W/prof.txt" "$D/docs/experiments.md"; check "with evidence: kept, and the note names the file" $?
newproj; ex baseline >/dev/null; val 12; ex keep "plain" 12 >/dev/null; [ "$(rowcount kept)" = 1 ]; check "without the optional lines, keep works as before" $?
newproj; addline "- Correctness: false"; g add -A; g commit -q -m metric; ex baseline >/dev/null
val 12; out=$(ex keep v1 12); [ "$(rowcount kept)" = 0 ] && grep -q "Correctness" <<<"$out"; check "a Correctness line without backticks is refused, not ignored" $?
newproj; addline "- Runs: three"; g add -A; g commit -q -m metric
out=$(ex measure); [ "$(exs measure)" != 0 ] && grep -q "Runs" <<<"$out"; check "a Runs line without a number is refused, not ignored" $?
newproj; addline "- Noise: a little"; g add -A; g commit -q -m metric; ex baseline >/dev/null
val 12; [ "$(exs keep v 12)" != 0 ] && [ "$(rowcount kept)" = 0 ]; check "a Noise line without a number is refused, not ignored" $?
newproj; addline "- Evidence: yes please"; g add -A; g commit -q -m metric; ex baseline >/dev/null
val 12; [ "$(exs keep v 12)" != 0 ]; check "an Evidence line that is not 'required' is refused, not ignored" $?
newproj; addline "- Noise: <set this from the baseline SPREAD>"; addline "- Correctness: \`<the test command>\`"; g add -A; g commit -q -m metric; ex baseline >/dev/null
val 12; ex keep v 12 >/dev/null; [ "$(rowcount kept)" = 1 ]; check "template <placeholders> still count as not set" $?

D=$(mktemp -d "$W/p.XXXX"); git -C "$D" init -q -b main; echo 10 > "$D/value.txt"; g add -A; g commit -q -m init
printf '# Perf\n\n## Metric\n- Name: v\n- Measured by: `cat value.txt`\n- Direction: higher is better\n- Target: none\n\n| Date | Variant | Metric | Result | Kept or reverted | Note |\n|---|---|---|---|---|---|\n' > "$W/perf-tpl.md"
out=$(ex --file docs/perf.md --template "$W/perf-tpl.md" start p); [ -f "$D/docs/perf.md" ] && [ ! -e "$D/docs/experiments.md" ]; check "--file and --template: start creates docs/perf.md" $?
ex --file docs/perf.md baseline >/dev/null; grep -q '| baseline |' "$D/docs/perf.md"; check "--file: baseline logs into docs/perf.md" $?
[ "$(exs --file ../outside.md status)" != 0 ]; check "--file outside the project is refused" $?

echo
echo "Result: $pass passed, $fail failed"
[ $fail -eq 0 ]
