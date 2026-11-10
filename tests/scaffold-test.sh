#!/usr/bin/env bash
# Tests scripts/scaffold.sh and the discover lock against throwaway projects.
# Run from anywhere:  bash tests/scaffold-test.sh
# shellcheck disable=SC2319  # `[ test ]; check name $?` reads the test's status on purpose

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
P="$ROOT/plugins/dev-harness"
SC="$P/scripts/scaffold.sh"
LOCK="$P/skills/discover/discover-lock.sh"
pass=0; fail=0
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT

check() { if [ "$2" = 0 ]; then echo "  PASS  $1"; pass=$((pass+1)); else echo "  FAIL  $1"; fail=$((fail+1)); fi; }
newrepo() { local d; d=$(mktemp -d "$W/p.XXXX"); git -C "$d" init -q -b main; git -C "$d" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init; echo "$d"; }
edit_on_main() { # project -> exit code of the project's own protect-paths hook
  jq -n --arg f "$1/src/app.ts" '{tool_name:"Edit",tool_input:{file_path:$f}}' \
    | CLAUDE_PROJECT_DIR="$1" "$1/.claude/hooks/protect-paths.sh" 2>/dev/null; echo $?; }
snapshot() { (cd "$1" && find . -path ./.git -prune -o -type f -print | sort | xargs shasum 2>/dev/null); }

for prof in prototype product assignment; do
  echo "Profile: $prof"
  d=$(newrepo)
  bash "$SC" "$d" files --profile "$prof" >"$d.files.log" 2>&1; check "files phase exits 0" $?
  bash "$SC" "$d" guardrails --profile "$prof" >"$d.guard.log" 2>&1; check "guardrails phase exits 0" $?
  for f in CLAUDE.md docs/INDEX.md docs/workflow.md docs/lessons.md docs/agents/INDEX.md .claude/rules/example-api.md \
           .claude/settings.json .claude/hooks/harness.conf .github/workflows/dev-harness-hooks.yml; do
    [ -f "$d/$f" ]; check "has $f" $?
  done
  for h in protect-paths guard-bash format verify test-hooks; do [ -x "$d/.claude/hooks/$h.sh" ]; check "hook $h.sh is executable" $?; done
  grep -q 'ok      hook tests: Result: [0-9]* passed, 0 failed' "$d.guard.log"; check "project hook tests ran and passed" $?
  [ "$(grep -c '{{' "$d/CLAUDE.md")" = 0 ]; check "CLAUDE.md has no unrendered {{markers}}" $?
  grep -q "^- Profile: $prof " "$d/CLAUDE.md"; check "CLAUDE.md names profile $prof" $?
  [ "$(wc -l < "$d/CLAUDE.md")" -lt 100 ]; check "CLAUDE.md under 100 lines" $?
  grep -q "^PROFILE=$prof$" "$d/.claude/hooks/harness.conf"; check "harness.conf PROFILE=$prof" $?
  jq empty "$d/.claude/settings.json"; check "settings.json is valid JSON" $?
  grep -qxF "CLAUDE.local.md" "$d/.gitignore"; check ".gitignore ignores CLAUDE.local.md" $?
  case $prof in
    product)
      [ "$(edit_on_main "$d")" = 2 ]; check "product: edit on main is blocked" $?
      grep -qx 'BLOCK_MAIN=1' "$d/.claude/hooks/harness.conf"; check "product: BLOCK_MAIN=1" $?
      jq -e '.permissions.ask | index("Bash(git push:*)")' "$d/.claude/settings.json" >/dev/null; check "product: git push asks" $?
      grep -q 'Never work on `main`' "$d/CLAUDE.md"; check "product: CLAUDE.md says never work on main" $?
      grep -q '^VERIFY_CMD="..*"' "$d/.claude/hooks/harness.conf"; check "product: VERIFY_CMD set by default" $? ;;
    prototype)
      [ "$(edit_on_main "$d")" = 0 ]; check "prototype: edit on main is allowed" $?
      jq -e '.permissions.ask | index("Bash(git push:*)") | not' "$d/.claude/settings.json" >/dev/null; check "prototype: git push does not ask" $?
      grep -qx 'VERIFY_CMD=""' "$d/.claude/hooks/harness.conf"; check "prototype: verify off" $?
      ! grep -q 'Never work on `main`' "$d/CLAUDE.md"; check "prototype: CLAUDE.md does not forbid main" $? ;;
    assignment)
      [ "$(edit_on_main "$d")" = 0 ]; check "assignment: edit on main is allowed" $?
      grep -qi 'explain each step' "$d/CLAUDE.md"; check "assignment: CLAUDE.md asks to explain steps" $?
      grep -q '^VERIFY_CMD="..*"' "$d/.claude/hooks/harness.conf"; check "assignment: VERIFY_CMD set (tests)" $? ;;
  esac

  before=$(snapshot "$d")
  out=$(bash "$SC" "$d" files --profile "$prof"; bash "$SC" "$d" guardrails --profile "$prof")
  ! grep -Eq '^  (add|merge|update|FAIL) ' <<<"$out"; check "second run only skips" $?
  [ "$before" = "$(snapshot "$d")" ]; check "second run changes no file" $?
done

echo "No overwrite"
d=$(newrepo); mkdir -p "$d/docs" "$d/.claude/hooks"
echo "my rules" > "$d/CLAUDE.md"; echo "my lessons" > "$d/docs/lessons.md"; echo "# mine" > "$d/.claude/hooks/verify.sh"
bash "$SC" "$d" files --profile product >/dev/null 2>&1
bash "$SC" "$d" guardrails --profile product >/dev/null 2>&1
[ "$(cat "$d/CLAUDE.md")" = "my rules" ]; check "existing CLAUDE.md untouched" $?
[ "$(cat "$d/docs/lessons.md")" = "my lessons" ]; check "existing docs/lessons.md untouched" $?
[ "$(cat "$d/.claude/hooks/verify.sh")" = "# mine" ]; check "existing hook untouched" $?

echo "Dry run"
d=$(newrepo); before=$(snapshot "$d")
bash "$SC" "$d" files --profile product --dry-run >/dev/null 2>&1; check "files --dry-run exits 0" $?
bash "$SC" "$d" guardrails --profile product --dry-run >/dev/null 2>&1; check "guardrails --dry-run exits 0" $?
[ "$before" = "$(snapshot "$d")" ]; check "dry run writes nothing" $?

echo "--verify-cmd"
d=$(newrepo)
bash "$SC" "$d" guardrails --profile prototype --verify-cmd 'npm test -- --run && echo "ok"' >/dev/null 2>&1
grep -qxF 'VERIFY_CMD="npm test -- --run && echo "ok""' "$d/.claude/hooks/harness.conf"; check "verify cmd written verbatim" $?
bash "$SC" "$d" guardrails --profile prototype --verify-cmd $'a\nb' >/dev/null 2>&1; [ $? -ne 0 ]; check "multi-line verify cmd rejected" $?

echo "settings.json merge"
d=$(newrepo); mkdir -p "$d/.claude"
cat > "$d/.claude/settings.json" <<'JSON'
{ "model": "opus", "permissions": { "allow": ["Bash(make:*)", "Bash(git status)"], "deny": ["Read(./private/**)"] },
  "hooks": { "Stop": [ { "hooks": [ { "type": "command", "command": "echo mine" } ] } ] } }
JSON
orig=$(cat "$d/.claude/settings.json")
out=$(bash "$SC" "$d" guardrails --profile product 2>&1)
[ "$(cat "$d/.claude/settings.json")" = "$orig" ]; check "without --merge-settings: settings.json untouched" $?
grep -q 'proposed merge' <<<"$out"; check "without --merge-settings: diff is shown" $?
bash "$SC" "$d" guardrails --profile product --merge-settings >/dev/null 2>&1
S="$d/.claude/settings.json"
jq -e '.model == "opus"' "$S" >/dev/null; check "merge keeps user keys" $?
jq -e '.permissions.allow | index("Bash(make:*)")' "$S" >/dev/null; check "merge keeps user allow rules" $?
jq -e '.permissions.deny | index("Read(./private/**)") and index("Read(./.env)")' "$S" >/dev/null; check "merge unions deny rules" $?
jq -e '[.permissions.allow[] | select(. == "Bash(git status)")] | length == 1' "$S" >/dev/null; check "merge has no duplicate rules" $?
jq -e '[.hooks.Stop[].hooks[].command] | (index("echo mine") != null) and (map(test("verify.sh")) | any)' "$S" >/dev/null; check "merge keeps user Stop hook and adds verify.sh" $?
jq -e '.hooks.PreToolUse | length == 2' "$S" >/dev/null; check "merge adds both PreToolUse hooks" $?
before=$(cat "$S"); bash "$SC" "$d" guardrails --profile product --merge-settings >/dev/null 2>&1
[ "$before" = "$(cat "$S")" ]; check "second merge changes nothing" $?
echo '{bad' > "$S"; bash "$SC" "$d" guardrails --profile product --merge-settings >/dev/null 2>&1; [ $? -ne 0 ]; check "invalid settings.json fails loudly" $?

echo "Bad input"
bash "$SC" "$W/missing" files --profile product >/dev/null 2>&1; [ $? -ne 0 ]; check "missing dir fails" $?
bash "$SC" "$(newrepo)" files --profile enterprise >/dev/null 2>&1; [ $? -ne 0 ]; check "unknown profile fails" $?
bash "$SC" "$(newrepo)" everything --profile product >/dev/null 2>&1; [ $? -ne 0 ]; check "unknown phase fails" $?

echo "discover lock"
d=$(newrepo); mkdir -p "$d/docs"
lock() { jq -n --arg f "$1" '{tool_input:{file_path:$f}}' | CLAUDE_PROJECT_DIR="$d" "$LOCK" 2>/dev/null; echo $?; }
[ "$(lock "$d/src/a.ts")" = 0 ]; check "no intent.md: allows edits" $?
printf -- '---\nstatus: discovering\n---\n' > "$d/docs/intent.md"
[ "$(lock "$d/src/a.ts")" = 2 ]; check "discovering: blocks src edit" $?
[ "$(lock "$d/docs/intent.md")" = 0 ]; check "discovering: allows docs/intent.md" $?
[ "$(lock docs/intent.md)" = 0 ]; check "discovering: allows relative docs/intent.md" $?
printf -- '---\nstatus: decided\n---\n' > "$d/docs/intent.md"
[ "$(lock "$d/src/a.ts")" = 0 ]; check "decided: allows edits" $?
cp "$P/skills/discover/intent-template.md" "$d/docs/intent.md"
[ "$(lock "$d/src/a.ts")" = 2 ]; check "fresh template (status: discovering) locks" $?

echo
echo "Result: $pass passed, $fail failed"
[ $fail -eq 0 ]
