#!/usr/bin/env bash
# dev-harness scaffolder. Copies templates into a project. Never overwrites.
#
# Usage:
#   scaffold.sh <project-dir> files      [--profile P] [--part NAME] [--dry-run]
#   scaffold.sh <project-dir> guardrails --profile P [--verify-cmd CMD] [--merge-settings] [--dry-run]
#
# files       CLAUDE.md (profile rules rendered), docs/, .claude/rules/, .gitignore entries.
#             --part NAME writes one part only (default: every part):
#               memory     CLAUDE.md, docs/{INDEX,architecture,conventions,lessons,progress,experiments}.md
#               lessons    docs/lessons.md
#               reviewer   docs/agents/INDEX.md
#               workflows  docs/workflow.md, docs/agents/first-workflow.md, docs/audits/README.md
#               rules      .claude/rules/
#               tasks      docs/tasks/_template.md, docs/tasks/INDEX.md (task cards; see scripts/tasks.sh)
#             --profile is required for the default and for memory (CLAUDE.md is rendered from it).
# guardrails  .claude/hooks/*.sh, harness.conf, .claude/settings.json, CI workflow; then runs test-hooks.sh.
#             Run it LAST: hooks take effect in the running session as soon as settings.json lands.
#
# Existing files are skipped. An existing .claude/settings.json is merged only with
# --merge-settings (union of permissions and hooks; the diff is always printed first).
# Output: one line per path: add | skip | merge | update | ok | note | FAIL. Exit 1 on any FAIL.
# "note" is advice (for example a routed file that another part adds), never a failure.

# -h / --help prints the comment block at the top of this file (the usage).
case "${1:-}" in -h|--help) sed -n -E '2,/^([^#]|$)/{/^#/s/^# ?//p;}' "$0"; exit 0 ;; esac

set -u
PLUGIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TPL="$PLUGIN/templates/project"

die() { echo "FAIL    $*" >&2; exit 1; }

DEST="${1:-}"; PHASE="${2:-}"; shift 2 2>/dev/null || true
PROFILE=""; PART=""; PART_SET=0; VERIFY=""; VERIFY_SET=0; DRY=0; MERGE=0
while [ $# -gt 0 ]; do
  case "$1" in --profile|--verify-cmd|--part) [ $# -ge 2 ] || die "$1 needs a value" ;; esac
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --part) PART="$2"; PART_SET=1; shift 2 ;;
    --verify-cmd) VERIFY="$2"; VERIFY_SET=1; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --merge-settings) MERGE=1; shift ;;
    *) die "unknown option: $1" ;;
  esac
done

[ -n "$DEST" ] && [ -d "$DEST" ] || die "project dir not found: '$DEST'"
DEST="$(cd "$DEST" && pwd)"
case "$PHASE" in files|guardrails) ;; *) die "phase must be 'files' or 'guardrails'" ;; esac
[ $PART_SET = 0 ] || [ -n "$PART" ] || die "--part needs a value"
case "$PART" in
  "") ;;
  memory|lessons|reviewer|workflows|rules|tasks) [ "$PHASE" = files ] || die "--part only applies to the files phase" ;;
  *) die "--part must be memory, lessons, reviewer, workflows, rules or tasks" ;;
esac
# The profile renders CLAUDE.md and picks the hooks; the other parts do not need it.
NEED_PROFILE=0
if [ "$PHASE" = guardrails ] || [ -z "$PART" ] || [ "$PART" = memory ]; then NEED_PROFILE=1; fi
if [ $NEED_PROFILE = 1 ] || [ -n "$PROFILE" ]; then
  case "$PROFILE" in prototype|product|assignment) ;; *) die "--profile must be prototype, product or assignment" ;; esac
fi
PROF="$PLUGIN/templates/profiles/$PROFILE"
command -v jq >/dev/null || die "jq is required (brew install jq / apt install jq). The hooks need it too."
case "$VERIFY" in *$'\n'*|*$'\r'*) die "--verify-cmd must be one line" ;; esac

fails=0
TMPD=$(mktemp -d); trap 'rm -rf "$TMPD"' EXIT
say() { printf '  %-7s %s\n' "$1" "$2"; [ "$1" = FAIL ] && fails=$((fails+1)); return 0; }
[ $DRY = 1 ] && echo "DRY RUN: nothing is written."
echo "dev-harness $PHASE${PART:+ ($PART)} -> $DEST${PROFILE:+ (profile: $PROFILE)}"

# put REL SOURCE_FILE: copy unless the destination exists (a dangling symlink counts as existing).
ADDED=""
put() {
  local rel="$1" src="$2"
  if [ -e "$DEST/$rel" ] || [ -L "$DEST/$rel" ]; then say skip "$rel (exists)"; return 1; fi
  if [ $DRY = 0 ]; then
    mkdir -p "$DEST/$(dirname "$rel")" && cp "$src" "$DEST/$rel" || { say FAIL "$rel (copy failed)"; return; }
  fi
  say add "$rel"; ADDED="$ADDED|$rel|"
}

# detect_verify PROFILE: a fast check command for this project, or nothing. Used only when --verify-cmd was
# not given (new and add propose a command and pass it; this is the fallback). First match wins:
# package.json scripts, Makefile targets, Cargo.toml, go.mod, pyproject.toml.
# product = typecheck + lint, assignment = tests.
detect_verify() {
  local prof="$1" pm=npm run="npm run" cmd="" s
  if [ -f "$DEST/package.json" ] && jq -e '.scripts | type == "object"' "$DEST/package.json" >/dev/null 2>&1; then
    if [ -f "$DEST/pnpm-lock.yaml" ]; then pm=pnpm; run="pnpm run"; elif [ -f "$DEST/yarn.lock" ]; then pm=yarn; run="yarn"; fi
    if [ "$prof" = product ]; then
      for s in typecheck lint; do
        jq -e --arg s "$s" '.scripts[$s] | type == "string"' "$DEST/package.json" >/dev/null 2>&1 \
          && cmd="${cmd:+$cmd && }$run $s"
      done
    else
      # npm init writes a "test" script that only fails ("Error: no test specified"): that is not a test.
      jq -e '.scripts.test | type == "string" and (test("no test specified") | not)' "$DEST/package.json" >/dev/null 2>&1 \
        && cmd="$pm test"
    fi
    [ -n "$cmd" ] && { printf '%s' "$cmd"; return; }
  fi
  if [ -f "$DEST/Makefile" ]; then
    if [ "$prof" = product ]; then
      for s in check lint; do grep -Eq "^$s:" "$DEST/Makefile" && { printf 'make %s' "$s"; return; }; done
    else
      grep -Eq '^test:' "$DEST/Makefile" && { printf 'make test'; return; }
    fi
  fi
  if [ -f "$DEST/Cargo.toml" ]; then
    if [ "$prof" = product ]; then printf 'cargo clippy'; else printf 'cargo test'; fi; return
  fi
  if [ -f "$DEST/go.mod" ]; then
    if [ "$prof" = product ]; then printf 'go vet ./...'; else printf 'go test ./...'; fi; return
  fi
  if [ -f "$DEST/pyproject.toml" ]; then
    if [ "$prof" = product ]; then
      grep -q '^\[tool\.ruff' "$DEST/pyproject.toml" && cmd="ruff check ."
      grep -q '^\[tool\.mypy' "$DEST/pyproject.toml" && cmd="${cmd:+$cmd && }mypy ."
      printf '%s' "$cmd"
    elif grep -q '^\[tool\.pytest' "$DEST/pyproject.toml" || [ -f "$DEST/pytest.ini" ] || [ -d "$DEST/tests" ]; then
      printf 'python3 -m pytest -q'   # only when pytest is configured or a tests/ folder exists
    fi
  fi
}

# want PART...: true when no --part was given, or --part is one of the arguments.
want() { local p; [ -z "$PART" ] && return 0; for p in "$@"; do [ "$p" = "$PART" ] && return 0; done; return 1; }

# gitignore_line LINE: append once, never glued onto a last line that has no newline.
gitignore_line() {
  if grep -qxF "$1" "$DEST/.gitignore" 2>/dev/null; then say skip ".gitignore has $1"
  else
    if [ $DRY = 0 ]; then
      [ -s "$DEST/.gitignore" ] && [ -n "$(tail -c 1 "$DEST/.gitignore")" ] && echo >> "$DEST/.gitignore"
      echo "$1" >> "$DEST/.gitignore"
    fi
    say update ".gitignore += $1"
  fi
}

if [ "$PHASE" = files ]; then
  if want memory; then
    # CLAUDE.md with the profile rendered in.
    rendered="$TMPD/CLAUDE.md"
    awk -v profile="$PROFILE" -v rules="$PROF/claude-rules.md" '
      /\{\{PROFILE_RULES\}\}/ { while ((getline line < rules) > 0) print line; next }
      { gsub(/\{\{PROFILE\}\}/, profile); print }' "$TPL/CLAUDE.md" > "$rendered"
    put CLAUDE.md "$rendered"
  fi

  while IFS= read -r f; do
    rel="${f#"$TPL"/}"
    # Which parts own this file. Anything not listed belongs to memory.
    case "$rel" in
      docs/lessons.md) owners="lessons memory" ;;
      docs/agents/INDEX.md) owners="reviewer" ;;
      docs/workflow.md|docs/agents/first-workflow.md|docs/audits/*) owners="workflows" ;;
      .claude/rules/*) owners="rules" ;;
      docs/tasks/*) owners="tasks" ;;
      *) owners="memory" ;;
    esac
    # shellcheck disable=SC2086  # $owners is a short word list
    want $owners && put "$rel" "$f"
  done < <(find "$TPL/docs" "$TPL/.claude/rules" -type f -not -name '.DS_Store' | sort)

  want memory && gitignore_line "CLAUDE.local.md"
  want tasks && gitignore_line ".claude/active-task"   # per worktree, written by tasks.sh active

  # The memory part writes the router and docs/INDEX.md, which route to files owned by other parts.
  if [ "$PART" = memory ]; then
    for pair in "docs/workflow.md:workflows" "docs/agents/first-workflow.md:workflows" "docs/audits/README.md:workflows" "docs/agents/INDEX.md:reviewer" "docs/tasks/INDEX.md:tasks"; do
      if [ ! -e "$DEST/${pair%%:*}" ] && [ ! -L "$DEST/${pair%%:*}" ]; then
        say note "${pair%%:*} is routed from CLAUDE.md or docs/INDEX.md but does not exist; add it with: add ${pair##*:}"
      fi
    done
  fi
  [ -z "$PART" ] && gitignore_line ".claude/settings.local.json"
fi

if [ "$PHASE" = guardrails ]; then
  gitignore_line ".claude/settings.local.json"
  for f in "$TPL"/.claude/hooks/*.sh; do
    rel=".claude/hooks/$(basename "$f")"
    if put "$rel" "$f"; then
      [ $DRY = 0 ] && chmod +x "$DEST/$rel"   # only files we added
    elif [ -f "$DEST/$rel" ] && grep -q 'harness.conf' "$f" && ! grep -q 'harness.conf' "$DEST/$rel"; then
      # An older hook (e.g. from claude-harness.zip) that ignores the profile.
      say FAIL "$rel exists but does not read harness.conf: the profile is NOT applied. Compare it with $f, then update it yourself or move it aside and rerun."
    fi
  done

  # harness.conf from the profile, with VERIFY_CMD overridden if given. No profile ships a stack-specific
  # command: without --verify-cmd, product and assignment get one detected from the project (or none).
  conf="$TMPD/harness.conf"
  if [ $VERIFY_SET = 0 ] && [ ! -e "$DEST/.claude/hooks/harness.conf" ] && [ ! -L "$DEST/.claude/hooks/harness.conf" ]; then
    case "$PROFILE" in
      product|assignment)
        VERIFY=$(detect_verify "$PROFILE")
        # A command whose tool is not installed would fail on every Stop: leave it empty and say why.
        # DH_DETECT_PATH (tests only) replaces PATH for this lookup.
        tool="${VERIFY%% *}"
        if [ -n "$VERIFY" ] && ! PATH="${DH_DETECT_PATH:-$PATH}" command -v "$tool" >/dev/null 2>&1; then
          say note "VERIFY_CMD not set: detected '$VERIFY', but '$tool' is not installed here"
          VERIFY=""
        fi
        if [ -n "$VERIFY" ]; then
          VERIFY_SET=1
          say note "VERIFY_CMD detected: $VERIFY (confirm it with the user; only the user edits .claude/hooks/harness.conf)"
        else
          say note "VERIFY_CMD is empty: no test, lint or typecheck command was found, so verify.sh is off until the user sets VERIFY_CMD in .claude/hooks/harness.conf"
        fi ;;
    esac
  fi
  if [ $VERIFY_SET = 1 ]; then
    # Written verbatim: no awk -v (it would process backslash escapes).
    { grep -v '^VERIFY_CMD=' "$PROF/harness.conf"; printf 'VERIFY_CMD="%s"\n' "$VERIFY"; } > "$conf"
  else cp "$PROF/harness.conf" "$conf"; fi
  put .claude/hooks/harness.conf "$conf"

  put .github/workflows/dev-harness-hooks.yml "$TPL/.github/workflows/dev-harness-hooks.yml"

  # settings.json: add, or merge (union) only when asked.
  S="$DEST/.claude/settings.json"
  if [ ! -e "$S" ]; then
    put .claude/settings.json "$PROF/settings.json"
  elif ! jq empty "$S" 2>/dev/null; then
    say FAIL ".claude/settings.json exists but is not valid JSON; fix it, then rerun"
  else
    merged="$TMPD/settings.json"
    jq -s '
      .[0] as $u | .[1] as $h
      | def union(a; b): (a // []) + ((b // []) - (a // []));
        def cmds(groups): [groups[]?.hooks[]?.command];
      $u
      | .permissions.allow = union($u.permissions.allow; $h.permissions.allow)
      | .permissions.ask   = union($u.permissions.ask;   $h.permissions.ask)
      | .permissions.deny  = union($u.permissions.deny;  $h.permissions.deny)
      | .permissions.disableBypassPermissionsMode = ($u.permissions.disableBypassPermissionsMode // $h.permissions.disableBypassPermissionsMode)
      | .hooks = reduce ($h.hooks | to_entries[]) as $e (($u.hooks // {});
          .[$e.key] = ((.[$e.key] // []) as $mine
            | $mine + [ $e.value[] | select(([.hooks[]?.command] - cmds($mine)) | length > 0) ]))
    ' "$S" "$PROF/settings.json" > "$merged" 2>"$TMPD/merge.err"
    if [ $? -ne 0 ] || ! jq -e 'type == "object"' "$merged" >/dev/null 2>&1; then
      say FAIL ".claude/settings.json could not be merged (unexpected shape: $(head -c 200 "$TMPD/merge.err")). File left unchanged; merge it by hand from $PROF/settings.json"
    elif jq -e --slurpfile a "$S" '. == $a[0]' "$merged" >/dev/null; then
      say skip ".claude/settings.json (already has every dev-harness rule and hook)"
    else
      echo "  --- proposed merge of .claude/settings.json (your rules kept, dev-harness rules added) ---"
      diff <(jq -S . "$S") <(jq -S . "$merged") | sed 's/^/  | /'
      if [ $MERGE = 1 ] && [ $DRY = 0 ]; then cp "$merged" "$S"; say merge ".claude/settings.json"
      elif [ $MERGE = 1 ]; then say merge ".claude/settings.json (dry run)"
      else say skip ".claude/settings.json (exists; rerun with --merge-settings to apply the merge above)"; fi
    fi
  fi

  if [ $DRY = 0 ]; then
    echo "Running .claude/hooks/test-hooks.sh ..."
    if out=$(cd "$DEST" && bash .claude/hooks/test-hooks.sh 2>&1); then
      say ok "hook tests: $(tail -n 1 <<<"$out")"
    else
      echo "$out" | grep -E 'FAIL|Result' | sed 's/^/  | /'
      say FAIL "hook tests failed: guardrails are NOT verified"
    fi
  fi
fi

echo "Done: $fails failure(s)."
[ $fails -eq 0 ]
