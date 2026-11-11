#!/usr/bin/env bash
# Tests scripts/forge.sh: the part spec bar, install per type, the registry, use/status, promote.
# Run from anywhere:  /bin/bash tests/forge-test.sh
# shellcheck disable=SC2319  # `[ test ]; check name $?` reads the test's status on purpose

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
P="$ROOT/plugins/dev-harness"
FG="$P/scripts/forge.sh"
pass=0; fail=0
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
export FORGE_TEST_TIMEOUT=30

check() { if [ "$2" = 0 ]; then echo "  PASS  $1"; pass=$((pass+1)); else echo "  FAIL  $1"; fail=$((fail+1)); fi; }
fg() { bash "$FG" "$@" 2>&1; }

# spec TYPE NAME [extra frontmatter lines]: a complete spec.md on stdout.
spec() {
  printf -- '---\nname: %s\ntype: %s\nstatus: experimental\nuses: 0\n' "$2" "$1"
  [ "$1" = hook ] && printf 'event: PreToolUse\nmatcher: Bash\ntimeout: 10\n'
  printf -- '---\n\n# %s\n\n' "$2"
  for s in "Purpose" "Which type and why" "Trigger" "Inputs and outputs" "Method or loop" "Unacceptable" "Success check" "Tests"; do
    printf '## %s\nReal text for %s.\n\n' "$s" "$s"
  done
  printf '## Budget\nn/a — not a loop.\n'
}
# mkpart TYPE NAME: a part folder in $W that passes check; prints its path.
mkpart() {
  local t="$1" n="$2" d; d=$(mktemp -d "$W/part.XXXX")/"$n"; mkdir -p "$d/files" "$d/tests"
  spec "$t" "$n" > "$d/spec.md"
  case "$t" in
    hook)
      printf '#!/usr/bin/env bash\ngrep -q "DROP DATABASE" && { echo "BLOCKED: no DROP DATABASE" >&2; exit 2; }\nexit 0\n' > "$d/files/$n.sh"; chmod +x "$d/files/$n.sh"
      printf '#!/usr/bin/env bash\nh="$FILES_DIR/%s.sh"\necho "{\\"tool_input\\":{\\"command\\":\\"psql -c DROP DATABASE x\\"}}" | bash "$h" 2>/dev/null; [ $? = 2 ] || exit 1\necho "{\\"tool_input\\":{\\"command\\":\\"ls\\"}}" | bash "$h" || exit 1\n' "$n" > "$d/tests/blocks.sh" ;;
    skill)
      printf -- '---\nname: %s\ndescription: Release checklist.\n---\n\n1. Run the tests.\n2. Bump the version.\n' "$n" > "$d/files/SKILL.md"
      printf '#!/usr/bin/env bash\ngrep -q "Run the tests" "$FILES_DIR/SKILL.md"\n' > "$d/tests/steps.sh" ;;
    agent)
      printf -- '---\nname: %s\ndescription: Reviews migrations.\ntools: Read, Grep, Glob\n---\n\nSTATUS: line first.\n' "$n" > "$d/files/$n.md"
      printf '#!/usr/bin/env bash\ngrep -q "^STATUS:" "$FILES_DIR/%s.md"\n' "$n" > "$d/tests/format.sh" ;;
    rule)
      printf -- '---\npaths:\n  - "migrations/**"\n---\n\nNever edit an applied migration.\n' > "$d/files/$n.md"
      printf '#!/usr/bin/env bash\ngrep -q "applied migration" "$FILES_DIR/%s.md"\n' "$n" > "$d/tests/rule.sh" ;;
  esac
  chmod +x "$d/tests/"*.sh; printf '%s' "$d"
}
newproj() { D=$(mktemp -d "$W/proj.XXXX"); git -C "$D" init -q -b main; mkdir -p "$D/docs"; cp "$P/templates/project/docs/parts.md" "$D/docs/parts.md"; }
setfm() { awk -v k="$2" -v v="$3" 'NR==1 {print; next} !e && /^---/ {e=1} !e && index($0, k ":")==1 {print k ": " v; next} {print}' "$1" > "$1.t" && mv "$1.t" "$1"; }

echo "check: a complete part of each type passes"
for t in hook skill agent rule; do
  d=$(mkpart "$t" "my-$t"); out=$(fg check "$d"); st=$?
  [ $st = 0 ] && grep -q 'PASS  tests fail without the part' <<<"$out"; check "$t part passes check" $?
done

echo "check: the spec"
d=$(mkpart hook h1); rm "$d/spec.md"
out=$(fg check "$d"); [ $? -ne 0 ] && grep -q 'no spec, no part' <<<"$out"; check "no spec.md: FAIL" $?
d=$(mkpart hook h1); awk '/^## Trigger/ {print; getline; next} {print}' "$d/spec.md" > "$d/s" && mv "$d/s" "$d/spec.md"
out=$(fg check "$d"); [ $? -ne 0 ] && grep -q "'Trigger'" <<<"$out"; check "an empty section: FAIL naming it" $?
d=$(mkpart hook h1); sed -i.b 's/^Real text for Unacceptable\.$/<Hard stops: what it must never do.>/' "$d/spec.md"
out=$(fg check "$d"); [ $? -ne 0 ] && grep -q "'Unacceptable'" <<<"$out"; check "a placeholder section: FAIL" $?
d=$(mkpart hook h1); sed -i.b 's/^n\/a — not a loop\.$/n\/a/' "$d/spec.md"
out=$(fg check "$d"); [ $? -ne 0 ] && grep -q "Budget'(n/a needs a reason" <<<"$out"; check "Budget 'n/a' without a reason: FAIL" $?
d=$(mkpart hook h1); setfm "$d/spec.md" type macro
! fg check "$d" >/dev/null; check "an unknown type: FAIL" $?
d=$(mkpart hook h1); setfm "$d/spec.md" event OnSave
out=$(fg check "$d"); [ $? -ne 0 ] && grep -q 'event(' <<<"$out"; check "a hook with an unknown event: FAIL" $?
d=$(mkpart hook h1); grep -v '^matcher:' "$d/spec.md" > "$d/s" && mv "$d/s" "$d/spec.md"
! fg check "$d" >/dev/null; check "a hook without the matcher key: FAIL" $?
d=$(mkpart skill s1); setfm "$d/spec.md" uses many
! fg check "$d" >/dev/null; check "uses that is not a number: FAIL" $?
d=$(mkpart skill s1); setfm "$d/spec.md" status proven; setfm "$d/spec.md" uses 2
out=$(fg check "$d"); [ $? -ne 0 ] && grep -q 'proven needs at least 3' <<<"$out"; check "proven with 2 uses: FAIL" $?
setfm "$d/spec.md" uses 3; fg check "$d" >/dev/null; check "proven with 3 uses: passes" $?

echo "check: files fit the type"
d=$(mkpart hook h1); chmod -x "$d/files/h1.sh"
! fg check "$d" >/dev/null; check "a hook script that is not executable: FAIL" $?
d=$(mkpart hook h1); cp "$d/files/h1.sh" "$d/files/second.sh"
! fg check "$d" >/dev/null; check "a hook part with two scripts: FAIL" $?
d=$(mkpart skill s1); sed -i.b 's/^name: s1$/name: other/' "$d/files/SKILL.md"; rm -f "$d/files/SKILL.md.b"
! fg check "$d" >/dev/null; check "SKILL.md whose name differs from the part: FAIL" $?
d=$(mkpart agent a1); sed -i.b 's/^tools: .*/tools: Read, Edit/' "$d/files/a1.md"; rm -f "$d/files/a1.md.b"
out=$(fg check "$d"); [ $? -ne 0 ] && grep -q 'no edit tool' <<<"$out"; check "an agent with Edit: FAIL" $?
d=$(mkpart agent a1); grep -v '^tools:' "$d/files/a1.md" > "$d/x" && mv "$d/x" "$d/files/a1.md"
! fg check "$d" >/dev/null; check "an agent without tools: FAIL" $?
d=$(mkpart rule r1); printf -- '---\ndescription: x\n---\nNever edit an applied migration.\n' > "$d/files/r1.md"
! fg check "$d" >/dev/null; check "a rule without paths: FAIL" $?

echo "check: tests exist, pass, and fail without the part"
d=$(mkpart hook h1); rm "$d/tests/"*.sh
out=$(fg check "$d"); [ $? -ne 0 ] && grep -q 'no tests, no part' <<<"$out"; check "no tests: FAIL" $?
d=$(mkpart hook h1); printf '#!/usr/bin/env bash\necho boom; exit 1\n' > "$d/tests/bad.sh"; chmod +x "$d/tests/bad.sh"
out=$(fg check "$d"); [ $? -ne 0 ] && grep -q 'failing: bad.sh (1)' <<<"$out" && grep -q '| boom' <<<"$out"; check "a failing test: FAIL with its output" $?
d=$(mkpart hook h1); printf '#!/usr/bin/env bash\ntrue\n' > "$d/tests/blocks.sh"
out=$(fg check "$d"); [ $? -ne 0 ] && grep -q 'the tests do not test the part' <<<"$out"; check "tests that pass with files/ emptied: FAIL" $?
d=$(mkpart hook h1); printf '#!/usr/bin/env bash\nsleep 60\n' > "$d/tests/slow.sh"; chmod +x "$d/tests/slow.sh"
out=$(FORGE_TEST_TIMEOUT=2 fg check "$d"); [ $? -ne 0 ] && grep -q 'slow.sh (timeout)' <<<"$out"; check "a test over the time limit: FAIL" $?
d=$(mkpart hook h1); before=$(cat "$d/files/h1.sh"); fg check "$d" >/dev/null
[ "$(cat "$d/files/h1.sh")" = "$before" ]; check "check never changes the part (tests run on a copy)" $?

echo "install"
for t in hook skill agent rule; do
  newproj; d=$(mkpart "$t" "my-$t"); fg install "$d" --project "$D" >/dev/null; check "$t: install exits 0" $?
done
newproj; d=$(mkpart hook guard-drop); fg install "$d" --project "$D" >/dev/null
[ -x "$D/.claude/hooks/guard-drop.sh" ]; check "hook: copied to .claude/hooks and executable" $?
jq -e '.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[] | select(.command == "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/guard-drop.sh" and .timeout == 10)' "$D/.claude/settings.json" >/dev/null; check "hook: registered in settings.json with matcher and timeout" $?
[ -f "$D/.claude/forge/guard-drop/spec.md" ] && [ -d "$D/.claude/forge/guard-drop/tests" ]; check "the part is staged in .claude/forge/<name>" $?
grep -q '^| guard-drop | hook | experimental | 0 | yes | `.claude/forge/guard-drop/spec.md` |$' "$D/docs/parts.md"; check "the registry has its row" $?
echo '{"tool_input":{"command":"DROP DATABASE prod"}}' | bash "$D/.claude/hooks/guard-drop.sh" 2>/dev/null; [ $? = 2 ]; check "the installed hook works" $?
newproj; printf '{"permissions":{"allow":["Bash(ls)"]},"hooks":{"PreToolUse":[{"matcher":"Edit","hooks":[{"type":"command","command":"x.sh"}]}]}}\n' > "$D/.claude-settings.tmp"
mkdir -p "$D/.claude"; mv "$D/.claude-settings.tmp" "$D/.claude/settings.json"
d=$(mkpart hook g2); fg install "$d" --project "$D" >/dev/null
jq -e '.permissions.allow == ["Bash(ls)"] and (.hooks.PreToolUse | length) == 2' "$D/.claude/settings.json" >/dev/null; check "existing settings are kept; the hook is added" $?
newproj; d=$(mkpart skill rel); fg install "$d" --project "$D" >/dev/null
[ -f "$D/.claude/skills/rel/SKILL.md" ]; check "skill: .claude/skills/<name>/SKILL.md" $?
newproj; d=$(mkpart agent rev); fg install "$d" --project "$D" >/dev/null; [ -f "$D/.claude/agents/rev.md" ]; check "agent: .claude/agents/<name>.md" $?
newproj; d=$(mkpart rule mig); fg install "$d" --project "$D" >/dev/null; [ -f "$D/.claude/rules/mig.md" ]; check "rule: .claude/rules/<name>.md" $?
newproj; d=$(mkpart rule mig); mkdir -p "$D/.claude/rules"; echo mine > "$D/.claude/rules/mig.md"
out=$(fg install "$d" --project "$D"); [ $? -ne 0 ] && grep -q 'never overwrites' <<<"$out" && [ "$(cat "$D/.claude/rules/mig.md")" = mine ]; check "an existing target is never overwritten" $?
newproj; d=$(mkpart hook h1); printf '#!/usr/bin/env bash\ntrue\n' > "$d/tests/blocks.sh"
out=$(fg install "$d" --project "$D"); [ $? -ne 0 ] && [ ! -e "$D/.claude/hooks/h1.sh" ] && grep -q 'nothing was installed' <<<"$out"; check "a part that fails check is not installed" $?
newproj; rm "$D/docs/parts.md"; d=$(mkpart rule r9); fg install "$d" --project "$D" >/dev/null
grep -q '| r9 | rule |' "$D/docs/parts.md"; check "a missing docs/parts.md is created from the template" $?

echo "use, status, list"
newproj; d=$(mkpart skill rel); fg install "$d" --project "$D" >/dev/null
out=$(fg status rel proven --project "$D"); [ $? -ne 0 ] && grep -q 'proven needs at least 3' <<<"$out"; check "status proven with 0 uses is refused" $?
for _ in 1 2 3; do fg use rel --project "$D" >/dev/null; done
grep -qx 'uses: 3' "$D/.claude/forge/rel/spec.md" && grep -q '^| rel | skill | experimental | 3 |' "$D/docs/parts.md"; check "use counts in the spec and the registry" $?
fg status rel proven --project "$D" >/dev/null; grep -qx 'status: proven' "$D/.claude/forge/rel/spec.md"; check "status proven after 3 uses" $?
fg list --project "$D" >/dev/null; check "list: the registry matches" $?
sed -i.b 's/| proven |/| experimental |/' "$D/docs/parts.md"; ! fg list --project "$D" >/dev/null; check "list: a hand-edited registry is drift" $?
! fg use ghost --project "$D" >/dev/null; check "use of an unknown part fails" $?
! fg use '../x' --project "$D" >/dev/null; check "a part name with a path is refused" $?
rm -rf "$D/.claude/skills/rel"; ! fg use rel --project "$D" >/dev/null; check "use of a part that is not installed fails" $?

echo "promote"
mkclone() { C=$(mktemp -d "$W/clone.XXXX"); mkdir -p "$C/.claude-plugin" "$C/plugins/pack"; echo '{}' > "$C/.claude-plugin/marketplace.json"; git -C "$C" init -q -b main; git -C "$C" add -A; git -C "$C" commit -q -m init; }
newproj; d=$(mkpart skill rel); fg install "$d" --project "$D" >/dev/null; mkclone
out=$(fg promote rel --to "$C" --plugin pack --project "$D"); [ $? -ne 0 ] && grep -q 'only a proven part' <<<"$out"; check "promote refuses an experimental part" $?
for _ in 1 2 3; do fg use rel --project "$D" >/dev/null; done; fg status rel proven --project "$D" >/dev/null
echo dirt > "$C/x"; ! fg promote rel --to "$C" --plugin pack --project "$D" >/dev/null; check "promote refuses a dirty clone" $?
rm "$C/x"; ! fg promote rel --to "$C" --plugin nope --project "$D" >/dev/null; check "promote refuses an unknown plugin" $?
out=$(fg promote rel --to "$C" --plugin pack --project "$D"); st=$?
[ $st = 0 ] && [ "$(git -C "$C" symbolic-ref --short HEAD)" = promote/rel ]; check "promote creates branch promote/<name>" $?
[ -f "$C/plugins/pack/parts/rel/spec.md" ] && [ -f "$C/plugins/pack/skills/rel/SKILL.md" ]; check "the part and the skill are copied into the plugin" $?
[ "$(git -C "$C" log --oneline | wc -l | tr -d ' ')" = 1 ]; check "promote commits nothing" $?
git -C "$C" switch -q main; git -C "$C" stash -u -q 2>/dev/null; ! fg promote rel --to "$C" --plugin pack --project "$D" >/dev/null; check "a second promote (branch exists) is refused" $?

echo "Usage"
bash "$FG" --help | grep -q 'forge.sh promote <name>'; check "--help prints the usage" $?
! bash "$FG" bogus >/dev/null 2>&1; check "an unknown command fails" $?

echo
echo "Result: $pass passed, $fail failed"
[ $fail -eq 0 ]
