#!/usr/bin/env bash
# dev-harness scaffolder. Copies templates into a project. Never overwrites.
#
# Usage:
#   scaffold.sh <project-dir> files      --profile P [--dry-run]
#   scaffold.sh <project-dir> guardrails --profile P [--verify-cmd CMD] [--merge-settings] [--dry-run]
#
# files       CLAUDE.md (profile rules rendered), docs/, .claude/rules/, .gitignore entries.
# guardrails  .claude/hooks/*.sh, harness.conf, .claude/settings.json, CI workflow; then runs test-hooks.sh.
#             Run it LAST: hooks take effect in the running session as soon as settings.json lands.
#
# Existing files are skipped. An existing .claude/settings.json is merged only with
# --merge-settings (union of permissions and hooks; the diff is always printed first).
# Output: one line per path: add | skip | merge | update | ok | FAIL. Exit 1 on any FAIL.

set -u
PLUGIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TPL="$PLUGIN/templates/project"

die() { echo "FAIL    $*" >&2; exit 1; }

DEST="${1:-}"; PHASE="${2:-}"; shift 2 2>/dev/null || true
PROFILE=""; VERIFY=""; VERIFY_SET=0; DRY=0; MERGE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --profile) PROFILE="${2:-}"; shift 2 ;;
    --verify-cmd) VERIFY="${2-}"; VERIFY_SET=1; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --merge-settings) MERGE=1; shift ;;
    *) die "unknown option: $1" ;;
  esac
done

[ -n "$DEST" ] && [ -d "$DEST" ] || die "project dir not found: '$DEST'"
DEST="$(cd "$DEST" && pwd)"
case "$PHASE" in files|guardrails) ;; *) die "phase must be 'files' or 'guardrails'" ;; esac
case "$PROFILE" in prototype|product|assignment) ;; *) die "--profile must be prototype, product or assignment" ;; esac
PROF="$PLUGIN/templates/profiles/$PROFILE"
command -v jq >/dev/null || die "jq is required (brew install jq / apt install jq). The hooks need it too."
case "$VERIFY" in *$'\n'*) die "--verify-cmd must be one line" ;; esac

fails=0
TMPD=$(mktemp -d); trap 'rm -rf "$TMPD"' EXIT
say() { printf '  %-7s %s\n' "$1" "$2"; [ "$1" = FAIL ] && fails=$((fails+1)); return 0; }
[ $DRY = 1 ] && echo "DRY RUN: nothing is written."
echo "dev-harness $PHASE -> $DEST (profile: $PROFILE)"

# put REL SOURCE_FILE: copy unless the destination exists.
put() {
  local rel="$1" src="$2"
  if [ -e "$DEST/$rel" ]; then say skip "$rel (exists)"; return; fi
  if [ $DRY = 0 ]; then
    mkdir -p "$DEST/$(dirname "$rel")" && cp "$src" "$DEST/$rel" || { say FAIL "$rel (copy failed)"; return; }
  fi
  say add "$rel"
}

if [ "$PHASE" = files ]; then
  # CLAUDE.md with the profile rendered in.
  rendered="$TMPD/CLAUDE.md"
  awk -v profile="$PROFILE" -v rules="$PROF/claude-rules.md" '
    /\{\{PROFILE_RULES\}\}/ { while ((getline line < rules) > 0) print line; next }
    { gsub(/\{\{PROFILE\}\}/, profile); print }' "$TPL/CLAUDE.md" > "$rendered"
  put CLAUDE.md "$rendered"

  while IFS= read -r f; do
    put "${f#"$TPL"/}" "$f"
  done < <(find "$TPL/docs" "$TPL/.claude/rules" -type f -not -name '.DS_Store' | sort)

  for line in "CLAUDE.local.md" ".claude/settings.local.json"; do
    if grep -qxF "$line" "$DEST/.gitignore" 2>/dev/null; then say skip ".gitignore has $line"
    else [ $DRY = 0 ] && echo "$line" >> "$DEST/.gitignore"; say update ".gitignore += $line"; fi
  done
fi

if [ "$PHASE" = guardrails ]; then
  for f in "$TPL"/.claude/hooks/*.sh; do put ".claude/hooks/$(basename "$f")" "$f"; done
  [ $DRY = 0 ] && chmod +x "$DEST"/.claude/hooks/*.sh 2>/dev/null

  # harness.conf from the profile, with VERIFY_CMD overridden if given.
  conf="$TMPD/harness.conf"
  if [ $VERIFY_SET = 1 ]; then
    awk -v v="$VERIFY" '/^VERIFY_CMD=/ { print "VERIFY_CMD=\"" v "\""; next } { print }' "$PROF/harness.conf" > "$conf"
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
    ' "$S" "$PROF/settings.json" > "$merged" || { say FAIL ".claude/settings.json merge failed"; }
    if jq -e --slurpfile a "$S" '. == $a[0]' "$merged" >/dev/null; then
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
