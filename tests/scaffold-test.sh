#!/usr/bin/env bash
# Tests scripts/scaffold.sh and the discover lock against throwaway projects.
# Run from anywhere:  bash tests/scaffold-test.sh
# shellcheck disable=SC2319  # `[ test ]; check name $?` reads the test's status on purpose

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
P="$ROOT/plugins/dev-harness"
SC="$P/scripts/scaffold.sh"
LOCK="$P/skills/discover/discover-lock.sh"
TPL_LESSONS="$P/templates/project/docs/lessons.md"
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
  for h in harness-conf protect-paths guard-bash format verify test-hooks; do [ -x "$d/.claude/hooks/$h.sh" ]; check "hook $h.sh is executable" $?; done
  grep -q 'ok      hook tests: Result: [0-9]* passed, 0 failed' "$d.guard.log"; check "project hook tests ran and passed" $?
  [ "$(grep -c '{{' "$d/CLAUDE.md")" = 0 ]; check "CLAUDE.md has no unrendered {{markers}}" $?
  grep -q "^- Profile: $prof " "$d/CLAUDE.md"; check "CLAUDE.md names profile $prof" $?
  [ "$(wc -l < "$d/CLAUDE.md")" -lt 100 ]; check "CLAUDE.md under 100 lines" $?
  grep -q "^PROFILE=$prof$" "$d/.claude/hooks/harness.conf"; check "harness.conf PROFILE=$prof" $?
  jq empty "$d/.claude/settings.json"; check "settings.json is valid JSON" $?
  for h in protect-paths guard-bash verify; do
    jq -e --arg h "$h" '[.hooks[]?[]?.hooks[]?.command] | map(test($h + "\\.sh")) | any' "$d/.claude/settings.json" >/dev/null; check "settings.json registers $h.sh" $?
  done
  grep -qxF "CLAUDE.local.md" "$d/.gitignore"; check ".gitignore ignores CLAUDE.local.md" $?
  case $prof in
    product)
      [ "$(edit_on_main "$d")" = 2 ]; check "product: edit on main is blocked" $?
      grep -qx 'BLOCK_MAIN=1' "$d/.claude/hooks/harness.conf"; check "product: BLOCK_MAIN=1" $?
      jq -e '.permissions.ask | index("Bash(git push:*)")' "$d/.claude/settings.json" >/dev/null; check "product: git push asks" $?
      grep -q 'Never work on `main`' "$d/CLAUDE.md"; check "product: CLAUDE.md says never work on main" $?
      grep -qx 'VERIFY_CMD=""' "$d/.claude/hooks/harness.conf"; check "product: no stack, so VERIFY_CMD is empty (no npm default)" $?
      grep -q 'note    VERIFY_CMD is empty' "$d.guard.log"; check "product: an empty VERIFY_CMD is reported" $? ;;
    prototype)
      [ "$(edit_on_main "$d")" = 0 ]; check "prototype: edit on main is allowed" $?
      jq -e '.permissions.ask | index("Bash(git push:*)") | not' "$d/.claude/settings.json" >/dev/null; check "prototype: git push does not ask" $?
      grep -qx 'VERIFY_CMD=""' "$d/.claude/hooks/harness.conf"; check "prototype: verify off" $?
      ! grep -q 'Never work on `main`' "$d/CLAUDE.md"; check "prototype: CLAUDE.md does not forbid main" $? ;;
    assignment)
      [ "$(edit_on_main "$d")" = 0 ]; check "assignment: edit on main is allowed" $?
      grep -qi 'explain each step' "$d/CLAUDE.md"; check "assignment: CLAUDE.md asks to explain steps" $?
      grep -qx 'VERIFY_CMD=""' "$d/.claude/hooks/harness.conf"; check "assignment: no stack, so VERIFY_CMD is empty (no npm default)" $?
      grep -q 'note    VERIFY_CMD is empty' "$d.guard.log"; check "assignment: an empty VERIFY_CMD is reported" $? ;;
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

echo "Review fixes (v0.2.0 skeptic)"
# 1. a merge that fails must leave settings.json byte-identical
for bad in '{"permissions":{"allow":"Bash(ls)"}}' '{"hooks":{"PreToolUse":{"x":1}}}' '[]'; do
  d=$(newrepo); mkdir -p "$d/.claude"; printf '%s' "$bad" > "$d/.claude/settings.json"
  bash "$SC" "$d" guardrails --profile product --merge-settings >/dev/null 2>&1; st=$?
  [ $st -ne 0 ] && [ "$(cat "$d/.claude/settings.json")" = "$bad" ]; check "failed merge of $bad: FAIL and file unchanged" $?
done
# 2. verify cmd with backslashes and a literal \n is written verbatim and cannot inject lines
d=$(newrepo)
bash "$SC" "$d" guardrails --profile product --verify-cmd 'grep -rq "\.ts$" src && printf x\nBLOCK_MAIN=0' >/dev/null 2>&1
grep -qxF 'VERIFY_CMD="grep -rq "\.ts$" src && printf x\nBLOCK_MAIN=0"' "$d/.claude/hooks/harness.conf"; check "backslashes kept verbatim" $?
[ "$(grep -c '^BLOCK_MAIN=' "$d/.claude/hooks/harness.conf")" = 1 ] && grep -qx 'BLOCK_MAIN=1' "$d/.claude/hooks/harness.conf"; check "no injected BLOCK_MAIN line" $?
[ "$(edit_on_main "$d")" = 2 ]; check "product still blocks main after odd verify cmd" $?
bash "$SC" "$(newrepo)" guardrails --profile product --verify-cmd $'a\rb' >/dev/null 2>&1; [ $? -ne 0 ]; check "verify cmd with CR rejected" $?
# 8. .gitignore without a trailing newline
d=$(newrepo); printf 'node_modules' > "$d/.gitignore"
bash "$SC" "$d" files --profile prototype >/dev/null 2>&1
grep -qx 'node_modules' "$d/.gitignore" && grep -qx 'CLAUDE.local.md' "$d/.gitignore"; check ".gitignore last line kept intact" $?
# 10. option without a value fails fast (not an endless loop)
bash "$SC" "$(newrepo)" guardrails --profile product --verify-cmd >/dev/null 2>&1; [ $? -ne 0 ]; check "--verify-cmd without value fails" $?
bash "$SC" "$(newrepo)" files --profile >/dev/null 2>&1; [ $? -ne 0 ]; check "--profile without value fails" $?
# 12. a dangling symlink is not followed
d=$(newrepo); ln -s "$W/outside-target.md" "$d/CLAUDE.md"
bash "$SC" "$d" files --profile prototype >/dev/null 2>&1
[ ! -e "$W/outside-target.md" ]; check "dangling symlink not followed" $?
# 13. a skipped user hook keeps its mode
d=$(newrepo); mkdir -p "$d/.claude/hooks"; printf '# mine, reads harness.conf\n' > "$d/.claude/hooks/format.sh"; chmod 644 "$d/.claude/hooks/format.sh"
bash "$SC" "$d" guardrails --profile prototype >/dev/null 2>&1
[ ! -x "$d/.claude/hooks/format.sh" ]; check "skipped user hook not chmod-ed" $?
# 7. an older hook that ignores harness.conf is reported, not silently kept
d=$(newrepo); mkdir -p "$d/.claude/hooks"; printf '#!/usr/bin/env bash\nexit 0\n' > "$d/.claude/hooks/protect-paths.sh"
out=$(bash "$SC" "$d" guardrails --profile prototype 2>&1); st=$?
[ $st -ne 0 ] && grep -q 'does not read harness.conf' <<<"$out"; check "old hook without harness.conf support: FAIL" $?

echo "Parts (add <part>)"
# files_of DIR: sorted project files, excluding .git
files_of() { (cd "$1" && find . -path ./.git -prune -o -type f -print | sed 's|^\./||' | LC_ALL=C sort | tr '\n' ' '); }
part_files() { # part -> expected file set (space separated, sorted, trailing space)
  case "$1" in
    lessons) echo "docs/lessons.md " ;;
    reviewer) echo "docs/agents/INDEX.md " ;;
    workflows) echo "docs/agents/first-workflow.md docs/audits/README.md docs/workflow.md " ;;
    rules) echo ".claude/rules/example-api.md " ;;
    memory) echo ".gitignore CLAUDE.md docs/INDEX.md docs/architecture.md docs/conventions.md docs/experiments.md docs/lessons.md docs/progress.md " ;;
  esac; }
for part in lessons reviewer workflows rules memory; do
  d=$(newrepo)
  bash "$SC" "$d" files --part "$part" --profile product >/dev/null 2>&1; check "$part: exits 0" $?
  [ "$(files_of "$d")" = "$(part_files "$part")" ]; check "$part: writes exactly its files" $?
  before=$(snapshot "$d")
  out=$(bash "$SC" "$d" files --part "$part" --profile product 2>&1)
  ! grep -Eq '^  (add|merge|update|FAIL) ' <<<"$out" && [ "$before" = "$(snapshot "$d")" ]; check "$part: second run only skips" $?
  d=$(newrepo); before=$(snapshot "$d")
  bash "$SC" "$d" files --part "$part" --profile product --dry-run >/dev/null 2>&1
  [ "$before" = "$(snapshot "$d")" ]; check "$part: dry run writes nothing" $?
done
for part in lessons reviewer workflows rules; do
  bash "$SC" "$(newrepo)" files --part "$part" >/dev/null 2>&1; check "$part: needs no --profile" $?
done
bash "$SC" "$(newrepo)" files --part memory >/dev/null 2>&1; [ $? -ne 0 ]; check "memory: needs --profile (CLAUDE.md is rendered)" $?
bash "$SC" "$(newrepo)" files --part bogus --profile product >/dev/null 2>&1; [ $? -ne 0 ]; check "unknown part fails" $?
bash "$SC" "$(newrepo)" guardrails --part rules --profile product >/dev/null 2>&1; [ $? -ne 0 ]; check "--part with guardrails phase fails" $?
bash "$SC" "$(newrepo)" files --part >/dev/null 2>&1; [ $? -ne 0 ]; check "--part without value fails" $?
bash "$SC" "$(newrepo)" files --part lessons --profile enterprise >/dev/null 2>&1; [ $? -ne 0 ]; check "a bad --profile still fails when given to a part that does not need it" $?
# existing user files survive a part run
d=$(newrepo); mkdir -p "$d/docs"; echo "mine" > "$d/docs/lessons.md"; echo "my rules" > "$d/CLAUDE.md"
bash "$SC" "$d" files --part memory --profile product >/dev/null 2>&1
[ "$(cat "$d/docs/lessons.md")" = "mine" ] && [ "$(cat "$d/CLAUDE.md")" = "my rules" ]; check "memory: existing CLAUDE.md and lessons.md untouched" $?
# add all == new: the parts together equal the full files phase, plus guardrails
d1=$(newrepo); d2=$(newrepo)
bash "$SC" "$d1" files --profile product >/dev/null 2>&1; bash "$SC" "$d1" guardrails --profile product >/dev/null 2>&1
for part in memory lessons reviewer workflows rules; do bash "$SC" "$d2" files --part "$part" --profile product >/dev/null 2>&1; done
bash "$SC" "$d2" guardrails --profile product >/dev/null 2>&1
[ "$(snapshot "$d1")" = "$(snapshot "$d2")" ]; check "all parts + guardrails == files + guardrails" $?
# routing and naming in the rendered CLAUDE.md
for prof in prototype product assignment; do
  d=$(newrepo); bash "$SC" "$d" files --profile "$prof" >/dev/null 2>&1
  grep -q 'docs/progress.md' "$d/CLAUDE.md" && grep -q 'docs/experiments.md' "$d/CLAUDE.md"; check "$prof: CLAUDE.md routes progress.md and experiments.md" $?
  grep -q 'dev-harness:skeptic' "$d/CLAUDE.md" && grep -q 'dev-harness:skeptic' "$d/docs/agents/INDEX.md"; check "$prof: CLAUDE.md and agents/INDEX.md name dev-harness:skeptic" $?
  ra=0; for a in skeptic lens-reviewer architect designer tester; do grep -q "dev-harness:$a" "$d/docs/agents/INDEX.md" || ra=1; done
  [ $ra = 0 ]; check "$prof: docs/agents/INDEX.md names all five plugin agents" $?
  stale=0; for f in CLAUDE.md docs/agents/INDEX.md docs/lessons.md docs/progress.md docs/experiments.md; do
    [ -f "$d/$f" ] || stale=1; ! grep -q 'from v0\.' "$d/$f" || stale=1; done
  [ $stale = 0 ]; check "$prof: rendered templates exist and have no stale 'from v0.x'" $?
  grep -q '`progress.md`' "$d/docs/INDEX.md"; check "$prof: docs/INDEX.md lists progress.md" $?
  grep -q '`experiments.md`' "$d/docs/INDEX.md"; check "$prof: docs/INDEX.md lists experiments.md" $?
done

bash "$SC" "$(newrepo)" files --part "" --profile product >/dev/null 2>&1; [ $? -ne 0 ]; check "empty --part value fails (not 'all parts')" $?
# memory routes to files other parts own: it must say so; the full files phase must not
d=$(newrepo); out=$(bash "$SC" "$d" files --part memory --profile product 2>&1)
grep -q 'note .*docs/workflow.md.*add workflows' <<<"$out" && grep -q 'note .*docs/audits/README.md.*add workflows' <<<"$out" && grep -q 'note .*docs/agents/INDEX.md.*add reviewer' <<<"$out"; check "memory: names the routed files it did not write" $?
out=$(bash "$SC" "$d" files --part workflows 2>&1; bash "$SC" "$d" files --part reviewer 2>&1; bash "$SC" "$d" files --part memory --profile product 2>&1)
! grep -q '^  note ' <<<"$out"; check "memory: no note once workflows and reviewer exist" $?
out=$(bash "$SC" "$(newrepo)" files --profile product 2>&1); ! grep -q '^  note ' <<<"$out"; check "full files phase prints no note" $?
# .gitignore: the files phase adds both personal files; guardrails alone adds the settings one
d=$(newrepo); bash "$SC" "$d" files --profile prototype >/dev/null 2>&1
grep -qxF ".claude/settings.local.json" "$d/.gitignore" && grep -qxF "CLAUDE.local.md" "$d/.gitignore"; check "files phase ignores both personal files" $?
d=$(newrepo); bash "$SC" "$d" guardrails --profile prototype >/dev/null 2>&1
grep -qxF ".claude/settings.local.json" "$d/.gitignore"; check "guardrails alone ignores .claude/settings.local.json" $?
d=$(newrepo); bash "$SC" "$d" files --part lessons >/dev/null 2>&1
[ ! -e "$d/.gitignore" ]; check "lessons part does not touch .gitignore" $?
# the [discover] tag has to agree across the lesson skill, the discover skill and the template
for f in "$P/skills/lesson/SKILL.md" "$P/skills/discover/SKILL.md" "$TPL_LESSONS"; do
  grep -qF '[discover]' "$f"; check "[discover] tag named in ${f#"$P"/}" $?
done


echo "VERIFY_CMD detection (no --verify-cmd)"
# vd PROFILE SETUP...: scaffold guardrails into a repo prepared by SETUP (eval'd in it), print VERIFY_CMD.
vd() { local prof="$1" d; shift; d=$(newrepo); (cd "$d" && eval "$*"); bash "$SC" "$d" guardrails --profile "$prof" >"$d.log" 2>&1
  bash "$d/.claude/hooks/harness-conf.sh" VERIFY_CMD "<missing>"; }
PJ='{"scripts":{"typecheck":"tsc --noEmit","lint":"eslint .","test":"vitest run"}}'
[ "$(vd product "printf '%s' '$PJ' > package.json")" = "npm run typecheck && npm run lint" ]; check "product + package.json: typecheck && lint" $?
[ "$(vd product "printf '%s' '{\"scripts\":{\"lint\":\"eslint .\"}}' > package.json")" = "npm run lint" ]; check "product + package.json: only the scripts that exist" $?
[ "$(vd product "printf '%s' '$PJ' > package.json; touch pnpm-lock.yaml")" = "pnpm run typecheck && pnpm run lint" ]; check "product + pnpm lockfile: pnpm run" $?
[ "$(vd assignment "printf '%s' '$PJ' > package.json")" = "npm test" ]; check "assignment + package.json test script: npm test" $?
[ "$(vd assignment "printf '%s' '{\"scripts\":{\"test\":\"echo \\\"Error: no test specified\\\" && exit 1\"}}' > package.json")" = "" ]; check "assignment: the npm init placeholder test is not chosen" $?
[ "$(vd assignment "printf 'test:\n\tpytest\n' > Makefile")" = "make test" ]; check "assignment + Makefile test target: make test" $?
[ "$(vd product "printf 'lint:\n\truff .\n' > Makefile")" = "make lint" ]; check "product + Makefile lint target: make lint" $?
[ "$(vd assignment "touch Cargo.toml")" = "cargo test" ]; check "assignment + Cargo.toml: cargo test" $?
[ "$(vd product "touch go.mod")" = "go vet ./..." ]; check "product + go.mod: go vet" $?
[ "$(vd assignment "touch pyproject.toml")" = "python3 -m pytest -q" ]; check "assignment + pyproject.toml: pytest" $?
[ "$(vd product "printf '[tool.ruff]\n[tool.mypy]\n' > pyproject.toml")" = "ruff check . && mypy ." ]; check "product + pyproject ruff and mypy" $?
[ "$(vd product "touch pyproject.toml")" = "" ]; check "product + plain pyproject: empty (no guess)" $?
[ "$(vd prototype "printf '%s' '$PJ' > package.json")" = "" ]; check "prototype: never detected (verify off)" $?
d=$(newrepo); printf '%s' "$PJ" > "$d/package.json"; bash "$SC" "$d" guardrails --profile assignment --verify-cmd 'make check' >/dev/null 2>&1
[ "$(bash "$d/.claude/hooks/harness-conf.sh" VERIFY_CMD x)" = "make check" ]; check "--verify-cmd wins over detection" $?
d=$(newrepo); printf '%s' "$PJ" > "$d/package.json"; out=$(bash "$SC" "$d" guardrails --profile product 2>&1)
grep -q '^  note    VERIFY_CMD detected: npm run typecheck && npm run lint' <<<"$out"; check "a detected VERIFY_CMD is reported as a note" $?

echo "The CI profile check reads harness.conf like the hooks"
d=$(newrepo); bash "$SC" "$d" guardrails --profile product >/dev/null 2>&1
YML="$d/.github/workflows/dev-harness-hooks.yml"
# The run: block of the step, de-indented, exactly as CI runs it.
awk '/- name: harness.conf matches its profile/ {f=1; next} f && /^      - name:/ {exit} f && /^        run: \|/ {r=1; next} r {sub(/^          /, ""); print}' "$YML" > "$W/ci-step.sh"
grep -q 'harness-conf.sh' "$W/ci-step.sh"; check "the CI step was extracted and uses harness-conf.sh" $?
ci() { (cd "$d" && bash "$W/ci-step.sh" >/dev/null 2>&1); echo $?; }   # 0 = CI passes
for v in 'BLOCK_MAIN="0"' 'BLOCK_MAIN=0' ' BLOCK_MAIN = 0 ' $'BLOCK_MAIN=0\r' $'BLOCK_MAIN=1\nBLOCK_MAIN=0' \
         'BLOCK_MAIN=1' 'BLOCK_MAIN="1"' 'BLOCK_MAIN=true' 'BLOCK_MAIN=' '# BLOCK_MAIN missing'; do
  for pl in 'PROFILE=product' 'PROFILE="product"' ' PROFILE = product'; do
    printf '%s\n%s\n' "$pl" "$v" > "$d/.claude/hooks/harness.conf"
    c=$(ci); e=$(edit_on_main "$d")
    # CI must fail exactly when the product project's own hook lets an edit on main through.
    { [ "$c" != 0 ] && [ "$e" = 0 ]; } || { [ "$c" = 0 ] && [ "$e" = 2 ]; }
    check "CI and hooks agree on [$pl | $(printf '%s' "$v" | tr '\r\n' '^|')] (ci=$c hook=$e)" $?
  done
done
printf 'PROFILE=product\nBLOCK_MAIN="0"\n' > "$d/.claude/hooks/harness.conf"; [ "$(ci)" != 0 ]; check 'CI fails: product with BLOCK_MAIN="0"' $?
mv "$d/.claude/hooks/harness-conf.sh" "$d/hc.off"; printf 'PROFILE=product\nBLOCK_MAIN=1\n' > "$d/.claude/hooks/harness.conf"
[ "$(ci)" != 0 ]; check "CI fails when harness-conf.sh is missing" $?

echo "Upgrade: 1.0.1 hooks stay, the parser is added"
d=$(newrepo); mkdir -p "$d/.claude/hooks"
for h in protect-paths guard-bash verify format test-hooks; do   # every hook file a 1.0.1 project has
  git -C "$ROOT" show "v1.0.1:plugins/dev-harness/templates/project/.claude/hooks/$h.sh" > "$d/.claude/hooks/$h.sh" 2>/dev/null; chmod +x "$d/.claude/hooks/$h.sh"
done
if [ -s "$d/.claude/hooks/protect-paths.sh" ]; then
  out=$(bash "$SC" "$d" guardrails --profile product 2>&1); st=$?
  grep -q '^  skip    .claude/hooks/protect-paths.sh' <<<"$out" && grep -q '^  add     .claude/hooks/harness-conf.sh' <<<"$out"; check "upgrade: old hooks skipped, harness-conf.sh added" $?
  [ "$(edit_on_main "$d")" = 2 ]; check "upgrade: the 1.0.1 protect-paths.sh still blocks main" $?
  [ $st = 0 ]; check "upgrade: scaffold and the new hook tests pass over the old hooks" $?
else
  echo "  SKIP  upgrade from v1.0.1 (tag not in this clone)"
fi


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
