---
name: discover
description: Understand a project before building it — who it is for, what they care about, what to deliver, and where to push hardest. A conversation that ends in docs/intent.md. Writes no code.
when_to_use: The user starts a new project, idea, assignment or brief, pastes a context dump, or asks "what should we build?", and docs/intent.md is missing or out of date. Also the first step of /dev-harness:new.
argument-hint: "[idea, brief, assignment text, links or file paths]"
allowed-tools: Read(/${CLAUDE_PLUGIN_ROOT}/skills/discover/intent-template.md) Edit(docs/intent.md)
hooks:
  PreToolUse:
    - matcher: "Edit|Write|NotebookEdit"
      hooks:
        - type: command
          command: "\"${CLAUDE_PLUGIN_ROOT}/skills/discover/discover-lock.sh\""
          timeout: 10
---

Run discovery for this project. Input from the user: $ARGUMENTS

Discovery is a conversation, not a questionnaire. The user often does not yet know what matters most; work it out together. **Do not write code, scaffold, or install anything.** A hook blocks edits to every file except `docs/intent.md` while `docs/intent.md` says `status: discovering`.

## 0. Prepare

- If `docs/intent.md` exists with `status: decided`, show a 5-line summary and ask: refine it, or start over? Refining sets `status: discovering` again until the user decides.
- If `docs/lessons.md` exists, read entries that mention discover, intent, or questions. Use them to ask better questions this time.
- Read what the user gave: text, files, links. If they gave nothing, ask for a context dump: "Paste or point me at anything: the idea, brief, assignment text, links, files."

## 1. Infer

From the context, work out, without asking yet:
- who the user is (role, level, strengths, what they want out of this)
- who receives the work and how they will judge it
- what exactly gets delivered, by when, under which constraints
- the potential: what would make this clearly better than "done"
- the areas worth pushing hardest

Mark each as **stated** (in the context) or **guessed**.

## 2. Reflect back

Write: "Here is what I think this is about:" then 4–8 short bullets, using the user's own words where possible. Put guesses in their own list, labelled as guesses. Then ask **only what is still missing**, at most 3 questions per round, most important first. Interpret the intention behind the words; say so when you read between the lines.

Copy `${CLAUDE_PLUGIN_ROOT}/skills/discover/intent-template.md` to `docs/intent.md` (keep `status: discovering`, set `updated:` to today) and fill what is known. Leave unknown fields as `<...>`. Repeat this step until the user agrees with the picture.

## 3. Brainstorm

Propose 2–3 directions. For each: one-line pitch, what it optimizes for, main cost or risk, and what the receiver would notice. Exactly one is **bold**: more ambitious than the brief asks, still feasible, with the risk named. Recommend one and say why.

## 4. Decide

Let the user pick and adjust: style, focus, what to push hardest, what is out of scope. Use AskUserQuestion when the choice is between listed options. Agree on a **success check**, ideally something that can be run or measured.

## 5. Save

Fill every section of `docs/intent.md`. Set `status: decided` and today's date. Show the final file, then say: "Discovery is done. Next: `/dev-harness:new` to set up the project, or start building."

## Rules

- Scale to the task: a weekend hack needs one round; a graded assignment or client job needs more.
- Never invent requirements. A guess stays labelled as a guess until the user confirms it.
- If the user wants to skip discovery, write what you know with `status: decided` and list the gaps under "Open questions". Say what was skipped.
- If discovery missed something important that came up later, suggest `/dev-harness:lesson` so the next discovery asks it.
