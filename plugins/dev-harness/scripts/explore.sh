#!/usr/bin/env bash
# dev-harness explore: the experiment loop's referee. Claude proposes and implements variants;
# this script measures them, decides keep or revert, logs, and says when to stop.
#
# Usage (run inside the project):
#   explore.sh start <slug>                       branch (if on main/master), create docs/experiments.md
#   explore.sh baseline [--runs N]                measure and record the baseline row
#   explore.sh measure [--runs N]                 run the metric; prints VALUE=<n> (median of N runs)
#   explore.sh keep   <variant> <value> [note]    value must beat the best so far; commits variant + log row
#   explore.sh revert <variant> <value> [note]    restore the tree to HEAD; logs the row
#   explore.sh status                             BASELINE, BEST, NO_PROGRESS, STOP=yes|no, REASON
#
# docs/experiments.md is the source of truth. Its Metric section must have:
#   - Measured by: `<command>`      run from the project root; the last number on its last output line is the value
#   - Direction: higher is better   (or: lower is better)
#   - Target: <number or none>      optional
# The log table rows are: | Date | Variant | Metric | Result | Kept or reverted | Note |
#
# Rules enforced here, not in prose: a variant is kept only if it beats the best value; the loop stops
# on the target or after 2 variants in a row with no improvement; start refuses a dirty tree; keep and
# revert refuse on a detached HEAD or outside an explore/ branch. revert discards ALL uncommitted work
# except the log (so run start first and make only the variant's change), after saving it under
# refs/explore/ and .git/explore-backups/.
# Exit 1 on any refusal or failure, with a "FAIL" line.

set -u
PLUGIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
. "$PLUGIN/scripts/lib.sh"

EXP="docs/experiments.md"
MAX_NO_PROGRESS=2
TIMEOUT="${EXPLORE_TIMEOUT:-600}"

die() { echo "FAIL    $*" >&2; exit 1; }

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git repository (explore needs git to keep and revert variants)"
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT" || die "cannot enter $ROOT"

branch() { git symbolic-ref --short -q HEAD 2>/dev/null || echo ""; }
on_explore() { case "$(branch)" in explore/*) return 0 ;; esac; return 1; }
detached() { [ -z "$(branch)" ]; }

# dirty_except_log: porcelain lines other than docs/experiments.md (empty = clean enough).
# The porcelain path starts at column 4 ("XY path"); compare the whole path, so a file such as
# docs/experiments.md.bak is not mistaken for the log.
dirty_except_log() { git status --porcelain -uall | awk -v exp_path="$EXP" 'substr($0, 4) != exp_path'; }

# one-line, pipe-free text for table cells
cell() { printf '%s' "$1" | tr '\r\n|' '   ' | sed 's/^ *//; s/ *$//'; }

# --- parse the experiments file ------------------------------------------------------------
metric_cmd() {
  local line
  line=$(grep -m1 -i '^- *Measured by *:' "$EXP" 2>/dev/null) || return 1
  line="${line#*\`}"; line="${line%\`*}"
  case "$line" in ""|"<"*) return 1 ;; esac
  printf '%s' "$line"
}
direction() { # prints higher | lower
  local line hi lo
  line=$(grep -m1 -i '^- *Direction *:' "$EXP" 2>/dev/null) || return 1
  hi=0; lo=0
  grep -qi 'higher' <<<"$line" && hi=1
  grep -qi 'lower' <<<"$line" && lo=1
  [ $((hi + lo)) = 1 ] || return 1
  if [ $hi = 1 ]; then echo higher; else echo lower; fi
}
target() { # prints a number or nothing
  local line
  line=$(grep -m1 -i '^- *Target *:' "$EXP" 2>/dev/null) || return 0
  last_number "${line#*:}" | head -n1
}
# rows: date<TAB>variant<TAB>value<TAB>state  for rows whose state is baseline|kept|reverted and value numeric
rows() {
  awk -F'|' '
    function trim(s) { gsub(/^[ \t`]+|[ \t`]+$/, "", s); return s }
    /^\|/ {
      st = tolower(trim($6)); v = trim($4)
      if ((st == "baseline" || st == "kept" || st == "reverted") && v ~ /^-?[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?$/)
        printf "%s\t%s\t%s\t%s\n", trim($2), trim($3), v, st
    }' "$EXP" 2>/dev/null
}
best_value() { rows | awk -F'\t' '$4 == "baseline" || $4 == "kept" { b = $3 } END { if (b != "") print b }'; }
has_baseline() { rows | awk -F'\t' '$4 == "baseline" { f = 1 } END { exit !f }'; }
no_progress() { rows | awk -F'\t' '{ s[NR] = $4 } END { n = 0; for (i = NR; i >= 1 && s[i] == "reverted"; i--) n++; print n }'; }

need_metric() {
  [ -f "$EXP" ] || die "$EXP not found. Run: explore.sh start <slug>"
  CMD=$(metric_cmd) || die "$EXP: 'Measured by' has no command in backticks"
  DIR=$(direction) || die "$EXP: 'Direction' must say exactly one of: higher is better, lower is better"
  TARGET=$(target)
}

# beats VALUE BEST: strictly better in the stated direction
beats() { if [ "$DIR" = higher ]; then num_cmp "$1" '>' "$2"; else num_cmp "$1" '<' "$2"; fi; }

# --- append a row after the last table row (or at the end of the file) ------------------------
append_row() { # variant value result state note
  local row tmp
  row="| $(date +%F) | $(cell "$1") | \`$2\` | $(cell "$3") | $4 | $(cell "$5") |"
  tmp=$(mktemp)
  ROW="$row" awk '
    BEGIN { row = ENVIRON["ROW"] }
    { lines[NR] = $0; if ($0 ~ /^\|/) last = NR }
    END {
      if (last == 0) { for (i = 1; i <= NR; i++) print lines[i]; print row; exit }
      for (i = 1; i <= NR; i++) { print lines[i]; if (i == last) print row }
    }' "$EXP" > "$tmp" && cat "$tmp" > "$EXP" || { rm -f "$tmp"; die "could not write $EXP"; }
  rm -f "$tmp"
}

# --- measure -----------------------------------------------------------------------------
do_measure() { # [--runs N] -> prints VALUE=<median>
  local runs=1 vals="" i v
  while [ $# -gt 0 ]; do
    case "$1" in
      --runs) [ $# -ge 2 ] || die "--runs needs a value"; runs="$2"; shift 2 ;;
      *) die "unknown option: $1" ;;
    esac
  done
  case "$runs" in ""|*[!0-9]*|0) die "--runs must be a positive integer" ;; esac
  need_metric
  i=0
  while [ "$i" -lt "$runs" ]; do
    i=$((i + 1))
    run_limited "$TIMEOUT" "$CMD"
    if [ "$RUN_TIMED_OUT" = 1 ]; then die "metric command timed out after ${TIMEOUT}s: $CMD"; fi
    if [ "$RUN_RC" -ne 0 ]; then
      echo "--- last 20 lines ---" >&2; printf '%s\n' "$RUN_OUT" | tail -n 20 >&2
      die "metric command failed (exit $RUN_RC): $CMD"
    fi
    v=$(last_number "$RUN_OUT")
    if has_thousands_sep "$RUN_OUT"; then
      die "the metric's last line has a number with a thousands separator (like 1,234), which would be misread. Print a plain number: $CMD"
    fi
    if [ -n "$v" ] && [ "$(count_numbers "$RUN_OUT")" -gt 1 ]; then
      echo "NOTE    the last line has more than one number; using the last one ($v). Make the metric command print only the value." >&2
    fi
    if [ -z "$v" ]; then
      echo "--- last 20 lines ---" >&2; printf '%s\n' "$RUN_OUT" | tail -n 20 >&2
      die "metric command printed no number: $CMD"
    fi
    vals="$vals$v"$'\n'
  done
  VALUE=$(printf '%s' "$vals" | sort -g | awk '{ a[NR] = $1 } END { if (NR % 2) print a[(NR + 1) / 2]; else printf "%.10g\n", (a[NR / 2] + a[NR / 2 + 1]) / 2 }')
  echo "VALUE=$VALUE"
  [ "$runs" -gt 1 ] && echo "RUNS=$runs (median; all: $(printf '%s' "$vals" | tr '\n' ' '))"
  return 0
}

is_number() { [[ "$1" =~ ^-?[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?$ ]]; }

# --- subcommands ---------------------------------------------------------------------------
cmd="${1:-}"; [ $# -gt 0 ] && shift
case "$cmd" in
  start)
    slug="${1:-}"
    [[ "$slug" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || die "start needs a kebab-case slug, e.g. cut-latency"
    git rev-parse --verify -q HEAD >/dev/null || die "the repository has no commits yet; commit once so variants can be reverted"
    [ -z "$(dirty_except_log)" ] || { git status --short >&2; die "the working tree is not clean. Commit or stash first: revert would otherwise destroy your changes"; }
    detached && die "HEAD is detached: commits made now would be lost. Switch to a branch first"
    if ! on_explore; then
      from=$(branch)
      git switch -c "explore/$slug" >/dev/null 2>&1 || die "could not create branch explore/$slug"
      echo "  branch  explore/$slug (variants are kept there, not on $from)"
    fi
    if [ -e "$EXP" ]; then echo "  skip    $EXP (exists)"
    else
      mkdir -p "$(dirname "$EXP")" && cp "$PLUGIN/templates/project/docs/experiments.md" "$EXP" || die "could not create $EXP"
      echo "  add     $EXP (fill the Metric section: Name, Measured by, Direction, Target; then run baseline)"
    fi
    ;;

  measure) do_measure "$@" ;;

  baseline)
    need_metric
    has_baseline && die "a baseline is already recorded in $EXP"
    out=$(do_measure "$@") || exit 1
    value=$(sed -n 's/^VALUE=//p' <<<"$out")
    # Drop the template's example row (| YYYY-MM-DD | baseline | `<value>` | ...), now that a real one is written.
    tmp=$(mktemp); grep -v '^| YYYY-MM-DD |' "$EXP" > "$tmp"; cat "$tmp" > "$EXP"; rm -f "$tmp"
    append_row "baseline" "$value" "—" "baseline" "Starting point"
    echo "  add     baseline row: $value"
    ;;

  keep|revert)
    variant="${1:-}"; value="${2:-}"; note="${3:-}"
    [ -n "$variant" ] || die "$cmd needs a variant description"
    is_number "$value" || die "$cmd needs the measured value as a number (got '$value')"
    need_metric
    has_baseline || die "no baseline row in $EXP. Run: explore.sh baseline"
    detached && die "refusing to $cmd on a detached HEAD: the commit would be lost"
    on_explore || die "refusing to $cmd on '$(branch)': run explore.sh start <slug> to get an explore/ branch"
    best=$(best_value)
    delta=$(awk -v v="$value" -v b="$best" 'BEGIN { printf "%+.10g", v - b }')
    if [ "$cmd" = keep ]; then
      beats "$value" "$best" || die "$value does not beat the best so far ($best, $DIR is better). Use: explore.sh revert"
      [ -n "$(dirty_except_log)" ] || die "no changes to keep: the working tree equals HEAD"
      bak=$(mktemp); cat "$EXP" > "$bak"
      append_row "$variant" "$value" "$delta" "kept" "$note"
      errf=$(mktemp)
      if ! git add -A >/dev/null 2>"$errf" || ! git commit -q -m "explore: $(cell "$variant") ($best -> $value)" >/dev/null 2>>"$errf"; then
        # Undo the log row and unstage, so the state is as before and keep can simply be retried.
        cat "$bak" > "$EXP"; git reset -q HEAD >/dev/null 2>&1
        cat "$errf" >&2; rm -f "$errf" "$bak"
        die "git commit failed (for example a failing commit hook). Nothing was logged; the variant is still in the working tree. Fix the cause and run keep again, or run revert"
      fi
      rm -f "$errf" "$bak"
      echo "  kept    $variant: $best -> $value ($delta)"
    else
      # Everything uncommitted (except the log) is about to be discarded. Keep a way back first:
      # tracked changes as a commit object under refs/explore/, untracked files in a tar next to it.
      gitdir=$(git rev-parse --git-dir); stamp=$(date +%Y%m%d-%H%M%S)-$$
      mkdir -p "$gitdir/explore-backups"
      snap=$(git stash create 2>/dev/null)
      [ -z "$snap" ] || git update-ref "refs/explore/backup-$stamp" "$snap"
      untracked=$(git ls-files --others --exclude-standard -z | tr '\0' '\n' | grep -v -x -F "$EXP")
      if [ -n "$untracked" ]; then
        printf '%s\n' "$untracked" | tar -cf "$gitdir/explore-backups/$stamp.tar" -T - 2>/dev/null
      fi
      git reset -q HEAD -- . ":(exclude)$EXP" >/dev/null 2>&1 || die "git reset failed"
      git checkout -q HEAD -- . ":(exclude)$EXP" >/dev/null 2>&1 || die "git checkout failed"
      # Untracked, non-ignored files only, one by one (git clean -d would take the whole docs/ folder
      # with it when docs/experiments.md is the only untracked file in it). Then empty parent folders.
      while IFS= read -r -d '' f; do
        [ "$f" = "$EXP" ] && continue
        rm -f -- "$f" || die "could not remove $f"
        d=$(dirname "$f")
        while [ "$d" != . ] && rmdir "$d" 2>/dev/null; do d=$(dirname "$d"); done
      done < <(git ls-files --others --exclude-standard -z)
      append_row "$variant" "$value" "$delta" "reverted" "$note"
      echo "  reverted $variant: $value vs best $best ($delta). Tree restored to HEAD."
      if [ -n "${snap:-}" ] || [ -n "$untracked" ]; then
        echo "  backup  discarded work saved: ${snap:+refs/explore/backup-$stamp (tracked changes; git stash apply refs/explore/backup-$stamp) }${untracked:+$gitdir/explore-backups/$stamp.tar (untracked files)}"
      fi
    fi
    ;;

  status)
    need_metric
    if ! has_baseline; then
      echo "BASELINE=none"; echo "STOP=no"; echo "REASON=no baseline yet: run explore.sh baseline"; exit 0
    fi
    base=$(rows | awk -F'\t' '$4 == "baseline" { print $3; exit }')
    best=$(best_value)
    kept=$(rows | awk -F'\t' '$4 == "kept"' | wc -l | tr -d ' ')
    rev=$(rows | awk -F'\t' '$4 == "reverted"' | wc -l | tr -d ' ')
    np=$(no_progress)
    echo "BASELINE=$base"; echo "BEST=$best"; echo "DIRECTION=$DIR"; echo "TARGET=${TARGET:-none}"
    echo "VARIANTS=$((kept + rev)) (kept $kept, reverted $rev)"; echo "NO_PROGRESS=$np"
    stop=no; reason="continue: $np of $MAX_NO_PROGRESS variants without improvement"
    if [ -n "$TARGET" ]; then
      if [ "$DIR" = higher ]; then num_cmp "$best" '>=' "$TARGET" && { stop=yes; reason="target reached ($best vs $TARGET)"; }
      else num_cmp "$best" '<=' "$TARGET" && { stop=yes; reason="target reached ($best vs $TARGET)"; }; fi
    fi
    if [ $stop = no ] && [ "$np" -ge "$MAX_NO_PROGRESS" ]; then stop=yes; reason="$np variants in a row without improvement"; fi
    echo "STOP=$stop"; echo "REASON=$reason"
    ;;

  *) sed -n '2,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; [ -z "$cmd" ] || die "unknown subcommand: $cmd"; exit 1 ;;
esac
