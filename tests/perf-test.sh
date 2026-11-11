#!/usr/bin/env bash
# Tests the dev-harness-perf plugin: every part passes dev-harness's forge.sh check (so the pack is the
# reference example for forge), explore.sh works through the symlink, and the plugin's wiring.
# Run from anywhere:  /bin/bash tests/perf-test.sh
# shellcheck disable=SC2319  # `[ test ]; check name $?` reads the test's status on purpose

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
Q="$ROOT/plugins/dev-harness-perf"
FG="$ROOT/plugins/dev-harness/scripts/forge.sh"
pass=0; fail=0
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
check() { if [ "$2" = 0 ]; then echo "  PASS  $1"; pass=$((pass+1)); else echo "  FAIL  $1"; fail=$((fail+1)); fi; }

echo "Every perf part passes forge.sh check"
n=0
for d in "$Q"/parts/*/; do
  n=$((n+1)); p=$(basename "$d")
  out=$(bash "$FG" check "$d" 2>&1); st=$?
  [ $st = 0 ] && grep -q 'PASS  tests fail without the part' <<<"$out"; check "part $p passes check (its tests fail without it)" $?
  [ $st = 0 ] || printf '%s\n' "$out" | grep -E 'FAIL|\|' | sed 's/^/      /'
done
[ "$n" = 3 ]; check "three parts: perf-loop, profiler, perf-guard ($n)" $?
for p in perf-loop:skill profiler:agent perf-guard:hook; do
  grep -qx "type: ${p#*:}" "$Q/parts/${p%%:*}/spec.md"; check "${p%%:*} is a ${p#*:} part" $?
done
[ "$(readlink "$Q/parts/perf-loop/files/SKILL.md")" = ../../../skills/perf-loop/SKILL.md ]; check "the perf-loop part is the plugin's own skill (a link, not a copy)" $?
[ "$(readlink "$Q/parts/profiler/files/profiler.md")" = ../../../agents/profiler.md ]; check "the profiler part is the plugin's own agent (a link, not a copy)" $?

echo "explore.sh through the symlink"
[ -L "$Q/scripts/explore.sh" ] && [ -L "$Q/scripts/lib.sh" ]; check "scripts/explore.sh and lib.sh are links to dev-harness" $?
cmp -s "$Q/scripts/explore.sh" "$ROOT/plugins/dev-harness/scripts/explore.sh"; check "... to the same file (no copy to drift)" $?
D=$(mktemp -d "$W/p.XXXX"); git -C "$D" init -q -b main; echo 50 > "$D/ms.txt"; git -C "$D" add -A; git -C "$D" commit -q -m init
(cd "$D" && bash "$Q/scripts/explore.sh" --file docs/perf.md --template "$Q/templates/perf.md" start s >/dev/null 2>&1); check "start with the perf template" $?
grep -q '^- Runs: 5$' "$D/docs/perf.md" && grep -q '^- Evidence: required$' "$D/docs/perf.md"; check "docs/perf.md has Runs: 5 and Evidence: required" $?
sed -i.b 's/^- Measured by: .*/- Measured by: `cat ms.txt`/' "$D/docs/perf.md"; rm -f "$D/docs/perf.md.b"
out=$(cd "$D" && bash "$Q/scripts/explore.sh" --file docs/perf.md baseline --runs 5 2>&1); grep -q '^SPREAD=' <<<"$out"; check "baseline through the link works" $?

echo "Wiring"
jq -e '.dependencies == ["dev-harness"]' "$Q/.claude-plugin/plugin.json" >/dev/null; check "plugin.json depends on dev-harness" $?
jq -e '.plugins[] | select(.name == "dev-harness-perf" and .source == "./plugins/dev-harness-perf")' "$ROOT/.claude-plugin/marketplace.json" >/dev/null; check "the marketplace lists dev-harness-perf" $?
at=$(sed -n 's/^allowed-tools: //p' "$Q/skills/perf-loop/SKILL.md")
grep -q 'scripts/explore.sh \*' <<<"$at" && ! grep -qi 'forge' <<<"$at" && ! grep -Eq '(^| )(Edit|Write)' <<<"$at"; check "perf-loop pre-approves explore.sh only (never forge install, never edits)" $?
grep -q 'disable-model-invocation: true' "$Q/skills/perf-loop/SKILL.md"; check "perf-loop is user-invoked" $?
grep -qF '/dev-harness:forge install ${CLAUDE_PLUGIN_ROOT}/parts/perf-guard' "$Q/skills/perf-loop/SKILL.md"; check "perf-loop installs perf-guard through forge" $?
for k in PERF_CMD PERF_BASELINE PERF_MAX_REGRESSION_PCT PERF_DIRECTION PERF_RUNS; do
  grep -q "$k" "$Q/parts/perf-guard/files/perf-guard.sh" && grep -q "$k" "$Q/skills/perf-loop/SKILL.md"; check "$k is read by perf-guard and named by perf-loop" $?
done

echo
echo "Result: $pass passed, $fail failed"
[ $fail -eq 0 ]
