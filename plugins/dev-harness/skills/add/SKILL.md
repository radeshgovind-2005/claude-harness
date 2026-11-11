---
name: add
description: Add one part of dev-harness to an existing project — guardrails, reviewer, lessons, memory, workflows, rules, or all. Never overwrites existing files.
argument-hint: "<guardrails|reviewer|lessons|memory|workflows|rules|all> [--profile prototype|product|assignment]"
disable-model-invocation: true
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/scaffold.sh *) Bash(git status *) Bash(git branch *) Bash(git rev-parse *)
---

Add one part of dev-harness to this project. Input from the user: $ARGUMENTS

Work in the current project directory. Scaffolding is done by one script; never copy template files by hand:

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/scaffold.sh <dir> files      [--part <memory|lessons|reviewer|workflows|rules>] [--profile <p>] [--dry-run]
bash ${CLAUDE_PLUGIN_ROOT}/scripts/scaffold.sh <dir> guardrails --profile <p> [--verify-cmd "<cmd>"] [--merge-settings] [--dry-run]
```

The script never overwrites; it prints `add`, `skip`, `merge`, `update`, `ok` or `FAIL` per path.

## Parts

| Part | Adds | Script call | Needs a profile |
|---|---|---|---|
| `memory` | `CLAUDE.md` router, `docs/` (INDEX, architecture, conventions, lessons, progress, experiments) | `files --part memory` | yes |
| `lessons` | `docs/lessons.md` (used by `/dev-harness:lesson`) | `files --part lessons` | no |
| `reviewer` | `docs/agents/INDEX.md`: how to use `dev-harness:skeptic` and when delegation pays | `files --part reviewer` | no |
| `workflows` | `docs/workflow.md`, `docs/agents/first-workflow.md` | `files --part workflows` | no |
| `rules` | `.claude/rules/` (path-scoped example) | `files --part rules` | no |
| `guardrails` | hooks, `harness.conf`, `.claude/settings.json`, CI workflow, then runs the hook tests | `guardrails` | yes |
| `all` | every `files` part, then `guardrails` last | `files`, then `guardrails` | yes |

The `dev-harness:skeptic` agent ships with the plugin, so `reviewer` adds only the guide to it.

## Steps

1. **Part.** Take the part from the first word of the input. If it is missing or not in the table, show the table and ask which part. Do not guess.

2. **Profile** (only for `memory`, `guardrails` and `all`). In this order: `--profile` from the input; `PROFILE=` in `.claude/hooks/harness.conf`; `- Profile:` in `CLAUDE.md`; otherwise ask with AskUserQuestion (prototype, product, assignment; see `/dev-harness:help` for what each changes) and recommend one from `docs/intent.md` if it exists. If the project already has a profile and the user names a different one, say so and ask which is meant. Never switch a project's profile silently.

3. **Git.** For `guardrails` and `all`: run `git rev-parse --is-inside-work-tree`. If this is not a repo, offer `git init -b main` (ask first). For **product** on `main` or `master`: offer `git switch -c chore/dev-harness-setup` before anything is written. Once the guardrails land, edits on `main` are blocked immediately in this session.

4. **Verify command** (only for `guardrails` and `all`). If `.claude/hooks/harness.conf` exists, leave it. Otherwise follow step 4 of `/dev-harness:new`: look for `package.json` scripts, `pyproject.toml`, `Makefile`, `Cargo.toml`, `go.mod`; propose a fast `VERIFY_CMD` (product = typecheck + lint, assignment = tests, prototype = empty); ask the user to confirm. Pass it with `--verify-cmd`; without the flag `scaffold.sh` falls back to its own detection and reports it as a `note`.

5. **Dry run, then write.** Run the script with `--dry-run` first and show the output. Then run it for real. For `all`, run `files` first and `guardrails` last: hooks take effect as soon as `.claude/settings.json` is written. For `guardrails` and `all`, if `.claude/settings.json` exists the dry run prints a proposed merge; ask before rerunning with `--merge-settings`.

6. **CLAUDE.md.**
   - If `memory` or `all` created it, fill the `<placeholders>` from `docs/intent.md` and the repo: name and one-line purpose, stack, one project-specific critical rule, and the commands you can confirm exist. Leave `<cmd>` for unknown ones and say so.
   - If `CLAUDE.md` already existed, the script skipped it. Check it against the template and list what it lacks: the routing rows for `docs/progress.md`, `docs/experiments.md` and `docs/lessons.md`, and the checklist line that names `dev-harness:skeptic`. Show the lines and ask before adding them. Keep the user's content and keep the file under 100 lines.

7. **Report.** List what was added, skipped and merged, and for guardrails the hook test result line, the profile and `VERIFY_CMD`. Then say what is NOT done:
   - Commit the change (ask first).
   - For `guardrails` and `all`: turn on branch protection and require the `dev-harness-hooks` CI check on the Git host. Local hooks stop mistakes, not deliberate bypass. The `permissions.allow` rules apply only after the user trusts this folder; hooks, `deny` and `ask` rules apply right away.
   - For `reviewer` and `all`: the skeptic needs the dev-harness plugin installed wherever the project is used.
   - Any `<cmd>` placeholders left in `CLAUDE.md`.
   - Any `note` line from the script: `memory` writes a router that points to `docs/workflow.md`, `docs/agents/first-workflow.md` and `docs/agents/INDEX.md`, which only `workflows` and `reviewer` add. Name the missing files and the part that adds each, and offer to add them.

## Rules

- If any script line says `FAIL`, stop and report it. Do not say the part was added.
- Never edit `.claude/hooks/*` or `.claude/settings.json` by hand; rerun the script or tell the user what to change.
- If the user asks for something that is not a part (for example `explore` or `lens`), say it is not an `add` part, and which version brings it (see `/dev-harness:help`).
- Do not write application code in this skill.
