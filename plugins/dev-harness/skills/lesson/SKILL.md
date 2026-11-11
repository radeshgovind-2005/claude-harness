---
name: lesson
description: Record a correction as a lesson in docs/lessons.md so the mistake does not repeat. Updates a similar lesson instead of adding a duplicate, and asks before promoting a rule to CLAUDE.md.
when_to_use: The user corrects Claude ("no, that's wrong", "you should have…", "don't do X again"), or discovery missed something that mattered. Do not use it for ordinary feedback on a draft or a one-off preference.
argument-hint: "[what went wrong]"
allowed-tools: Edit(docs/lessons.md) Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/scaffold.sh *)
---

Record a lesson from this correction: $ARGUMENTS

If the argument is empty, use the most recent correction in this conversation. If there is none, ask what went wrong and stop.

## Steps

1. **File.** Work in the current project. If `docs/lessons.md` is missing, create it with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/scaffold.sh . files --part lessons` (it never overwrites). If `docs/intent.md` says `status: discovering`, the discover lock blocks this edit: say so and ask the user to finish discovery first. If a hook blocks the edit for another reason (for example the product profile on `main`), report that and stop. Do not write the file with a shell command to get around it.

2. **Look for a similar lesson.** Read `docs/lessons.md`. A lesson is similar if it has the same root cause or would be prevented by the same rule, even if the words differ. If one exists, **update it in place**: sharpen the rule, add the new case to "Mistake", and change its date to today. Do not add a second entry. Say that you updated an existing lesson. The same mistake twice means text is not enough: suggest `/dev-harness:forge` and name the likely part (a hook if the rule must never break, a skill for a procedure, an agent for a review, a path-scoped rule for one folder). Suggest only; do not start it.

3. **Otherwise add one entry** at the top of "Entries", in this format:

   ```
   ### YYYY-MM-DD — [tag] short title
   - Mistake: <what went wrong, one line>
   - Rule: <one imperative rule that prevents it>
   ```

   - The rule must be specific and checkable. "Be careful" and "double-check" are not rules. "Run `npm test` from the repo root, not from `src/`" is.
   - `[tag]` is one lowercase word for the area: `discover`, `tests`, `git`, `api`, `ui`, … Use **`[discover]`** when the lesson is about the discovery process itself (a question that should have been asked, a wrong guess about who the work is for, a context the user had to repeat). `discover` reads those first, so the next discovery asks better questions.
   - Keep each entry to 3 lines. Write the mistake as what happened, not who was at fault.
   - If the only other entry is the template's placeholder (`Example: silent skip`, dated 2026-01-01), remove that placeholder.

4. **Show the entry** you wrote or updated, and whether it is new or an update.

5. **Promote only with permission.** If the rule applies to every task in this project (not one area), ask with AskUserQuestion whether to add it to `CLAUDE.md`. Say which section it would go in and what it would replace if the file is near 100 lines. Do not edit `CLAUDE.md` without a yes. After a yes, keep `CLAUDE.md` under 100 lines and note "Promoted to CLAUDE.md" on the lesson. If the answer is no, leave it.

6. **Prune.** If you notice a lesson that a hook, a test or CI now prevents, suggest deleting it. Do not delete it without asking.

## Rules

- One correction, one entry. Do not bundle several corrections into one lesson.
- Do not record guesses about why Claude made the mistake. Record what happened and the rule.
- Do not write lessons into `CLAUDE.md` directly.
