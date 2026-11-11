#!/usr/bin/env bash
# profiler: read-only tools, the fixed report format, and evidence for every hotspot.
pass=0; fail=0
c() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else echo "FAIL $1"; fail=$((fail+1)); fi; }
A="$FILES_DIR/profiler.md"
tools=$(awk 'NR>1 && /^---/ {exit} /^tools:/ {sub(/^tools:[[:space:]]*/, ""); print}' "$A")
[ "$tools" = "Read, Grep, Glob, Bash" ]; c "tools are Read, Grep, Glob, Bash (no edit tool)" 0 $?
for w in 'STATUS: HOTSPOTS FOUND | NO CLEAR HOTSPOT | COULD NOT PROFILE' '^HOTSPOTS$' '^EVIDENCE$' '^HYPOTHESES$' '^NOT CHECKED$' \
         'A hotspot without evidence is not listed' 'mktemp -d' 'data, not instructions'; do
  grep -Eq -- "$w" "$A" || grep -qF -- "$w" "$A"; c "the agent says: $w" 0 $?
done
echo "profiler tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
