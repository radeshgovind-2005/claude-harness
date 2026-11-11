#!/usr/bin/env bash
# dev-harness tasks: task cards in docs/tasks/ (one card per piece of work). Code enforces, text advises.
#
# Usage (run in the project, or set TASKS_ROOT=<project dir>):
#   tasks.sh new "<title>" --scope "g1, g2" --goal "..." --done-when "..." --read-first "p1, p2, p3"
#                          [--depends "001, 002"] [--next "..."] [--owner NAME]
#   tasks.sh check                 cards complete, statuses valid, depends exist with no cycle,
#                                  INDEX matches the cards, then overlap
#   tasks.sh overlap               FAIL for two not-done cards whose scopes overlap with no dependency
#                                  path between them: those cards are not parallel
#   tasks.sh index                 rewrite the table in docs/tasks/INDEX.md from the cards
#   tasks.sh active [<id>|--clear] show, set or clear the active card of this worktree
#                                  (.claude/active-task, gitignored; read by the SessionStart hook)
#   tasks.sh worktree <id>         a git worktree and branch task/<id> for one card; the card becomes
#                                  in-progress and active there
#
# A card is docs/tasks/NNN-slug.md with frontmatter id, title, status (open|in-progress|blocked|done),
# owner, depends (ids, comma-separated) and scope (globs, comma-separated: * ? and ** work; [..] and
# {..} are treated as *, so overlap can over-report but never misses one). An entry without a wildcard
# whose last segment has no dot is read as a folder and covers everything below it (src/api means
# src/api and src/api/**; src/a.ts is just the file). A folder with a dot in its name must end in /
# or /** (src/v1.0/), or what is below it is not covered. Commas inside {..} do not split the scope.
# <id> may be the full id (003-login-form) or its number (003).
# Output: PASS|WARN|FAIL lines, then SUMMARY. Exit 1 on any FAIL.

# -h / --help prints the comment block at the top of this file (the usage).
case "${1:-}" in -h|--help) sed -n -E '2,/^([^#]|$)/{/^#/s/^# ?//p;}' "$0"; exit 0 ;; esac

set -u
ROOT="${TASKS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
ROOT="$(cd "$ROOT" 2>/dev/null && pwd)" || { echo "FAIL    project dir not found: ${TASKS_ROOT:-.}" >&2; exit 1; }
TD="$ROOT/docs/tasks"
ACTIVE="$ROOT/.claude/active-task"

p=0; w=0; f=0
say() { printf '%-5s %s — %s\n' "$1" "$2" "$3"; case "$1" in PASS) p=$((p+1)) ;; WARN) w=$((w+1)) ;; FAIL) f=$((f+1)) ;; esac; }
summary() { echo "SUMMARY pass=$p warn=$w fail=$f"; [ "$f" -eq 0 ]; }
die() { echo "FAIL    $*" >&2; exit 1; }

# fm FILE KEY: a frontmatter value (between the first two --- lines), trimmed, CR dropped.
fm() {
  tr -d '\r' < "$1" | awk -v k="$2" 'NR==1 && $0!="---" {exit} NR>1 && /^---[[:space:]]*$/ {exit}
    NR>1 { i=index($0, ":"); if (i && substr($0,1,i-1)==k) { v=substr($0,i+1); sub(/^[[:space:]]+/,"",v); sub(/[[:space:]]+$/,"",v); print v; exit } }'
}
# section FILE NAME: the body of "## NAME" up to the next "## ", without HTML comments and blank lines.
section() {
  tr -d '\r' < "$1" | awk -v n="## $2" '$0==n {on=1; next} on && /^## / {exit} on {print}' \
    | sed -e 's/<!--.*-->//g' | grep -v '^[[:space:]]*$'
}
cards() { [ -d "$TD" ] && find "$TD" -maxdepth 1 -type f -name '[0-9][0-9][0-9]-*.md' | LC_ALL=C sort; }
# resolve ID-or-number -> full id (exactly one card), or fail.
resolve() {
  local want="$1" c id hits=""
  while IFS= read -r c; do id=$(basename "$c" .md)
    case "$id" in "$want"|"$want"-*) hits="$hits $id" ;; esac
  done < <(cards)
  set -- $hits
  [ $# -eq 1 ] || die "no single card matches '$want'${hits:+ (matches:$hits)}"
  printf '%s' "$1"
}
valid_id() { [[ "$1" =~ ^[0-9]{3}-[a-z0-9]+(-[a-z0-9]+)*$ ]]; }

# The table INDEX.md should have, from the cards.
index_rows() {
  local c
  echo "| id | title | status | owner | depends |"
  echo "|---|---|---|---|---|"
  while IFS= read -r c; do
    printf '| %s | %s | %s | %s | %s |\n' "$(fm "$c" id)" "$(fm "$c" title | sed 's/|/\\|/g')" \
      "$(fm "$c" status)" "$(fm "$c" owner | sed 's/|/\\|/g')" "$(fm "$c" depends)"
  done < <(cards)
}
index_block() { tr -d '\r' < "$TD/INDEX.md" | awk '/<!-- tasks:index:end -->/ {on=0} on {print} /<!-- tasks:index:start -->/ {on=1}'; }
write_index() {
  local idx="$TD/INDEX.md" tmp
  grep -q '<!-- tasks:index:start -->' "$idx" 2>/dev/null && grep -q '<!-- tasks:index:end -->' "$idx" \
    || die "$idx has no <!-- tasks:index:start --> / <!-- tasks:index:end --> markers"
  tmp=$(mktemp "${TMPDIR:-/tmp}/dh-index.XXXXXX") || die "mktemp failed"
  index_rows > "$tmp.rows"
  awk -v rows="$tmp.rows" '/<!-- tasks:index:start -->/ {print; while ((getline l < rows) > 0) print l; skip=1; next}
    /<!-- tasks:index:end -->/ {skip=0} !skip {print}' "$idx" > "$tmp" && cat "$tmp" > "$idx"
  rm -f "$tmp" "$tmp.rows"
}

# overlap_check [ONLY_ID]: one line per not-done card into awk, which checks dependency paths (and cycles)
# and intersects the scope globs. With ONLY_ID, only pairs that include that card are checked.
overlap_check() {
  local only="${1:-}" c
  while IFS= read -r c; do
    printf '%s\t%s\t%s\t%s\n' "$(fm "$c" id)" "$(fm "$c" status)" "$(fm "$c" depends)" "$(fm "$c" scope)"
  done < <(cards) | awk -F'\t' -v only="$only" '
    function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
    # norm: ./ and leading / dropped; [..] and {..} become *; a trailing / means everything below.
    function norm(g) { g = trim(g); sub(/^\.\//, "", g); sub(/^\/+/, "", g)
      gsub(/\[[^]]*\]/, "*", g); gsub(/\{[^}]*\}/, "*", g); sub(/\/$/, "/**", g); return g }
    # seg(p, q): is there a string that matches both single-segment patterns (* and ?)?
    function seg(p, q,    k, r, a, b) {
      k = p SUBSEP q; if (k in SM) return SM[k]
      if (p == "" && q == "") r = 1
      else if (p == "") r = (q ~ /^\**$/)
      else if (q == "") r = (p ~ /^\**$/)
      else { a = substr(p, 1, 1); b = substr(q, 1, 1)
        if (a == "*") r = seg(substr(p, 2), q) || seg(p, substr(q, 2))
        else if (b == "*") r = seg(p, substr(q, 2)) || seg(substr(p, 2), q)
        else r = (a == "?" || b == "?" || a == b) && seg(substr(p, 2), substr(q, 2)) }
      SM[k] = r; return r }
    # path(i, j): do segments A[i..] and B[j..] have a common match? ** is zero or more segments.
    function path(i, j,    k, r) {
      k = i SUBSEP j; if (k in PM) return PM[k]
      if (i > na && j > nb) r = 1
      else if (i <= na && A[i] == "**") r = path(i + 1, j) || (j <= nb && path(i, j + 1))
      else if (j <= nb && B[j] == "**") r = path(i, j + 1) || (i <= na && path(i + 1, j))
      else if (i > na || j > nb) r = 0
      else r = seg(A[i], B[j]) && path(i + 1, j + 1)
      PM[k] = r; return r }
    # splitg(s, out): split a scope on commas that are not inside {...}.
    function splitg(s, out,    n, i, ch, depth, cur) { n = 0; depth = 0; cur = ""
      for (i = 1; i <= length(s); i++) { ch = substr(s, i, 1)
        if (ch == "{") depth++; else if (ch == "}" && depth > 0) depth--
        if (ch == "," && depth == 0) { out[++n] = cur; cur = "" } else cur = cur ch }
      out[++n] = cur; return n }
    # dirlike(g): a literal entry whose last segment has no dot is read as a folder (src/api covers src/api/**).
    function dirlike(g,    s) { if (g ~ /[*?]/) return 0; s = g; sub(/.*\//, "", s); return s !~ /\./ }
    function globs_meet(x, y) { split("", PM); na = split(x, A, "/"); nb = split(y, B, "/"); return path(1, 1) }
    # reach(a, b): is there a dependency path from a to b?
    function reach(a, b,    n, i, L, d) {
      if (a == b) return 1
      if ((a SUBSEP b) in RM) return RM[a SUBSEP b]
      RM[a SUBSEP b] = 0; n = split(DEP[a], L, ",")
      for (i = 1; i <= n; i++) { d = trim(L[i]); if (d != "" && reach(d, b)) { RM[a SUBSEP b] = 1; return 1 } }
      return 0 }
    { id[NR] = $1; st[$1] = $2; DEP[$1] = $3; SC[$1] = $4; n = NR; known[$1] = 1 }
    END {
      bad = 0
      for (i = 1; i <= n; i++) {          # depends name real cards, and nothing depends on itself
        m = split(DEP[id[i]], L, ",")
        for (k = 1; k <= m; k++) { d = trim(L[k]); if (d == "") continue
          if (!(d in known)) { print "FAIL\tdepends\t" id[i] " depends on " d ", which is not a card"; bad++ }
          else { split("", RM); if (reach(d, id[i])) { print "FAIL\tdepends\tcycle: " id[i] " and " d " depend on each other"; bad++ } } } }
      pairs = 0
      for (i = 1; i <= n; i++) for (j = i + 1; j <= n; j++) {
        a = id[i]; b = id[j]
        if (st[a] == "done" || st[b] == "done") continue
        if (only != "" && a != only && b != only) continue
        pairs++
        split("", RM); if (reach(a, b) || reach(b, a)) continue
        na2 = splitg(SC[a], GA); nb2 = splitg(SC[b], GB); hit = ""
        for (x = 1; x <= na2 && hit == ""; x++) for (y = 1; y <= nb2 && hit == ""; y++) {
          ga = norm(GA[x]); gb = norm(GB[y]); if (ga == "" || gb == "") continue
          # a literal entry also covers what is below it
          if (globs_meet(ga, gb) || (dirlike(ga) && globs_meet(ga "/**", gb)) || (dirlike(gb) && globs_meet(ga, gb "/**")))
            hit = ga " vs " gb }
        if (hit != "") { print "FAIL\toverlap\t" a " and " b " overlap (" hit ") with no dependency between them: they are not parallel. Add one to the other'"'"'s depends, or narrow a scope"; bad++ } }
      if (bad == 0) print "PASS\toverlap\t" pairs " pair(s) of not-done cards checked, no undeclared overlap" }'
}
run_overlap() { local s n d; while IFS=$'\t' read -r s n d; do say "$s" "$n" "$d"; done < <(overlap_check "${1:-}"); }

cmd="${1:-}"; [ $# -gt 0 ] && shift
case "$cmd" in
  new)
    [ -d "$TD" ] || die "no docs/tasks/ in $ROOT (add it with: scaffold.sh <dir> files --part tasks)"
    title="${1:-}"; [ $# -gt 0 ] && shift
    [ -n "$title" ] || die "new needs a title"
    scope=""; deps=""; goal=""; done_when=""; readf=""; next=""; owner="unassigned"
    while [ $# -gt 0 ]; do
      [ $# -ge 2 ] || die "$1 needs a value"
      case "$1" in
        --scope) scope="$2" ;; --depends) deps="$2" ;; --goal) goal="$2" ;; --done-when) done_when="$2" ;;
        --read-first) readf="$2" ;; --next) next="$2" ;; --owner) owner="$2" ;;
        *) die "unknown option: $1" ;;
      esac; shift 2
    done
    for v in "$title" "$scope" "$deps" "$goal" "$done_when" "$readf" "$next" "$owner"; do
      case "$v" in *$'\n'*|*$'\r'*) die "values must be one line" ;; esac
    done
    [ -n "$scope" ] || die "new needs --scope (the globs this card may touch)"
    last=$(cards | sed -E 's|.*/([0-9]{3})-.*|\1|' | tail -n 1)
    num=$(printf '%03d' $((10#${last:-0} + 1)))
    slug=$(printf '%s' "$title" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' | cut -c1-40 | sed -E 's/-+$//')
    id="$num-${slug:-task}"
    valid_id "$id" || die "could not make an id from '$title'"
    for d in $(printf '%s' "$deps" | tr ',' ' '); do resolve "$d" >/dev/null; done
    # Full ids in depends, so the card does not depend on how numbers were typed.
    deps_full=""; for d in $(printf '%s' "$deps" | tr ',' ' '); do r=$(resolve "$d") || exit 1; deps_full="${deps_full:+$deps_full, }$r"; done
    out="$TD/$id.md"
    {
      printf -- '---\nid: %s\ntitle: %s\nstatus: open\nowner: %s\ndepends:%s\nscope: %s\n---\n\n# %s\n\n' \
        "$id" "$title" "$owner" "${deps_full:+ $deps_full}" "$scope" "$title"
      printf '## Goal\n%s\n\n## Done when\n%s\n\n## Read first\n' "${goal:-<What is true when this is done, and for whom.>}" "${done_when:-<A real check: a command that exits 0, or something observable.>}"
      if [ -n "$readf" ]; then printf '%s' "$readf" | tr ',' '\n' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' | grep -v '^$' | sed 's/^/- /'
      else echo "- <3 to 5 paths a fresh session needs>"; fi
      printf '\n## Decisions\n\n## Verified\n\n## Not verified\n\n## Next\n%s\n\n## Log\n- %s created\n' \
        "${next:-<The next concrete step.>}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    } > "$out" || die "could not write $out"
    write_index
    say PASS "new" "docs/tasks/$id.md"
    summary ;;

  check)
    [ -d "$TD" ] || die "no docs/tasks/ in $ROOT"
    n=0
    while IFS= read -r c; do
      n=$((n+1)); stem=$(basename "$c" .md); bad=""
      [ "$(fm "$c" id)" = "$stem" ] || bad="$bad id-does-not-match-file-name"
      for k in title owner scope; do v=$(fm "$c" "$k"); { [ -z "$v" ] || [[ "$v" == *"<"*">"* ]]; } && bad="$bad $k"; done
      case "$(fm "$c" status)" in open|in-progress|blocked|done) ;; *) bad="$bad status(open|in-progress|blocked|done)" ;; esac
      for s in "Goal" "Done when" "Read first" "Next"; do
        body=$(section "$c" "$s"); { [ -z "$body" ] || grep -Eq '^[-[:space:]]*<[^>]*>' <<<"$body"; } && bad="$bad section:$s"
      done
      if [ -n "$bad" ]; then say FAIL "card $stem" "missing or placeholder:$bad"
      else
        rf=$(section "$c" "Read first" | grep -c '^- ')
        if [ "$rf" -lt 3 ] || [ "$rf" -gt 5 ]; then say WARN "card $stem" "complete; Read first has $rf path(s), 3 to 5 keep a fresh session small and sufficient"
        else say PASS "card $stem" "complete"; fi
      fi
    done < <(cards)
    [ $n -gt 0 ] || say WARN "cards" "no cards yet (make them with /dev-harness:split or tasks.sh new)"
    if [ ! -f "$TD/INDEX.md" ]; then say FAIL "INDEX.md" "docs/tasks/INDEX.md is missing"
    elif ! grep -q '<!-- tasks:index:start -->' "$TD/INDEX.md"; then say FAIL "INDEX.md" "no tasks:index markers"
    elif [ "$(index_block)" = "$(index_rows)" ]; then say PASS "INDEX.md" "matches the $n card(s)"
    else say FAIL "INDEX.md" "the table does not match the cards; run: tasks.sh index"; fi
    run_overlap
    summary ;;

  overlap)
    [ -d "$TD" ] || die "no docs/tasks/ in $ROOT"
    run_overlap
    summary ;;

  index)
    [ -d "$TD" ] || die "no docs/tasks/ in $ROOT"
    write_index
    say PASS "index" "docs/tasks/INDEX.md has $(cards | grep -c .) card(s)"
    summary ;;

  active)
    case "${1:-}" in
      "")
        if [ -f "$ACTIVE" ]; then
          id=$(tr -d '\r\n' < "$ACTIVE")
          if valid_id "$id" && [ -f "$TD/$id.md" ]; then echo "$id docs/tasks/$id.md"
          else echo "WARN  active — .claude/active-task names '$id', which is not a card: tasks.sh active --clear" >&2; exit 1; fi
        else echo "none"; fi ;;
      --clear) rm -f "$ACTIVE"; echo "none" ;;
      *)
        id=$(resolve "$1") || exit 1
        mkdir -p "$ROOT/.claude" && printf '%s\n' "$id" > "$ACTIVE" || die "could not write $ACTIVE"
        echo "$id docs/tasks/$id.md"
        if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 && ! git -C "$ROOT" check-ignore -q .claude/active-task; then
          echo "WARN  active — .claude/active-task is not gitignored: add it to .gitignore (it is per worktree, not shared)" >&2
        fi ;;
    esac ;;

  worktree)
    [ -n "${1:-}" ] || die "worktree needs a card id"
    git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not a git repository: $ROOT"
    id=$(resolve "$1") || exit 1; rel="docs/tasks/$id.md"
    git -C "$ROOT" cat-file -e "HEAD:$rel" 2>/dev/null || die "$rel is not committed: the new worktree would not have it. Commit the cards first."
    git -C "$ROOT" diff --quiet HEAD -- "$rel" || die "$rel has uncommitted changes: commit them first, so the worktree gets the same card"
    [ "$(fm "$TD/$id.md" status)" = "done" ] && die "$id is done"
    for d in $(fm "$TD/$id.md" depends | tr ',' ' '); do
      [ "$(fm "$TD/$d.md" status 2>/dev/null)" = "done" ] || die "$id depends on $d, which is not done: they are not parallel. Finish $d first."
    done
    ov=$(overlap_check "$id" | grep '^FAIL')
    [ -z "$ov" ] || { printf '%s\n' "$ov" | sed 's/^FAIL\t[a-z]*\t/FAIL    /' >&2; die "$id is not parallel with the cards above"; }
    branch="task/$id"; top=$(git -C "$ROOT" rev-parse --show-toplevel)
    path="$(dirname "$top")/$(basename "$top")-$id"
    git -C "$ROOT" show-ref --verify -q "refs/heads/$branch" && die "branch $branch already exists"
    [ -e "$path" ] && die "$path already exists"
    git -C "$ROOT" worktree add -q -b "$branch" "$path" HEAD || die "git worktree add failed"
    card="$path/$rel"
    cp "$card" "$card.bak" || die "could not read $card"
    awk -v b="$branch" 'NR==1 {print; next} !done && /^---[[:space:]]*$/ {done=1} !done && /^status:/ {print "status: in-progress"; next}
      !done && /^owner:/ {print "owner: " b; next} {print}' "$card.bak" > "$card" && rm -f "$card.bak"
    TASKS_ROOT="$path" bash "$0" index >/dev/null
    mkdir -p "$path/.claude" && printf '%s\n' "$id" > "$path/.claude/active-task"
    say PASS "worktree" "$path on branch $branch; $id is in-progress and active there (commit the card change on that branch)"
    git -C "$path" check-ignore -q .claude/active-task || say WARN "worktree" ".claude/active-task is not gitignored on this branch"
    echo "Next: cd \"$path\" && claude, then /dev-harness:resume $id"
    summary ;;

  *) die "unknown command '${cmd}'. Use --help." ;;
esac
