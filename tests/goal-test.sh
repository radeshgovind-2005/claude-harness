#!/usr/bin/env bash
# Tests scripts/goal.sh (state) and skills/goal/goal-stop.sh (the Stop hook) with the JSON Claude Code sends.
# Run from anywhere:  /bin/bash tests/goal-test.sh
# shellcheck disable=SC2319  # `[ test ]; check name $?` reads the test's status on purpose

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
P="$ROOT/plugins/dev-harness"
GS="$P/scripts/goal.sh"
HOOK="$P/skills/goal/goal-stop.sh"
pass=0; fail=0
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
export DEV_HARNESS_STATE_DIR="$W/state"
STATE="$DEV_HARNESS_STATE_DIR/goals"

check() { if [ "$2" = 0 ]; then echo "  PASS  $1"; pass=$((pass+1)); else echo "  FAIL  $1"; fail=$((fail+1)); fi; }
gs() { (cd "$PROJ" && bash "$GS" "$@" 2>&1); }
gsx() { (cd "$PROJ" && bash "$GS" "$@" >/dev/null 2>&1); echo $?; }
# hook SID: runs the Stop hook for session SID; sets HOUT (stderr+stdout) and HRC (exit code)
hook() {
  HOUT=$(jq -n --arg s "$1" '{session_id:$s, hook_event_name:"Stop", stop_hook_active:false}' \
    | (cd "$W" && CLAUDE_PLUGIN_ROOT="$P" CLAUDE_PROJECT_DIR="$PROJ" bash "$HOOK" 2>&1)); HRC=$?
}
sf() { echo "$STATE/$1.json"; }
jqf() { jq -r "$2" "$(sf "$1")"; }
newgoal() { # sid check [rounds] [minutes]
  PROJ=$(mktemp -d "$W/proj.XXXX"); gs start --session "$1" --check "$2" --rounds "${3:-3}" --minutes "${4:-30}" >/dev/null; }

echo "goal.sh start"
PROJ=$(mktemp -d "$W/proj.XXXX")
[ "$(gsx start --session s1 --check 'true')" = 0 ]; check "start with defaults" $?
[ -f "$(sf s1)" ]; check "state file is written under the state dir, not the project" $?
[ -z "$(ls -A "$PROJ")" ]; check "nothing is written into the project" $?
[ "$(jqf s1 .rounds_max)" = 10 ] && [ "$(jqf s1 .minutes_max)" = 30 ] && [ "$(jqf s1 .status)" = active ] && [ "$(jqf s1 .rounds)" = 0 ]; check "defaults: 10 rounds, 30 minutes, active, round 0" $?
[ "$(gsx start --session s1 --check 'true')" != 0 ]; check "a second start while active is refused" $?
[ "$(gsx start --session s1 --check 'echo two' --replace)" = 0 ] && [ "$(jqf s1 .check)" = "echo two" ]; check "--replace overwrites an active goal" $?
gs stop --session s1 --reason "done" >/dev/null; [ "$(gsx start --session s1 --check 'true')" = 0 ]; check "start after a finished goal is allowed" $?
[ "$(gsx start --session s2 --check $'a\nb')" != 0 ]; check "a multi-line check is rejected" $?
[ "$(gsx start --session s2 --check '')" != 0 ]; check "an empty check is rejected" $?
[ "$(gsx start --session s2 --check 'true' --rounds 0)" != 0 ] && [ "$(gsx start --session s2 --check 'true' --rounds 101)" != 0 ] && [ "$(gsx start --session s2 --check 'true' --rounds x)" != 0 ]; check "rounds must be 1..100" $?
[ "$(gsx start --session s2 --check 'true' --minutes 0)" != 0 ] && [ "$(gsx start --session s2 --check 'true' --minutes 721)" != 0 ]; check "minutes must be 1..720" $?
[ "$(gsx start --check 'true')" != 0 ]; check "a missing --session is rejected" $?
[ "$(gsx start --session '../x' --check 'true')" != 0 ]; check "a session id with path characters is rejected" $?
[ "$(gsx start --session s2 --check 'true' --bogus 1)" != 0 ]; check "an unknown option is rejected" $?
[ "$(gsx start --session s2 --check)" != 0 ]; check "an option without a value is rejected" $?
gs status --session s1 | grep -q 'rounds: 0 of 10'; check "status shows rounds" $?
gs status --session nosuch | grep -q 'no goal'; check "status of an unknown session says so" $?

echo "Stop hook: gated"
PROJ=$(mktemp -d "$W/proj.XXXX")
hook nosuch; [ "$HRC" = 0 ] && [ -z "$HOUT" ]; check "no state: allow, silent" $?
newgoal g1 'false' 3; hook other-session; [ "$HRC" = 0 ] && [ "$(jqf g1 .rounds)" = 0 ]; check "another session's stop does not touch this goal" $?
hook '../../etc/passwd'; [ "$HRC" = 0 ] && [ -z "$HOUT" ]; check "a session id with path characters is ignored" $?
echo '{}' | (cd "$W" && CLAUDE_PLUGIN_ROOT="$P" bash "$HOOK" >/dev/null 2>&1); [ $? = 0 ]; check "input without a session id: allow" $?
gs stop --session g1 --reason test >/dev/null; hook g1; [ "$HRC" = 0 ] && [ -z "$HOUT" ]; check "a stopped goal: allow, silent" $?

echo "Stop hook: check fails, budget left"
newgoal g2 'echo boom-output; exit 7' 3
hook g2
[ "$HRC" = 2 ]; check "a failing check blocks the stop (exit 2)" $?
grep -q 'GOAL NOT MET: round 1 of 3' <<<"$HOUT"; check "the reason names the round" $?
grep -q 'exited 7' <<<"$HOUT" && grep -q 'boom-output' <<<"$HOUT"; check "the reason has the exit code and the check output" $?
grep -q 'docs/progress.md' <<<"$HOUT" && grep -q 'checkpoint' <<<"$HOUT"; check "the reason asks for a checkpoint" $?
grep -q "goal.sh stop --session g2" <<<"$HOUT" && grep -q "$P/scripts/goal.sh" <<<"$HOUT"; check "the reason gives the real path to stop the goal" $?
! grep -q 'LAST ROUND' <<<"$HOUT"; check "round 1 of 3 is not flagged as the last" $?
[ "$(jqf g2 .rounds)" = 1 ] && [ "$(jqf g2 .status)" = active ]; check "state: round 1, still active" $?
hook g2; grep -q 'round 2 of 3' <<<"$HOUT" && grep -q 'LAST ROUND' <<<"$HOUT"; check "round 2 of 3 warns that it is the last" $?

echo "Stop hook: rounds budget"
hook g2
[ "$HRC" = 2 ] && grep -q 'GOAL BUDGET REACHED' <<<"$HOUT" && grep -q 'Do not claim the goal is done' <<<"$HOUT"; check "round 3 of 3: budget stop asks for an honest report" $?
[ "$(jqf g2 .status)" = reporting ] && [ "$(jqf g2 .outcome)" = budget ]; check "state: reporting, outcome budget" $?
hook g2; [ "$HRC" = 0 ]; check "after the report turn the stop is allowed" $?
[ "$(jqf g2 .status)" = finished ]; check "state: finished" $?
hook g2; [ "$HRC" = 0 ] && [ -z "$HOUT" ] && [ "$(jqf g2 .rounds)" = 3 ]; check "later stops in the session do nothing (no endless loop)" $?

echo "Stop hook: success"
newgoal g3 'test -f done.txt' 5
hook g3; [ "$HRC" = 2 ] && grep -q 'GOAL NOT MET' <<<"$HOUT"; check "check fails while done.txt is missing" $?
touch "$PROJ/done.txt"
hook g3; [ "$HRC" = 2 ] && grep -q 'GOAL MET after 2 round' <<<"$HOUT" && grep -q 'NOT verified' <<<"$HOUT"; check "check passes: block once to demand the final report" $?
[ "$(jqf g3 .outcome)" = met ] && [ "$(jqf g3 .status)" = reporting ]; check "state: reporting, outcome met" $?
hook g3; [ "$HRC" = 0 ]; check "the stop after the report is allowed" $?
rm "$PROJ/done.txt"; hook g3; [ "$HRC" = 0 ] && [ -z "$HOUT" ]; check "a finished goal does not restart when the check fails again" $?
newgoal g4 'true' 1
hook g4; grep -q 'GOAL MET' <<<"$HOUT"; check "success wins over the budget on the last round" $?
newgoal g5 'cd "$PWD" && pwd | grep -q proj' 2
(cd "$W" && jq -n '{session_id:"g5"}' | CLAUDE_PLUGIN_ROOT="$P" bash "$HOOK" >/dev/null 2>&1); [ "$(jqf g5 .outcome)" = met ]; check "the check runs in the goal's project dir, not the hook's cwd" $?

echo "Stop hook: minutes budget"
newgoal g6 'false' 10 1
tmp=$(mktemp); jq ".started = $(( $(date +%s) - 3600 ))" "$(sf g6)" > "$tmp" && mv "$tmp" "$(sf g6)"
hook g6; [ "$HRC" = 2 ] && grep -q 'GOAL BUDGET REACHED' <<<"$HOUT" && grep -q 'min' <<<"$HOUT"; check "time is up with rounds left: budget stop" $?
newgoal g7 'false' 10 600
hook g7; grep -q 'GOAL NOT MET' <<<"$HOUT"; check "time left: keep going" $?

echo "Stop hook: hostile or broken checks and state"
newgoal g8 'sleep 30; echo late' 3
start=$(date +%s); HOUT=$(jq -n '{session_id:"g8"}' | (cd "$W" && GOAL_CHECK_TIMEOUT=1 CLAUDE_PLUGIN_ROOT="$P" bash "$HOOK" 2>&1)); HRC=$?; el=$(( $(date +%s) - start ))
[ "$HRC" = 2 ] && grep -q 'timed out after 1s' <<<"$HOUT" && [ "$el" -lt 6 ]; check "a hung check is killed by the watchdog (${el}s)" $?
newgoal g9 "(sleep 3; touch $W/g9-orphan) & sleep 20" 3
(jq -n '{session_id:"g9"}' | (cd "$W" && GOAL_CHECK_TIMEOUT=1 CLAUDE_PLUGIN_ROOT="$P" bash "$HOOK" >/dev/null 2>&1)); sleep 4
[ ! -e "$W/g9-orphan" ]; check "the watchdog kills the check's whole process group" $?
newgoal g10 'cat; echo read-stdin-ok' 3
hook g10; grep -q 'GOAL MET' <<<"$HOUT"; check "a check that reads stdin does not hang the hook" $?
newgoal g11 'true' 3; echo 'not json {' > "$(sf g11)"
hook g11; [ "$HRC" = 0 ] && grep -q 'unreadable' <<<"$HOUT"; check "corrupt state: fail open with a message" $?
newgoal g12 'true' 3; jq '.rounds = "x"' "$(sf g12)" > "$W/t" && mv "$W/t" "$(sf g12)"
hook g12; [ "$HRC" = 0 ] && grep -q 'malformed' <<<"$HOUT"; check "malformed state: fail open with a message" $?
newgoal g13 'true' 3; jq '.check = ""' "$(sf g13)" > "$W/t" && mv "$W/t" "$(sf g13)"
hook g13; [ "$HRC" = 0 ] && grep -q 'malformed' <<<"$HOUT"; check "an empty check in the state: fail open, never 'met'" $?

echo "review fixes (v0.4.0 skeptic)"
newgoal r1 'head -c 300000 /dev/zero | tr "\\0" "x"; exit 1' 3
hook r1; [ "$HRC" = 2 ] && [ "${#HOUT}" -lt 6000 ]; check "a check that prints 300 KB on one line: the feedback stays small (${#HOUT} chars)" $?
newgoal r2 'printf "\033[31mRED\033[0m bell\007 nul-free\n"; exit 1' 3
hook r2; [ "$HRC" = 2 ] && grep -q 'RED' <<<"$HOUT" && ! grep -q "$(printf '\033')" <<<"$HOUT" && ! grep -q "$(printf '\007')" <<<"$HOUT"; check "escape and control characters are stripped from the feedback" $?
newgoal r3 'touch ran-here; exit 1' 3
projdir="$PROJ"; mkdir -p "$W/elsewhere"
jq --arg p "$W/does-not-exist" '.project = $p' "$(sf r3)" > "$W/t" && mv "$W/t" "$(sf r3)"
HOUT=$(jq -n '{session_id:"r3"}' | (cd "$W/elsewhere" && CLAUDE_PLUGIN_ROOT="$P" bash "$HOOK" 2>&1)); HRC=$?
[ "$HRC" = 0 ] && grep -q 'no longer exists' <<<"$HOUT" && [ ! -e "$W/elsewhere/ran-here" ]; check "a missing project folder: fail open, and the check is not run elsewhere" $?
[ -d "$projdir" ]; check "(setup) project dir existed" $?
start=$(date +%s); newgoal r4 'true' 3; GOAL_CHECK_TIMEOUT=777 hook r4; sleep 1
[ -z "$(pgrep -f 'sleep 777' || true)" ] && [ $(( $(date +%s) - start )) -lt 4 ]; check "no sleeping helper is left behind and a fast check returns fast" $?

echo "wiring"
sed -n '/^---$/,/^---$/p' "$P/skills/goal/SKILL.md" | grep -q 'goal-stop.sh'; check "the skill registers goal-stop.sh as a hook" $?
sed -n '/^---$/,/^---$/p' "$P/skills/goal/SKILL.md" | grep -q '^disable-model-invocation: true'; check "the skill is user-invoked only" $?
sed -n '/^---$/,/^---$/p' "$P/skills/goal/SKILL.md" | grep -q 'Stop:'; check "the hook is a Stop hook" $?
[ -x "$HOOK" ] && [ -x "$GS" ]; check "hook and goal.sh are executable" $?
al=$(sed -n 's/^allowed-tools:[[:space:]]*//p' "$P/skills/goal/SKILL.md")
! grep -Eq 'goal\.sh (\*|start)' <<<"$al" && grep -q 'goal.sh status' <<<"$al"; check "goal.sh start is not pre-approved (Claude Code asks, showing the check command)" $?

echo
echo "Result: $pass passed, $fail failed"
[ $fail -eq 0 ]
