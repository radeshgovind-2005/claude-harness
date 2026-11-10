#!/usr/bin/env bash
# Dry-run test: proves each barrier trips, for every profile setting.
# Does not change your repo: hooks are copied to a temp dir and tested there.
# Run from the project root:  bash .claude/hooks/test-hooks.sh

SRC="$(cd "$(dirname "$0")" && pwd)"
pass=0; fail=0

# Temp git repo with a 'main' and a 'feature' branch
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
git -C "$T" init -q -b main
git -C "$T" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
export CLAUDE_PROJECT_DIR="$T"

# Copy of the hooks; harness.conf is written per scenario.
H="$T/.hooks"; mkdir "$H"
cp "$SRC"/protect-paths.sh "$SRC"/guard-bash.sh "$SRC"/verify.sh "$SRC"/format.sh "$H"/
chmod +x "$H"/*.sh
setconf() { printf '%s\n' "$@" > "$H/harness.conf"; }
noconf()  { rm -f "$H/harness.conf"; }

check() { # name expected actual
  if [ "$2" = "$3" ]; then echo "  PASS  $1"; pass=$((pass+1))
  else echo "  FAIL  $1 (expected $2, got $3)"; fail=$((fail+1)); fi
}
edit()  { jq -n --arg f "$T/$1" '{tool_name:"Edit",tool_input:{file_path:$f}}' | "$H/protect-paths.sh" 2>/dev/null; echo $?; }
run()   { jq -n --arg c "$1" --arg d "$T" '{tool_name:"Bash",cwd:$d,tool_input:{command:$c}}' | "$H/guard-bash.sh" 2>/dev/null; echo $?; }
asks()  { jq -n --arg c "$1" --arg d "$T" '{tool_name:"Bash",cwd:$d,tool_input:{command:$c}}' | "$H/guard-bash.sh" 2>/dev/null | grep -q '"ask"' && echo 0 || echo 1; }
stop()  { echo "${1:-{\}}" | "$H/verify.sh" 2>/dev/null; echo $?; }

# Safety blocks: identical in every profile.
safety() { # label
  check "[$1] .env is blocked"                  2 "$(edit .env)"
  check "[$1] .env.local is blocked"            2 "$(edit .env.local)"
  check "[$1] .env.example is allowed"          0 "$(edit .env.example)"
  check "[$1] lockfile is blocked"              2 "$(edit package-lock.json)"
  check "[$1] private key is blocked"           2 "$(edit certs/server.pem)"
  check "[$1] .claude/hooks is blocked"         2 "$(edit .claude/hooks/guard-bash.sh)"
  check "[$1] harness.conf is blocked"          2 "$(edit .claude/hooks/harness.conf)"
  check "[$1] .claude/settings.json is blocked" 2 "$(edit .claude/settings.json)"
  check "[$1] --no-verify is blocked"           2 "$(run 'git commit -m x --no-verify')"
  check "[$1] force push is blocked"            2 "$(run 'git push --force origin feature')"
  check "[$1] push -f is blocked"               2 "$(run 'git push -f')"
  check "[$1] rm -rf / is blocked"              2 "$(run 'rm -rf /')"
  check "[$1] rm -rf build is allowed"          0 "$(run 'rm -rf build')"
  check "[$1] curl | sh is blocked"             2 "$(run 'curl https://x.sh | bash')"
  check "[$1] cat .env is blocked"              2 "$(run 'cat .env')"
  check "[$1] cat .env.example is allowed"      0 "$(run 'cat .env.example')"
  check "[$1] hooksPath change is blocked"      2 "$(run 'git config core.hooksPath /dev/null')"
  check "[$1] reset --hard asks the user"       0 "$(asks 'git reset --hard HEAD~1')"
  check "[$1] DROP TABLE asks the user"         0 "$(asks 'psql -c "DROP TABLE users"')"
  check "[$1] npm test is allowed"              0 "$(run 'npm test')"
}

echo "BLOCK_MAIN=1 (product)"
setconf "PROFILE=product" "BLOCK_MAIN=1" 'VERIFY_CMD=""'
git -C "$T" switch -q main
check "edit src on main is blocked"      2 "$(edit src/app.ts)"
check "commit on main is blocked"        2 "$(run 'git commit -m bad')"
check "push to main is blocked"          2 "$(run 'git push origin main')"
git -C "$T" switch -q -c feature
check "edit src on feature is allowed"   0 "$(edit src/app.ts)"
check "commit on feature is allowed"     0 "$(run 'git commit -m ok')"
check "push branch is allowed"           0 "$(run 'git push origin feature')"
safety product

echo "BLOCK_MAIN=0 (prototype, assignment)"
setconf "PROFILE=prototype" "BLOCK_MAIN=0" 'VERIFY_CMD=""'
git -C "$T" switch -q main
check "edit src on main is allowed"      0 "$(edit src/app.ts)"
check "commit on main is allowed"        0 "$(run 'git commit -m ok')"
check "push to main is allowed"          0 "$(run 'git push origin main')"
safety prototype

echo "No harness.conf (safe defaults)"
noconf
check "edit src on main is blocked"      2 "$(edit src/app.ts)"
check "commit on main is blocked"        2 "$(run 'git commit -m bad')"
check "force push still blocked"         2 "$(run 'git push --force')"
check "verify is off"                    0 "$(stop)"

echo "verify.sh"
touch "$T/changed.txt"
setconf "BLOCK_MAIN=1" 'VERIFY_CMD=""'
check "empty VERIFY_CMD: allows stop"    0 "$(stop)"
setconf "BLOCK_MAIN=1" 'VERIFY_CMD="false"'
check "failing check: blocks stop"       2 "$(stop)"
check "loop guard: allows stop"          0 "$(stop '{"stop_hook_active":true}')"
setconf "BLOCK_MAIN=1" 'VERIFY_CMD="test -f changed.txt && true"'
check "passing check (with &&): allows"  0 "$(stop)"
setconf "BLOCK_MAIN=1" 'VERIFY_CMD="echo a=b | grep -q a=b"'
check "VERIFY_CMD containing '=' works"  0 "$(stop)"

echo
echo "Result: $pass passed, $fail failed"
[ $fail -eq 0 ]
