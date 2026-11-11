#!/usr/bin/env bash
# perf-loop: the skill names the enforced steps, and the docs/perf.md template it ships makes explore.sh
# refuse each Unacceptable: no baseline, a single cold run, a gain inside the noise, a failing
# correctness check, and a change without profiler evidence.
pass=0; fail=0
c() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else echo "FAIL $1 (expected $2, got $3)"; fail=$((fail+1)); fi; }
S="$FILES_DIR/SKILL.md"
for w in 'explore.sh --file docs/perf.md' 'baseline --runs 5' '--evidence' 'dev-harness-perf:profiler' 'Noise:' 'Correctness' 'parts/perf-guard'; do
  grep -qF -- "$w" "$S"; c "the skill names: $w" 0 $?
done
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
EX="$PART_DIR/tests/fixtures/scripts/explore.sh"; TPL="$PART_DIR/tests/fixtures/perf.md"
D=$(mktemp -d); E=$(mktemp -d); trap 'rm -rf "$D" "$E"' EXIT
git -C "$D" init -q -b main; echo 100 > "$D/ms.txt"; git -C "$D" add -A; git -C "$D" commit -q -m init
x() { (cd "$D" && bash "$EX" --file docs/perf.md "$@" >"$E/out" 2>&1); echo $?; }
c "start creates docs/perf.md from the template"  0 "$(x --template "$TPL" start speed)"
setl() { T="$2" awk -v l="$1" 'BEGIN {t = ENVIRON["T"]} $0 ~ "^- " l ":" {print "- " l ": " t; next} {print}' "$D/docs/perf.md" > "$E/p" && cat "$E/p" > "$D/docs/perf.md"; }
setl "Measured by" '`cat ms.txt`'; setl Correctness '`test -f tests-pass`'
git -C "$D" add -A; git -C "$D" commit -q -m metric
c "a change without a baseline is refused"        1 "$(echo 90 > "$D/ms.txt"; x keep v 90 h --evidence /etc/hosts; grep -q "no baseline" "$E/out" || echo X; git -C "$D" checkout -q -- ms.txt)"
c "a single cold run is refused (Runs: 5)"        1 "$(x baseline)"
c "a 5-run baseline is recorded"                  0 "$(x baseline --runs 5)"
grep -q '^SPREAD=' "$E/out"; c "... and prints SPREAD" 0 $?
setl Noise '5%'; git -C "$D" add -A; git -C "$D" commit -q -m noise
echo "hot: parse 70%" > "$E/profile.txt"; touch "$D/tests-pass"
echo 97 > "$D/ms.txt"; c "a gain inside the noise (3% of 5%) is refused" 1 "$(x keep small 97 h --evidence "$E/profile.txt")"
echo 80 > "$D/ms.txt"; c "no profiler evidence: refused"                 1 "$(x keep big 80 h)"
rm "$D/tests-pass"; c "a failing correctness check: refused"            1 "$(x keep big 80 h --evidence "$E/profile.txt")"
touch "$D/tests-pass"; c "evidence, beyond the noise, tests pass: kept"  0 "$(x keep big 80 h --evidence "$E/profile.txt")"
grep -q '| kept |' "$D/docs/perf.md"; c "the kept row is logged in docs/perf.md" 0 $?
echo "perf-loop tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
