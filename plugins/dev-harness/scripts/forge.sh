#!/usr/bin/env bash
# dev-harness forge: the quality bar for new parts (hooks, skills, agents, path-scoped rules). Code
# enforces, text advises: a part with a soft spec or tests that do not test it is not created.
#
# Usage:
#   forge.sh check   <part-dir>                       spec complete, files fit the type, tests pass, and at
#                                                     least one test FAILS when the part's files are emptied
#   forge.sh install <part-dir> [--project D]         check, then install into the project (never overwrites)
#   forge.sh use     <name> [--project D]             count one real successful use (uses += 1)
#   forge.sh status  <name> proven|experimental [--project D]   proven needs uses >= 3 and a passing check
#   forge.sh list    [--project D]                    the registry docs/parts.md, checked against the parts
#   forge.sh promote <name> --to <marketplace-clone> --plugin <plugin> [--project D]
#                                                     proven parts only: branch promote/<name> in the clone and
#                                                     copy the part there (nothing is committed or pushed)
#
# A part is a folder: spec.md, files/ (what is installed), tests/ (executable *.sh; each must exit 0).
# Tests run from a copy of the part folder, with PART_DIR and FILES_DIR set. Staging in a project is
# .claude/forge/<name>/. The spec form is skills/forge/part-spec.md.
# Installed to: hook -> .claude/hooks/<name>.sh + .claude/settings.json; skill -> .claude/skills/<name>/;
# agent -> .claude/agents/<name>.md; rule -> .claude/rules/<name>.md. Registry: docs/parts.md.
# install, status and promote change guarded files: the project's guard-bash.sh asks the user first.
# Output: PASS|WARN|FAIL lines, then SUMMARY. Exit 1 on any FAIL. FORGE_TEST_TIMEOUT: seconds per test (300).

# -h / --help prints the comment block at the top of this file (the usage).
case "${1:-}" in -h|--help) sed -n -E '2,/^([^#]|$)/{/^#/s/^# ?//p;}' "$0"; exit 0 ;; esac

set -u
PLUGIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
. "$PLUGIN/scripts/lib.sh"
TEST_TIMEOUT="${FORGE_TEST_TIMEOUT:-300}"
SECTIONS="Purpose|Which type and why|Trigger|Inputs and outputs|Method or loop|Unacceptable|Success check|Tests|Budget"
EVENTS=" PreToolUse PostToolUse UserPromptSubmit Stop SubagentStop SessionStart SessionEnd PreCompact PostCompact Notification "

p=0; w=0; f=0
say() { printf '%-5s %s — %s\n' "$1" "$2" "$3"; case "$1" in PASS) p=$((p+1)) ;; WARN) w=$((w+1)) ;; FAIL) f=$((f+1)) ;; esac; }
summary() { echo "SUMMARY pass=$p warn=$w fail=$f"; [ "$f" -eq 0 ]; }
die() { echo "FAIL    $*" >&2; exit 1; }

fm() { # FILE KEY: frontmatter value, trimmed, CR dropped
  tr -d '\r' < "$1" | awk -v k="$2" 'NR==1 && $0!="---" {exit} NR>1 && /^---[[:space:]]*$/ {exit}
    NR>1 { i=index($0, ":"); if (i && substr($0,1,i-1)==k) { v=substr($0,i+1); sub(/^[[:space:]]+/,"",v); sub(/[[:space:]]+$/,"",v); print v; exit } }'
}
has_fm_key() { tr -d '\r' < "$1" | awk -v k="$2" 'NR==1 && $0!="---" {exit 1} NR>1 && /^---[[:space:]]*$/ {exit 1} NR>1 && index($0, k ":")==1 {f=1; exit} END {exit !f}'; }
section() { # FILE NAME: body of "## NAME" without comments and blank lines
  tr -d '\r' < "$1" | awk -v n="## $2" '$0==n {on=1; next} on && /^## / {exit} on {print}' \
    | sed -e 's/<!--.*-->//g' | grep -v '^[[:space:]]*$'
}
setfm() { # FILE KEY VALUE: replace a frontmatter line in place
  local tmp; tmp=$(mktemp) || return 1
  awk -v k="$2" -v v="$3" 'NR==1 {print; next} !e && /^---/ {e=1} !e && index($0, k ":")==1 {print k ": " v; next} {print}' "$1" > "$tmp" \
    && cat "$tmp" > "$1"; rm -f "$tmp"
}

# --- check -----------------------------------------------------------------------------------------
# run_tests DIR: runs every tests/*.sh of the part folder DIR (a copy); prints "name rc" lines.
run_tests() {
  local d="$1" t
  for t in "$d"/tests/*.sh; do
    [ -f "$t" ] || continue
    run_limited "$TEST_TIMEOUT" "cd \"$d\" && PART_DIR=\"$d\" FILES_DIR=\"$d/files\" bash \"$t\""
    printf '%s\n' "$RUN_OUT" > "$d/.forge-out-$(basename "$t")"
    if [ "$RUN_TIMED_OUT" = 1 ]; then echo "$(basename "$t") timeout"; else echo "$(basename "$t") $RUN_RC"; fi
  done
}

do_check() { # DIR -> say lines; sets TYPE NAME
  local d="$1" s v name type status uses bad="" n tmpd res failing ev tm
  [ -d "$d" ] || die "part folder not found: $d"
  s="$d/spec.md"
  if [ ! -f "$s" ]; then say FAIL "spec" "$d has no spec.md: no spec, no part (template: skills/forge/part-spec.md)"; return; fi
  name=$(fm "$s" name); type=$(fm "$s" type); status=$(fm "$s" status); uses=$(fm "$s" uses)
  NAME="$name"; TYPE="$type"
  [[ "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || bad="$bad name(kebab-case)"
  case "$type" in hook|skill|agent|rule) ;; *) bad="$bad type(hook|skill|agent|rule)" ;; esac
  case "$status" in experimental|proven) ;; *) bad="$bad status(experimental|proven)" ;; esac
  [[ "$uses" =~ ^[0-9]+$ ]] || bad="$bad uses(a whole number)"
  if [ "$type" = hook ]; then
    ev=$(fm "$s" event); tm=$(fm "$s" timeout)
    case "$EVENTS" in *" $ev "*) ;; *) bad="$bad event(a hook event such as PreToolUse or Stop)" ;; esac
    has_fm_key "$s" matcher || bad="$bad matcher(may be empty, but the key must be there)"
    [[ "$tm" =~ ^[0-9]+$ ]] || bad="$bad timeout(seconds)"
  fi
  if [ -n "$bad" ]; then say FAIL "spec frontmatter" "missing or invalid:$bad"; else say PASS "spec frontmatter" "$name ($type, $status, uses $uses)"; fi
  bad=""
  IFS='|' read -ra secs <<<"$SECTIONS"
  for v in "${secs[@]}"; do
    body=$(section "$s" "$v")
    if [ -z "$body" ] || grep -Eq '^[-[:space:]]*<[^<>]*>[[:space:]]*$' <<<"$body"; then bad="$bad '$v'"; fi
  done
  b=$(section "$s" Budget | head -n 1)
  if grep -Eqi '^[-[:space:]]*n/?a[[:space:].]*$' <<<"$b"; then bad="$bad 'Budget'(n/a needs a reason: n/a — not a loop)"; fi
  if [ -n "$bad" ]; then say FAIL "spec sections" "empty or placeholder:$bad"; else say PASS "spec sections" "all ${#secs[@]} filled"; fi
  if [ "$status" = proven ] && [[ "$uses" =~ ^[0-9]+$ ]] && [ "$uses" -lt 3 ]; then
    say FAIL "status" "proven needs at least 3 real successful uses (uses: $uses). Count them with: forge.sh use $name"
  fi

  # files/ fit the type
  if [ ! -d "$d/files" ]; then say FAIL "files" "no files/ folder (what is installed)"
  else
    case "$type" in
      hook)
        n=$(find "$d/files" -maxdepth 1 -name '*.sh' | wc -l | tr -d ' ')
        if [ "$n" != 1 ]; then say FAIL "files" "a hook part has exactly one files/*.sh (found $n)"
        elif [ ! -x "$(find "$d/files" -maxdepth 1 -name '*.sh')" ]; then say FAIL "files" "files/*.sh is not executable"
        else say PASS "files" "one executable hook script"; fi ;;
      skill)
        if [ ! -f "$d/files/SKILL.md" ]; then say FAIL "files" "a skill part needs files/SKILL.md"
        elif [ "$(fm "$d/files/SKILL.md" name)" != "$name" ] || [ -z "$(fm "$d/files/SKILL.md" description)" ]; then
          say FAIL "files" "files/SKILL.md needs name: $name and a description"
        else say PASS "files" "SKILL.md with name and description"; fi ;;
      agent)
        v="$d/files/$name.md"
        if [ ! -f "$v" ]; then say FAIL "files" "an agent part needs files/$name.md"
        elif [ -z "$(fm "$v" tools)" ] || [ -z "$(fm "$v" description)" ]; then say FAIL "files" "files/$name.md needs tools: (listed explicitly) and a description"
        elif grep -Eqi '(^|[ ,])(Edit|Write|MultiEdit|NotebookEdit)([ ,(]|$)' <<<"$(fm "$v" tools)"; then say FAIL "files" "an agent gets no edit tool (tools: $(fm "$v" tools))"
        else say PASS "files" "agent with an explicit, read-only tools list"; fi ;;
      rule)
        v="$d/files/$name.md"
        if [ ! -f "$v" ]; then say FAIL "files" "a rule part needs files/$name.md"
        elif ! has_fm_key "$v" paths; then say FAIL "files" "files/$name.md needs paths: in its frontmatter (a rule for one folder or file type)"
        else say PASS "files" "rule with paths:"; fi ;;
      *) say FAIL "files" "unknown type, files not checked" ;;
    esac
  fi

  # tests exist, pass, and fail without the part
  n=$(find "$d/tests" -maxdepth 1 -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')
  if [ "$n" = 0 ]; then say FAIL "tests" "no tests/*.sh: no tests, no part"; return; fi
  tmpd=$(mktemp -d "${TMPDIR:-/tmp}/dh-forge.XXXXXX") || die "mktemp failed"
  cp -RL "$d/." "$tmpd/" 2>/dev/null || { rm -rf "$tmpd"; die "could not copy $d"; }
  res=$(run_tests "$tmpd")
  failing=$(awk '$2 != 0 {print $1 " (" $2 ")"}' <<<"$res" | tr '\n' ' ')
  if [ -n "$failing" ]; then
    say FAIL "tests" "$n test(s); failing: $failing"
    for v in $(awk '$2 != 0 {print $1}' <<<"$res"); do echo "      --- $v (last 10 lines)"; tail -n 10 "$tmpd/.forge-out-$v" | sed 's/^/      | /'; done
  else say PASS "tests" "$n test(s) pass"; fi
  rm -rf "$tmpd"
  if [ -z "$failing" ] && [ -d "$d/files" ]; then
    tmpd=$(mktemp -d "${TMPDIR:-/tmp}/dh-forge.XXXXXX") || die "mktemp failed"
    cp -RL "$d/." "$tmpd/" 2>/dev/null
    find "$tmpd/files" -type f -exec sh -c ': > "$1"' _ {} \;
    res=$(run_tests "$tmpd")
    if awk '$2 != 0 {f=1} END {exit !f}' <<<"$res"; then say PASS "tests fail without the part" "with files/ emptied, a test fails"
    else say FAIL "tests fail without the part" "every test still passes with files/ emptied: the tests do not test the part"; fi
    rm -rf "$tmpd"
  fi
}

# --- project, registry -----------------------------------------------------------------------------
project_root() { # [--project D] already parsed into PROJ
  local r="${PROJ:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
  (cd "$r" 2>/dev/null && pwd) || die "project dir not found: $r"
}
target_of() { # TYPE NAME -> path relative to the project
  case "$1" in hook) echo ".claude/hooks/$2.sh" ;; skill) echo ".claude/skills/$2" ;; agent) echo ".claude/agents/$2.md" ;; rule) echo ".claude/rules/$2.md" ;; esac
}
registry_rows() { # ROOT
  local r="$1" s n
  echo "| part | type | status | uses | installed | spec |"
  echo "|---|---|---|---|---|---|"
  for s in "$r"/.claude/forge/*/spec.md; do
    [ -f "$s" ] || continue
    n=$(fm "$s" name)
    printf '| %s | %s | %s | %s | %s | `.claude/forge/%s/spec.md` |\n' "$n" "$(fm "$s" type)" "$(fm "$s" status)" "$(fm "$s" uses)" \
      "$([ -e "$r/$(target_of "$(fm "$s" type)" "$n")" ] && echo yes || echo no)" "$(basename "$(dirname "$s")")"
  done
}
registry_block() { tr -d '\r' < "$1/docs/parts.md" | awk '/<!-- parts:index:end -->/ {on=0} on {print} /<!-- parts:index:start -->/ {on=1}'; }
write_registry() { # ROOT
  local r="$1" reg="$1/docs/parts.md" tmp
  if [ ! -f "$reg" ]; then mkdir -p "$r/docs" && cp "$PLUGIN/templates/project/docs/parts.md" "$reg" || die "could not create $reg"; fi
  grep -q '<!-- parts:index:start -->' "$reg" && grep -q '<!-- parts:index:end -->' "$reg" || die "$reg has no parts:index markers"
  tmp=$(mktemp) || die "mktemp failed"
  registry_rows "$r" > "$tmp.rows"
  awk -v rows="$tmp.rows" '/<!-- parts:index:start -->/ {print; while ((getline l < rows) > 0) print l; skip=1; next}
    /<!-- parts:index:end -->/ {skip=0} !skip {print}' "$reg" > "$tmp" && cat "$tmp" > "$reg"
  rm -f "$tmp" "$tmp.rows"
}
staged() { # ROOT NAME -> spec path or die
  [[ "$2" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || die "not a part name: '$2'"
  [ -f "$1/.claude/forge/$2/spec.md" ] || die "no part '$2' in .claude/forge/ (install it first)"
  printf '%s' "$1/.claude/forge/$2/spec.md"
}

# --- commands --------------------------------------------------------------------------------------
cmd="${1:-}"; [ $# -gt 0 ] && shift
PROJ=""; TO=""; PLUG=""; ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --project|--to|--plugin) [ $# -ge 2 ] || die "$1 needs a value" ;;
  esac
  case "$1" in
    --project) PROJ="$2"; shift 2 ;; --to) TO="$2"; shift 2 ;; --plugin) PLUG="$2"; shift 2 ;;
    *) ARGS+=("$1"); shift ;;
  esac
done

case "$cmd" in
  check)
    [ -n "${ARGS[0]:-}" ] || die "check needs a part folder"
    do_check "${ARGS[0]}"
    summary ;;

  install)
    [ -n "${ARGS[0]:-}" ] || die "install needs a part folder"
    src="$(cd "${ARGS[0]}" 2>/dev/null && pwd)" || die "part folder not found: ${ARGS[0]}"
    do_check "$src"
    [ "$f" -eq 0 ] || { summary; die "the part does not pass check: nothing was installed"; }
    R=$(project_root); name="$NAME"; type="$TYPE"; tgt=$(target_of "$type" "$name")
    [ -e "$R/$tgt" ] || [ -L "$R/$tgt" ] && die "$tgt already exists: forge never overwrites. Compare it with $src/files, then move it aside yourself if the new part should replace it"
    stage="$R/.claude/forge/$name"
    if [ "$src" != "$stage" ]; then
      [ -e "$stage" ] && die ".claude/forge/$name already exists (another part with this name)"
      mkdir -p "$R/.claude/forge" && cp -RL "$src" "$stage" || die "could not stage the part in $stage"
      say PASS "staged" ".claude/forge/$name (spec, files, tests stay here)"
    fi
    case "$type" in
      hook)
        mkdir -p "$R/.claude/hooks"
        cp "$(find "$stage/files" -maxdepth 1 -name '*.sh')" "$R/$tgt" && chmod +x "$R/$tgt" || die "could not copy the hook"
        S="$R/.claude/settings.json"
        [ -f "$S" ] || printf '{}\n' > "$S"
        jq empty "$S" 2>/dev/null || die ".claude/settings.json is not valid JSON; fix it first (the hook file was copied, not registered)"
        ev=$(fm "$stage/spec.md" event); mt=$(fm "$stage/spec.md" matcher); tm=$(fm "$stage/spec.md" timeout)
        c="\"\$CLAUDE_PROJECT_DIR\"/$tgt"
        tmp=$(mktemp) || die "mktemp failed"
        jq --arg ev "$ev" --arg mt "$mt" --arg c "$c" --argjson tm "$tm" '
          .hooks //= {} | .hooks[$ev] //= []
          | if ([.hooks[$ev][]?.hooks[]?.command] | index($c)) then .
            else .hooks[$ev] += [ (if $mt == "" then {} else {matcher: $mt} end) + {hooks: [{type: "command", command: $c, timeout: $tm}]} ] end' \
          "$S" > "$tmp" && jq empty "$tmp" && cat "$tmp" > "$S" || { rm -f "$tmp"; die "could not register the hook in .claude/settings.json"; }
        rm -f "$tmp"
        say PASS "installed" "$tgt, registered for $ev${mt:+ ($mt)} in .claude/settings.json" ;;
      skill) mkdir -p "$R/$tgt" && cp -RL "$stage/files/." "$R/$tgt/" || die "could not install the skill"; say PASS "installed" "$tgt/ (as /$name)" ;;
      agent|rule) mkdir -p "$(dirname "$R/$tgt")" && cp "$stage/files/$name.md" "$R/$tgt" || die "could not install"; say PASS "installed" "$tgt" ;;
    esac
    write_registry "$R"; say PASS "registry" "docs/parts.md"
    summary ;;

  use)
    R=$(project_root); s=$(staged "$R" "${ARGS[0]:-}") || exit 1
    [ -e "$R/$(target_of "$(fm "$s" type)" "${ARGS[0]}")" ] || die "${ARGS[0]} is not installed: only an installed part can have a real use"
    n=$(fm "$s" uses); setfm "$s" uses $((n + 1)) || die "could not update $s"
    write_registry "$R"; say PASS "use" "${ARGS[0]}: uses $n -> $((n + 1))"
    summary ;;

  status)
    R=$(project_root); s=$(staged "$R" "${ARGS[0]:-}") || exit 1
    case "${ARGS[1]:-}" in
      proven)
        do_check "$(dirname "$s")"
        [ "$f" -eq 0 ] || { summary; die "the part does not pass check"; }
        n=$(fm "$s" uses); [ "$n" -ge 3 ] || die "${ARGS[0]} has $n real use(s): proven needs at least 3 (forge.sh use ${ARGS[0]} after each)" ;;
      experimental) ;;
      *) die "status needs proven or experimental" ;;
    esac
    setfm "$s" status "${ARGS[1]}" || die "could not update $s"
    write_registry "$R"; say PASS "status" "${ARGS[0]} is ${ARGS[1]}"
    summary ;;

  list)
    R=$(project_root)
    if [ ! -f "$R/docs/parts.md" ]; then
      [ -z "$(registry_rows "$R" | sed '1,2d')" ] && { echo "no parts yet"; exit 0; }
      die "parts exist in .claude/forge/ but docs/parts.md is missing"
    fi
    registry_block "$R"
    if [ "$(registry_block "$R")" = "$(registry_rows "$R")" ]; then say PASS "registry" "docs/parts.md matches .claude/forge/"
    else say FAIL "registry" "docs/parts.md does not match .claude/forge/ (edited by hand?); forge.sh use, status or install rewrite it"; fi
    summary ;;

  promote)
    R=$(project_root); name="${ARGS[0]:-}"; s=$(staged "$R" "$name") || exit 1
    [ -n "$TO" ] && [ -n "$PLUG" ] || die "promote needs --to <marketplace clone> and --plugin <plugin name>"
    [ "$(fm "$s" status)" = proven ] || die "$name is $(fm "$s" status): only a proven part is promoted (forge.sh status $name proven)"
    do_check "$(dirname "$s")"
    [ "$f" -eq 0 ] || { summary; die "the part does not pass check"; }
    C="$(cd "$TO" 2>/dev/null && pwd)" || die "clone not found: $TO"
    [ -f "$C/.claude-plugin/marketplace.json" ] || die "$C is not a marketplace (no .claude-plugin/marketplace.json)"
    [ -d "$C/plugins/$PLUG" ] || die "$C has no plugins/$PLUG"
    git -C "$C" rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "$C is not a git repository"
    [ -z "$(git -C "$C" status --porcelain)" ] || die "$C has uncommitted changes: promote works on a clean clone"
    git -C "$C" show-ref --verify -q "refs/heads/promote/$name" && die "branch promote/$name already exists in $C"
    type=$(fm "$s" type)
    dst="$C/plugins/$PLUG/parts/$name"
    [ -e "$dst" ] && die "plugins/$PLUG/parts/$name already exists in the clone"
    case "$type" in
      skill) [ -e "$C/plugins/$PLUG/skills/$name" ] && die "plugins/$PLUG/skills/$name already exists" ;;
      agent) [ -e "$C/plugins/$PLUG/agents/$name.md" ] && die "plugins/$PLUG/agents/$name.md already exists" ;;
    esac
    git -C "$C" switch -q -c "promote/$name" || die "could not create branch promote/$name"
    mkdir -p "$dst" && cp -RL "$(dirname "$s")/." "$dst/" || die "could not copy the part"
    case "$type" in
      skill) mkdir -p "$C/plugins/$PLUG/skills/$name" && cp -RL "$dst/files/." "$C/plugins/$PLUG/skills/$name/" ;;
      agent) mkdir -p "$C/plugins/$PLUG/agents" && cp "$dst/files/$name.md" "$C/plugins/$PLUG/agents/$name.md" ;;
    esac
    say PASS "promote" "branch promote/$name in $C; part copied to plugins/$PLUG/parts/$name${type:+ ($type)}"
    echo "Next: remove project details from the copy (keep the tests), run tests/run-all.sh in the clone, commit on promote/$name. Nothing is committed or pushed."
    summary ;;

  *) die "unknown command '${cmd}'. Use --help." ;;
esac
