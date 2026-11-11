#!/usr/bin/env bash
# Tests scripts/ax-check.sh (facts for the AX reviewer) and the lens skill's consistency.
# Run from anywhere:  /bin/bash tests/lens-test.sh
# shellcheck disable=SC2319  # `[ test ]; check name $?` reads the test's status on purpose

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
P="$ROOT/plugins/dev-harness"
AX="$P/scripts/ax-check.sh"
SC="$P/scripts/scaffold.sh"
pass=0; fail=0
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT

check() { if [ "$2" = 0 ]; then echo "  PASS  $1"; pass=$((pass+1)); else echo "  FAIL  $1"; fail=$((fail+1)); fi; }
# project PROFILE: a scaffolded project (files + guardrails) in $D
project() {
  D=$(mktemp -d "$W/p.XXXX"); git -C "$D" init -q -b main
  git -C "$D" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  bash "$SC" "$D" files --profile "${1:-product}" >/dev/null 2>&1
  bash "$SC" "$D" guardrails --profile "${1:-product}" >/dev/null 2>&1
}
ax() { bash "$AX" "$D" 2>&1; }
has() { grep -Eq "$1" <<<"$OUT"; }

echo "ax-check on a fresh scaffold"
project product; OUT=$(ax); bash "$AX" "$D" >/dev/null 2>&1; st=$?
[ $st -eq 0 ]; check "a fresh product scaffold has no FAIL (exit 0)" $?
has '^PASS +CLAUDE.md length'; check "CLAUDE.md length passes" $?
has '^PASS +routed paths exist'; check "every routed path exists" $?
has '^WARN +CLAUDE.md placeholders'; check "unfilled placeholders are a WARN" $?
has '^PASS +hooks registered'; check "registered hooks exist and are executable" $?
has '^PASS +harness.conf profile.*product'; check "profile product is read" $?
has '^WARN +VERIFY_CMD.*product'; check "a product scaffold with no stack has an empty VERIFY_CMD (a WARN, not a FAIL)" $?
has '^WARN +docs/intent.md.*missing'; check "no intent.md is a WARN" $?
has '^PASS +docs/progress.md'; check "progress.md present" $?
has '^SUMMARY pass=[0-9]+ warn=[0-9]+ fail=0$'; check "summary line counts zero failures" $?

echo "ax-check finds what an agent would hit"
project product; rm "$D/docs/workflow.md"; OUT=$(ax)
has '^FAIL +routed paths exist.*docs/workflow.md'; check "a deleted routed doc is a FAIL naming it" $?
bash "$AX" "$D" >/dev/null 2>&1; [ $? -ne 0 ]; check "a FAIL makes the exit code non-zero" $?
project product; chmod -x "$D/.claude/hooks/protect-paths.sh"; OUT=$(ax)
has '^FAIL +hooks registered.*protect-paths.sh'; check "a non-executable hook is a FAIL naming it" $?
project product; rm "$D/.claude/hooks/guard-bash.sh"; OUT=$(ax)
has '^FAIL +hooks registered.*guard-bash.sh'; check "a missing hook is a FAIL naming it" $?
project product; { cat "$D/CLAUDE.md"; for i in $(seq 1 45); do echo "- filler $i"; done; } > "$D/c.md"; mv "$D/c.md" "$D/CLAUDE.md"; OUT=$(ax)
has '^FAIL +CLAUDE.md length'; check "CLAUDE.md of 100+ lines is a FAIL" $?
project product; rm "$D/CLAUDE.md"; OUT=$(ax)
has '^FAIL +CLAUDE.md +—'; check "missing CLAUDE.md is a FAIL" $?
project product; printf -- '---\nstatus: discovering\n---\n' > "$D/docs/intent.md"; OUT=$(ax)
has '^WARN +docs/intent.md.*discovering'; check "intent.md still discovering is a WARN" $?
printf -- '---\nstatus: decided\n---\n' > "$D/docs/intent.md"; OUT=$(ax)
has '^PASS +docs/intent.md.*decided'; check "intent.md decided passes" $?
project product; sed -i.bak 's/^VERIFY_CMD=.*/VERIFY_CMD=""/' "$D/.claude/hooks/harness.conf"; rm -f "$D/.claude/hooks/harness.conf.bak"; OUT=$(ax)
has '^WARN +VERIFY_CMD.*product'; check "product with an empty VERIFY_CMD is a WARN" $?
project prototype; OUT=$(ax)
! has 'VERIFY_CMD'; check "prototype: an empty VERIFY_CMD is not reported" $?
project product; sed -i.bak 's/^PROFILE=.*/PROFILE=banana/' "$D/.claude/hooks/harness.conf"; rm -f "$D/.claude/hooks/harness.conf.bak"; OUT=$(ax)
has '^WARN +harness.conf profile.*banana'; check "an unknown profile is a WARN" $?
project product; rm "$D/.claude/settings.json"; OUT=$(ax)
has '^WARN +hooks registered.*no .claude/settings.json'; check "no settings.json is a WARN (no guardrails)" $?
project product; sed -i.bak -e 's/<project-name> — <one-line purpose>/demo — a demo/' -e 's/<language>, <framework>, <database>/bash/' -e 's/<one project-specific must-follow rule>/Keep it small./' -e 's/`<cmd>`/`make`/g' -e 's/`<cmd> <path>`/`make one`/' "$D/CLAUDE.md"; rm -f "$D/CLAUDE.md.bak"; OUT=$(ax)
has '^PASS +CLAUDE.md placeholders'; check "filled-in CLAUDE.md passes the placeholder check" $?
project product; printf '\n- See `docs/nope.md` and `.claude/missing/` for more.\n' >> "$D/CLAUDE.md"; OUT=$(ax)
has '^FAIL +routed paths exist.*docs/nope.md'; check "a made-up route in CLAUDE.md is a FAIL" $?
project product; printf '\n- Plans in `docs/plans/*.md`, local overrides in `.claude/settings.local.json`, see `docs/workflow.md#git` and `docs/workflow.md:12`.\n' >> "$D/CLAUDE.md"; OUT=$(ax)
has '^PASS +routed paths exist'; check "globs, #anchors, :line suffixes and settings.local.json are not false FAILs" $?
project product; printf '\n- See `docs/nope.md#intro` and `docs/nope2.md:9`.\n' >> "$D/CLAUDE.md"; OUT=$(ax)
has '^FAIL +routed paths exist.*docs/nope.md.*docs/nope2.md'; check "a missing file is still a FAIL after the anchor or line suffix is stripped" $?
project product; echo '{ not json .claude/hooks/protect-paths.sh' > "$D/.claude/settings.json"; OUT=$(ax)
has '^FAIL +hooks registered.*not valid JSON'; check "an invalid settings.json is a FAIL, not a PASS" $?
bash "$AX" "$W/not-a-dir" >/dev/null 2>&1; [ $? -ne 0 ]; check "a missing project dir fails" $?

echo "lens skill consistency"
for a in UX DX AX; do
  grep -q "^## $a " "$P/skills/lens/angles.md"; check "angles.md has a $a block" $?
done
grep -q 'dev-harness:lens-reviewer' "$P/skills/lens/SKILL.md" && [ -f "$P/agents/lens-reviewer.md" ]; check "lens names an agent that exists" $?
sed -n '/^---$/,/^---$/p' "$P/agents/lens-reviewer.md" | grep -q '^name: lens-reviewer$'; check "agent frontmatter name is lens-reviewer" $?
grep -q 'ax-check.sh' "$P/skills/lens/SKILL.md"; check "lens runs ax-check.sh" $?
grep -q 'ONE message' "$P/skills/lens/SKILL.md"; check "lens asks for the three reviewers in one message" $?
grep -q '3 of 3\|Three reviewers started' "$P/skills/lens/SKILL.md"; check "lens checks the fan-in" $?

echo "ax-check reads harness.conf like the project's harness-conf.sh"
project product
for v in 'PROFILE=product' 'PROFILE="product"' ' PROFILE = product ' $'PROFILE=product\r' 'PROFILE="product' $'PROFILE=banana\nPROFILE=product' "PROFILE=\"product\" "; do
  printf '%s\nVERIFY_CMD="make test"\n' "$v" > "$D/.claude/hooks/harness.conf"
  want=$(bash "$D/.claude/hooks/harness-conf.sh" PROFILE "")
  got=$(bash "$AX" "$D" 2>&1 | sed -nE 's/^(PASS|WARN) +harness\.conf profile [^ ]+ //p' | sed -E "s/^PROFILE is '(.*)', expected.*/\\1/")
  [ "$got" = "$want" ]; check "same PROFILE for [$(printf '%s' "$v" | tr '\r\n' '^|')]: '$want'" $?
done
printf 'PROFILE=product\nVERIFY_CMD=" make test "\n' > "$D/.claude/hooks/harness.conf"
OUT=$(ax); has "^PASS +VERIFY_CMD [^ ]+ set: $(bash "$D/.claude/hooks/harness-conf.sh" VERIFY_CMD x)\$"; check "same VERIFY_CMD for a quoted value with inner spaces" $?

echo
echo "Result: $pass passed, $fail failed"
[ $fail -eq 0 ]
