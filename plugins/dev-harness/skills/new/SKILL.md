---
name: new
description: Full project setup — runs discover, picks a profile (prototype, product, assignment), and scaffolds CLAUDE.md, docs and guardrail hooks into the project. Never overwrites existing files.
argument-hint: "[idea or brief] [--profile prototype|product|assignment]"
disable-model-invocation: true
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/scaffold.sh *) Bash(git status *) Bash(git branch *) Bash(git rev-parse *)
---

Set up this project with dev-harness. Input from the user: $ARGUMENTS

Work in the current project directory. Scaffolding is done by one script; never copy template files by hand:

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/scaffold.sh <dir> files      --profile <p> [--dry-run]
bash ${CLAUDE_PLUGIN_ROOT}/scripts/scaffold.sh <dir> guardrails --profile <p> [--verify-cmd "<cmd>"] [--merge-settings] [--dry-run]
```

The script never overwrites; it prints `add`, `skip`, `merge`, `update`, `ok` or `FAIL` per path.

## Steps

1. **Intent.** If `docs/intent.md` is missing or has `status: discovering`, run discovery first: invoke the `dev-harness:discover` skill with the user's input, and finish it (`status: decided`) before step 2. If it already says `status: decided`, summarize it in 3 lines and continue.

2. **Profile.** If `--profile` was given, use it. Otherwise ask with AskUserQuestion, recommending one based on the intent:
   - **prototype**: speed and learning; edits on `main` allowed; no stop check.
   - **product**: real users or a team; `main` is blocked, stop check runs typecheck and lint, `git push` asks first, plan mode and review required.
   - **assignment**: graded or learning work; Claude explains each step; stop check runs the tests.
   Force push, `--no-verify`, reading `.env`, `rm -rf /` and `curl | sh` are blocked in every profile.

3. **Git.** Run `git rev-parse --is-inside-work-tree`. If this is not a repo, offer `git init -b main` (ask first). For **product** on `main` or `master`: offer `git switch -c chore/dev-harness-setup` before anything is written. Once the guardrails land, edits on `main` are blocked immediately in this session.

4. **Verify command.** Look at `package.json` scripts, `pyproject.toml`, `Makefile`, `Cargo.toml`, `go.mod`. Propose a fast `VERIFY_CMD` (under 60 s): product = typecheck + lint, assignment = tests, prototype = empty. Pass it with `--verify-cmd` (an empty one too: `--verify-cmd ""`). Without the flag, `scaffold.sh` detects one itself and reports it as a `note`; that is only a fallback. No profile ships a default. Ask the user to confirm or change it. If there is no code yet, propose empty and say it can be set later in `.claude/hooks/harness.conf` (only the user edits that file; Claude's edits are blocked and shell changes ask first).

5. **Files.** Run the `files` phase. Then fill the `<placeholders>` in `CLAUDE.md` from `docs/intent.md` and the repo: name and one-line purpose, stack, one project-specific critical rule, commands you can confirm exist (leave `<cmd>` for unknown ones and say so). If `CLAUDE.md` was skipped because it existed, show the user what the dev-harness version adds and ask before merging; keep their content and stay under 100 lines.

6. **Guardrails.** Run the `guardrails` phase with `--dry-run` first and show the output. If `.claude/settings.json` exists, the dry run prints the proposed merge; ask before rerunning with `--merge-settings`. On a yes, run it for real. This phase must be last: hooks take effect as soon as `.claude/settings.json` is written.

7. **Report.** List what was added, skipped and merged; the hook test result line; the profile and `VERIFY_CMD`. Then say what is NOT done:
   - Commit the setup (ask first).
   - Turn on branch protection and require the `dev-harness-hooks` CI check on the Git host. Local hooks stop mistakes, not deliberate bypass.
   - Any `<cmd>` placeholders left in `CLAUDE.md`.
   - The `permissions.allow` rules in `.claude/settings.json` apply only after the user trusts this folder (Claude Code's trust dialog). Hooks, `deny` and `ask` rules apply right away.

## Rules

- If any script line says `FAIL`, stop and report it. Do not say the setup is done.
- Never edit `.claude/hooks/*` or `.claude/settings.json` by hand; rerun the script or tell the user what to change.
- Do not write application code in this skill.
