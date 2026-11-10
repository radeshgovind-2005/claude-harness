---
name: lens
description: Review a piece of work from three angles in fresh context - UX (the person who uses it), DX (the next developer) and AX (an AI agent working in the project) - and return one ranked list of findings with evidence. Reports only; changes nothing.
when_to_use: The user wants the work looked at from outside before showing it, shipping it, or handing it over ("review the onboarding flow", "is this ready to show?").
argument-hint: "[path, feature or flow to review; default: the current changes]"
disable-model-invocation: true
allowed-tools: Read(/${CLAUDE_PLUGIN_ROOT}/skills/lens/angles.md) Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/ax-check.sh *) Bash(git diff *) Bash(git status *)
---

Review this from three angles. Target from the user: $ARGUMENTS

You coordinate. The reviewing is done by three fresh-context agents, one per angle, so no angle is graded by the conversation that built the work. **You change nothing in the project.**

## 1. Target and audience

- Target: the argument (a path, feature or flow). If it is empty, use the current changes (`git status`, `git diff`); if there are none, ask what to review. Do not review the whole repository by default.
- Snapshot: run `git status --short -uall` and keep the output. (`-uall` lists every untracked file, so edits inside untracked folders show up too.)
- Audience: read `docs/intent.md` if it exists and write a 3-line summary of who the work is for, what they care about, and what the chosen direction is. If it does not exist, say so; the reviewers will state their assumption.

## 2. Facts for the AX reviewer

Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ax-check.sh .` and keep its full output. It is a script, so its PASS, WARN and FAIL lines are facts, not opinions.

## 3. Start three reviewers in ONE message

Read `${CLAUDE_PLUGIN_ROOT}/skills/lens/angles.md`. Then call the Agent tool **three times in the same message**, with `subagent_type: "dev-harness:lens-reviewer"`, one call per angle. Each prompt contains only:

- `ANGLE:` UX, DX or AX
- `TARGET:` the target from step 1 (for a diff, tell it to run `git diff` itself)
- `CHECKLIST:` the matching block from `angles.md`, verbatim
- The audience summary from step 1
- For AX only: the `ax-check.sh` output

Do not include your own opinion of the work, what you built, or why. A reviewer that is told the answer will confirm it.

## 4. Fan-in, then synthesize

1. **Count.** Three reviewers started; how many returned a report in the fixed format? Name any that failed or returned nothing. Never fill in a missing angle from your own judgment: write "AX: no report" and offer to rerun it.
2. **Merge.** Remove duplicates (the same problem found from two angles becomes one finding, tagged with both). Keep each finding's evidence. Drop any finding that has no evidence and say how many you dropped.
3. **Rank** by severity, then by how many angles hit it.
4. **Present:**
   - the fan-in line (`3 of 3 reviewers returned`) and the `ax-check` summary line
   - the top findings, most severe first: angle(s), `file:line` or command, what they experience, evidence, fix idea
   - per-angle sections with the remaining findings and the "nothing found for" items
   - **Not checked**: everything the reviewers listed, plus what you did not send them
5. Ask what the user wants fixed. Do not fix anything yourself in this skill.

## Rules

- Reviewers can run commands and, through `Bash`, could still write; they are told not to. After the reviewers finish, run `git status --short -uall` again and compare it with the snapshot from step 1. Report any difference. It cannot show a change to a file that was already modified before the review, so say that when the tree was not clean at the start.
- If `docs/intent.md` says a direction or priority, a finding that the work ignores it is high severity.
- Scale to the target: one function does not need all three angles. If an angle is irrelevant (for example UX for an internal script with no users), say so and run only the others, with the count stated.
