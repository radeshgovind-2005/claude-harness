---
name: showcase
description: Find the most impressive and valuable part of the work and turn it into a demo, a README section and talking points that match docs/intent.md. Every claim is run or read, and labelled, before it is written down. Proposes only; writes the README section only if you say yes.
when_to_use: The user is about to show, hand in, publish or present the work ("what should I demo?", "write the README pitch", "what do I say in the interview?"). Not for reviewing quality: use lens for that.
argument-hint: "[audience or occasion, e.g. 'tutor demo', 'portfolio README', 'interview']"
disable-model-invocation: true
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/showcase-facts.sh *) Bash(git log *) Bash(git status *) Bash(git diff *)
---

Find what to show off in this project. Audience or occasion from the user: $ARGUMENTS

Impressive means it matters to the person who will judge the work, and it demonstrably works. A feature that is large but unproven, or proven but irrelevant to the receiver, loses. **You propose; you change no file in this skill unless the user says yes in step 6.**

## 1. Audience

Read `docs/intent.md` if it exists. Write down, in three lines: who receives the work, what they care about, and what the user said to push hardest on. If the file is missing or says `status: discovering`, say so and state the assumption you are making (from `$ARGUMENTS` or the README). If you cannot name a receiver at all, ask one question before going on.

## 2. Facts

Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/showcase-facts.sh .` and keep its output. Its lines are facts from files and git history, not opinions. A measured gain in `experiment` (baseline to best) is the strongest evidence a project can have; most-changed files show where the effort went; `tests` shows what is protected. A line that says something is missing means it is missing: do not fill it in.

Then read what the facts point at: the README, the entry point, the most-changed source files. Do not review the whole repository.

## 3. Shortlist and pick

List three candidates, each one thing the receiver could see or try. Score each in one line against, in order:

1. **Matters to the receiver** (the `intent.md` text, quoted).
2. **Evidence it works** (a command that can be run, a test, a measured number).
3. **Distinct** (not what every project of this kind has).
4. **Demoable in about 60 seconds.**

Pick one. Say in a sentence why each of the other two lost. If nothing is impressive yet, say that, say what would change it, and stop after step 2: do not dress up a weak project.

## 4. Run the demo

Run the demo steps yourself, for real, in this project: the exact commands the user would type. Run only safe, fast commands (no installs, no network calls to third parties, nothing that deletes or sends); the user is asked to approve each. Capture what each printed.

If a step cannot be run (needs a service, a key, a display), say so and mark everything that depends on it `UNVERIFIED`. Label every claim you intend to make:

- `VERIFIED`: you ran a command and saw the output (quote the command and the relevant line).
- `READ`: you read it in the code or docs (give `file:line`) but did not run it.
- `UNVERIFIED`: anything else, including numbers from memory or from the README that you did not reproduce.

Never write a number, speed, count or "works with X" that is not `VERIFIED` or `READ`. Claims that are `UNVERIFIED` stay out of the README section and the talking points; they go under DO NOT CLAIM.

## 5. Present, in exactly this format

```
PICK: <the one thing, one line>
FOR: <who receives it, and whether that came from docs/intent.md or is an assumption>

WHY:
<2 to 4 lines. Quote the intent text it serves. Why the other two candidates lost.>

DEMO (at most 6 steps, about 60 seconds):
1. <exact command or action>
   You see: <the output you captured, trimmed>
2. ...

README SECTION (draft, not written yet):
<the Markdown, using only VERIFIED and READ claims>

TALKING POINTS:
1. <one sentence> [VERIFIED|READ: command or file:line]
2. ...

DO NOT CLAIM:
- <things that sound good but are UNVERIFIED or false, and why>

NOT VERIFIED:
- <demo steps you could not run, and what you did not check>
```

## 6. Ask, then write

Ask whether to add the README section. If the user says yes:

- If the README has no matching section, add it with the `Edit` tool (Claude Code asks for approval).
- If the README already has a section on the same thing, **never overwrite it**: show a before and after and ask which to keep.
- Change nothing else. Run `git diff` afterwards and show it.

## Rules

- Match the tone to the receiver in `docs/intent.md`: a tutor wants evidence of understanding, a client wants the problem solved, a recruiter wants the one hard thing you did.
- Honest limits make the pitch stronger. If the demo has a known rough edge, put it in DO NOT CLAIM, not in a footnote.
- If a measured gain exists, show the baseline and the result with the command that measured it. Do not round up.
