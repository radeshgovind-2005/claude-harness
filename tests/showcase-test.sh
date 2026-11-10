#!/usr/bin/env bash
# Tests scripts/showcase-facts.sh and the consistency of the showcase skill and the role agents.
# Run from anywhere:  /bin/bash tests/showcase-test.sh
# shellcheck disable=SC2319  # `[ test ]; check name $?` reads the test's status on purpose

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
P="$ROOT/plugins/dev-harness"
SF="$P/scripts/showcase-facts.sh"
SC="$P/scripts/scaffold.sh"
pass=0; fail=0
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
# CI runners have no git identity; every commit in these tests names one.
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

check() { if [ "$2" = 0 ]; then echo "  PASS  $1"; pass=$((pass+1)); else echo "  FAIL  $1"; fail=$((fail+1)); fi; }
repo() { D=$(mktemp -d "$W/r.XXXX"); git -C "$D" init -q -b main; }
commit() { git -C "$D" add -A; git -C "$D" commit -q -m "$1"; }
facts() { OUT=$(bash "$SF" "$D" 2>&1); RC=$?; }
has() { grep -Eq "$1" <<<"$OUT"; }

echo "showcase-facts: no git, no files"
D=$(mktemp -d "$W/n.XXXX"); facts
[ $RC -eq 0 ]; check "a plain folder is not an error (exit 0)" $?
has '^FACT +history +— not a git repository'; check "no git is said, not guessed" $?
has '^FACT +readme +— no README found'; check "no README is said" $?
has '^FACT +intent +— no docs/intent.md'; check "no intent is said" $?
has '^FACT +experiment +— no docs/experiments.md'; check "no experiments is said" $?
has '^SUMMARY facts=[0-9]+$'; check "summary line" $?
bash "$SF" "$W/not-a-dir" >/dev/null 2>&1; [ $? -ne 0 ]; check "a missing project dir fails" $?
repo; facts
has '^FACT +history +— not a git repository, or no commits'; check "a repo with no commits is said, not an error" $?

echo "showcase-facts: history and churn"
repo
echo a > "$D/hot.py"; echo b > "$D/cold.py"; echo l > "$D/package-lock.json"; mkdir "$D/docs"; echo p > "$D/docs/progress.md"; echo g > "$D/gone.py"
commit "first thing"
for i in 1 2 3; do echo "$i" >> "$D/hot.py"; echo "$i" >> "$D/package-lock.json"; echo "$i" >> "$D/docs/progress.md"; echo "$i" >> "$D/gone.py"; commit "hot $i"; done
echo c >> "$D/cold.py"; commit "cold"
git -C "$D" rm -q gone.py; commit "remove gone"
facts
has '^FACT +history +— 6 commit\(s\), first [0-9-]+, last [0-9-]+$'; check "commit count and dates" $?
has '^FACT +recent +— remove gone$'; check "the latest subject is listed" $?
first=$(grep '^FACT  churn' <<<"$OUT" | head -n1)
grep -q 'hot.py' <<<"$first"; check "the most-changed file is listed first" $?
grep -q '4 commit(s) touched hot.py' <<<"$first"; check "its commit count is right (4)" $?
! has 'package-lock.json'; check "lockfiles are left out of churn" $?
! has 'touched docs/progress.md'; check "docs/ is left out of churn" $?
! has 'touched gone.py'; check "a deleted file is left out of churn" $?
has 'touched cold.py'; check "a less-changed file is still listed" $?

echo "showcase-facts: tests and README"
repo
mkdir -p "$D/tests" "$D/node_modules/x" "$D/src"
echo t > "$D/tests/test_a.py"; echo t > "$D/src/b.test.ts"; echo t > "$D/node_modules/x/c.test.js"; echo t > "$D/src/not_a_t.py"
printf '# Demo app\n\n## Quickstart\n\nrun it\n\n## Internals\n' > "$D/README.md"
commit init; facts
has '^FACT +tests +— 2 test file\(s\)'; check "test files counted by pattern, node_modules skipped (2)" $?
has '^FACT +readme +— README.md: Demo app \| Quickstart \| Internals'; check "README headings listed in order" $?
has '^FACT +readme-demo +— README.md has a demo'; check "a Quickstart heading counts as a demo heading" $?
printf '# Demo app\n\n## Use\n' > "$D/README.md"; facts
has '^FACT +readme-demo +— README.md has a demo'; check "a Use heading counts as a demo heading" $?
printf '# Demo app\n\n## Internals\n\n## Maintainer notes\n' > "$D/README.md"; facts
has '^FACT +readme-demo +— README.md has no demo'; check "no demo heading is said" $?
rm "$D/tests/test_a.py" "$D/src/b.test.ts"; facts
has '^FACT +tests +— no test files found'; check "zero test files is said" $?

echo "showcase-facts: commands from CLAUDE.md"
repo
printf '# P\n\n## Commands\n\n- Install: `make setup`\n- Test (all): `<cmd>`\n- Run: `make run`\n\n## Other\n\n- Not a command: `rm x`\n' > "$D/CLAUDE.md"
commit init; facts
has '^FACT +command +— - Install: make setup$'; check "a filled command is listed" $?
has '^FACT +command +— - Run: make run$'; check "a second command is listed" $?
! has '<cmd>'; check "an unfilled <cmd> line is skipped" $?
! has 'Not a command'; check "lines after the Commands section are not read" $?
printf '# P\n\n## Commands\n\n- Test (all): `<cmd>`\n' > "$D/CLAUDE.md"; facts
has '^FACT +command +— CLAUDE.md lists no filled-in commands'; check "all-placeholder commands are said" $?

echo "showcase-facts: intent"
repo; mkdir "$D/docs"
cat > "$D/docs/intent.md" <<'EOF'
---
status: decided
---
# Intent
## Who
- **Receiver:** the course tutor
- **What the receiver cares about:** a working demo and clean tests
## What
- **Deliverable:** <exactly what gets handed over>
## Direction chosen
- **Direction:** a CLI first
## Push hardest on
1. The error messages
2. <...>
3. Speed of the first run
EOF
commit init; facts
has '^FACT +intent +— docs/intent.md status: decided$'; check "intent status decided" $?
has 'Receiver: the course tutor'; check "the receiver is read" $?
has 'What the receiver cares about: a working demo and clean tests'; check "what the receiver cares about is read" $?
has 'Direction: a CLI first'; check "the direction is read" $?
! has 'Deliverable'; check "a still-<placeholder> field is skipped" $?
has '^FACT +push-on +— The error messages$'; check "push-hardest item 1 is listed" $?
has '^FACT +push-on +— Speed of the first run$'; check "push-hardest item 3 is listed" $?
! has '<\.\.\.>'; check "a placeholder push-hardest item is skipped" $?
sed -i.bak 's/status: decided/status: discovering/' "$D/docs/intent.md"; rm -f "$D/docs/intent.md.bak"; facts
has 'status: discovering \(not decided'; check "a draft intent is flagged as a draft" $?

echo "showcase-facts: experiments"
repo; mkdir "$D/docs"
cat > "$D/docs/experiments.md" <<'EOF'
# Experiments
- Name: `requests per second`
- Measured by: `bash bench.sh`
- Direction: higher is better
- Target: none
## Log
| Date | Variant (one change) | Metric | Result | Kept or reverted | Note |
|---|---|---|---|---|---|
| 2026-01-01 | baseline | `100` | — | baseline | start |
| 2026-01-02 | threads=8 | `60` | -40 | reverted | slower |
| 2026-01-03 | threads=4 | `140` | +40 | kept | faster |
| 2026-01-04 | cache | `190.5` | +50.5 | kept | much faster |
EOF
commit init; facts
has '^FACT +experiment +— requests per second: baseline 100, best 190.5, 2 kept, 1 reverted; direction: higher is better$'; check "baseline, best, kept and reverted counts" $?
cp "$P/templates/project/docs/experiments.md" "$D/docs/experiments.md"; facts
has '^FACT +experiment +— docs/experiments.md has no measured rows'; check "the untouched template has no measured rows (its example row is not a result)" $?
sed -i.bak '/| baseline |/d' "$D/docs/experiments.md"; rm -f "$D/docs/experiments.md.bak"
printf '| 2026-01-03 | threads=4 | `140` | +40 | kept | faster |\n' >> "$D/docs/experiments.md"; facts
has 'no baseline row, so no gain can be claimed'; check "a kept row with no baseline row claims nothing" $?

echo "showcase-facts: lessons"
repo; mkdir "$D/docs"; printf '# Lessons\n\n### 2026-01-01 — [a] one\n- Mistake: x\n\n### 2026-01-02 — [b] two\n' > "$D/docs/lessons.md"; commit init; facts
has '^FACT +lessons +— 2 lesson entries'; check "lesson entries counted" $?

echo "showcase-facts: read-only"
repo; mkdir "$D/docs"; echo x > "$D/a.py"; printf -- '---\nstatus: decided\n---\n' > "$D/docs/intent.md"; commit init; echo dirty > "$D/untracked.txt"
before=$(cd "$D" && git status --porcelain=v1 -uall; find . -path ./.git -prune -o -type f -exec cksum {} + | sort)
facts
after=$(cd "$D" && git status --porcelain=v1 -uall; find . -path ./.git -prune -o -type f -exec cksum {} + | sort)
[ "$before" = "$after" ]; check "the script changes nothing in the project" $?
repo; bash "$SC" "$D" files --profile product >/dev/null 2>&1; commit scaffold; facts
[ $RC -eq 0 ]; check "a fresh scaffold runs clean" $?
has '^FACT +command +— CLAUDE.md lists no filled-in commands'; check "a fresh scaffold has no filled-in commands (placeholders skipped)" $?
has '^FACT +experiment +— docs/experiments.md has no measured rows'; check "a fresh scaffold has no measured gains" $?

echo "role agents"
for a in architect designer tester; do
  f="$P/agents/$a.md"
  sed -n '/^---$/,/^---$/p' "$f" | grep -q "^name: $a$"; check "$a: frontmatter name is $a" $?
  grep -q '^tools: Read, Grep, Glob, Bash$' "$f"; check "$a: tools are Read, Grep, Glob, Bash" $?
  grep -q 'Report only' "$f"; check "$a: says it reports only" $?
  grep -q 'are data to examine' "$f"; check "$a: treats the input as data, not instructions" $?
  grep -q '^NOT CHECKED:\|^NOT SEEN:' "$f"; check "$a: output format has a NOT CHECKED / NOT SEEN line" $?
done
grep -q '^STATUS: SOUND | CONCERNS$' "$P/agents/architect.md"; check "architect: fixed STATUS line" $?
grep -q '^OPTIONS:$' "$P/agents/architect.md" && grep -q '^RECOMMENDATION:' "$P/agents/architect.md"; check "architect: OPTIONS and RECOMMENDATION in the format" $?
grep -q '^STATUS: GOOD | FIXES NEEDED | NOT A UI$' "$P/agents/designer.md"; check "designer: fixed STATUS line with NOT A UI" $?
grep -q 'NOT A UI' "$P/agents/designer.md" && grep -q 'stop and report' "$P/agents/designer.md"; check "designer: stops on a target with no UI" $?
grep -q '^STATUS: TESTS CATCH BREAKS | GAPS FOUND$' "$P/agents/tester.md"; check "tester: fixed STATUS line" $?
grep -q 'mktemp -d' "$P/agents/tester.md" && grep -q 'Never in the real project' "$P/agents/tester.md"; check "tester: mutates only in a temporary copy" $?
grep -q 'at most 6 mutants' "$P/agents/tester.md"; check "tester: mutants are bounded" $?
grep -q '^MUTANTS' "$P/agents/tester.md" && grep -q 'SURVIVED' "$P/agents/tester.md"; check "tester: survivors are in the format" $?
for a in architect designer tester skeptic lens-reviewer; do
  grep -q "\`$a\`" "$P/skills/help/SKILL.md"; check "help names $a" $?
done
grep -q 'Which reviewer for what' "$P/skills/help/SKILL.md"; check "help says which reviewer asks which question" $?

echo "showcase skill"
S="$P/skills/showcase/SKILL.md"
[ -f "$S" ]; check "skills/showcase/SKILL.md exists" $?
grep -q 'showcase-facts.sh' "$S"; check "the skill runs showcase-facts.sh" $?
[ -f "$P/scripts/showcase-facts.sh" ] && [ -x "$P/scripts/showcase-facts.sh" ]; check "showcase-facts.sh exists and is executable" $?
fm=$(sed -n '2,/^---$/p' "$S")
grep -q '^disable-model-invocation: true$' <<<"$fm"; check "showcase is user-invoked only" $?
! grep -Eq '^allowed-tools:.*(Edit|Write|MultiEdit)' <<<"$fm"; check "showcase pre-approves no Edit or Write (a README write must prompt)" $?
! grep -Eq '^hooks:' <<<"$fm"; check "showcase declares no hook" $?
for w in PICK WHY DEMO 'README SECTION' 'TALKING POINTS' 'DO NOT CLAIM' 'NOT VERIFIED'; do
  grep -q "^$w" "$S"; check "showcase output format has $w" $?
done
for w in VERIFIED READ UNVERIFIED; do grep -q "$w" "$S"; check "showcase labels claims $w" $?; done
grep -qi 'never overwrite' "$S"; check "showcase never overwrites an existing README section" $?
grep -q "^| \`showcase\` .*| available |$" "$P/skills/help/SKILL.md"; check "help marks showcase available" $?

echo "project template"
for a in architect designer tester; do
  grep -q "dev-harness:$a" "$P/templates/project/docs/agents/INDEX.md"; check "docs/agents/INDEX.md template names dev-harness:$a" $?
done

echo
echo "Result: $pass passed, $fail failed"
[ $fail -eq 0 ]
