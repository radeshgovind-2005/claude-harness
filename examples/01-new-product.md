# `new` on a project with a decided intent (product profile)

- Plugin version: 1.0.0
- Date: 2026-11-10
- Command: `/dev-harness:new --profile product ... (intent decided, VERIFY_CMD confirmed in the prompt)`
- How it was run: headless `claude -p` with `--plugin-dir`. A headless run cannot answer prompts or approve tools, so the confirmations are in the prompt and the tools are passed with `--allowedTools`.
- Project: a toy Node project (`reading-list`) with `package.json` and a decided `docs/intent.md`, on the branch `chore/dev-harness-setup`.

Shows what `new` writes, what it reports as not done, and what `ax-check.sh` says about the result. The `typecheck`, `lint` and `test` scripts in this toy project are `echo` stubs, and Claude said so in its report.

Trimmed: one line about the folder trust dialog was removed from the output, and absolute paths were shortened (`<scratch>`, `~`). Nothing else was edited.

## What Claude reported

```
The dev-harness setup is in place with the `product` profile on `chore/dev-harness-setup`. The script reported no `FAIL` lines, and the hook tests passed (172 passed, 0 failed). Nothing is committed.

**Added**
- `CLAUDE.md`, `.claude/rules/example-api.md`, and `docs/` (`INDEX`, `architecture`, `conventions`, `experiments`, `lessons`, `progress`, `workflow`, `agents/INDEX`, `agents/first-workflow`)
- Guardrails: `.claude/hooks/` (`format.sh`, `guard-bash.sh`, `protect-paths.sh`, `test-hooks.sh`, `verify.sh`, `harness.conf`), `.claude/settings.json`, `.github/workflows/dev-harness-hooks.yml`

**Merged or updated**
- `.gitignore` gained `CLAUDE.local.md` and `.claude/settings.local.json`.

**Skipped**
- Nothing was skipped for the files phase. In the guardrails phase, the `.gitignore` entry for `.claude/settings.local.json` already existed. There was no existing `settings.json`, so nothing needed merging.

**Settings**
- Profile is `product`.
- `VERIFY_CMD="npm run typecheck && npm run lint"`, set in `.claude/hooks/harness.conf`.

**`CLAUDE.md`**
- I filled in the name, purpose and stack (Node, one JSON file, no database).
- I added two project rules:
  - Every user-facing error must say what went wrong and what to do next.
  - Keep it a plain CLI with no server and no database.
- I filled the install, test, lint and typecheck commands from `package.json`.
- Dev server reads "none (CLI, no server)".
- **`Test (one file)` is still `<cmd> <path>`.** There is no single-file test runner yet; set it once you pick one.

**Not done**
- **Commit:** Nothing is committed. Tell me when you want the setup committed.
- **Branch protection:** Turn it on and require the `dev-harness-hooks` CI check on your Git host. Local hooks stop mistakes, not deliberate bypass.
- **Trust dialog:** The `permissions.allow` rules in `.claude/settings.json` apply only after you trust this folder in Claude Code's trust dialog. Hooks, `deny` and `ask` rules apply right away.
- **Stub scripts:** `typecheck`, `lint` and `test` are `echo` stubs in `package.json`, so the stop check passes without checking anything. Swap in real commands once code exists.
```


## The project afterwards

```
$ find . -type f -not -path "./.git/*" | sort
./.claude/hooks/format.sh
./.claude/hooks/guard-bash.sh
./.claude/hooks/harness.conf
./.claude/hooks/protect-paths.sh
./.claude/hooks/test-hooks.sh
./.claude/hooks/verify.sh
./.claude/rules/example-api.md
./.claude/settings.json
./.github/workflows/dev-harness-hooks.yml
./.gitignore
./CLAUDE.md
./docs/agents/first-workflow.md
./docs/agents/INDEX.md
./docs/architecture.md
./docs/conventions.md
./docs/experiments.md
./docs/INDEX.md
./docs/intent.md
./docs/lessons.md
./docs/progress.md
./docs/workflow.md
./package.json

$ bash ax-check.sh .
PASS  CLAUDE.md length — 73 lines (limit 100)
PASS  routed paths exist — 10 path(s) in CLAUDE.md checked
WARN  CLAUDE.md placeholders — 1 line(s) still have <placeholders>: an agent cannot run '<cmd>'
PASS  hooks registered — 4 hook script(s) exist and are executable
PASS  harness.conf profile — product
PASS  VERIFY_CMD — set: npm run typecheck && npm run lint
PASS  docs/intent.md — status: decided
PASS  docs/progress.md — present
PASS  docs/lessons.md — present
SUMMARY pass=8 warn=1 fail=0

$ cat .claude/hooks/harness.conf (comment lines removed)
PROFILE=product
BLOCK_MAIN=1
VERIFY_CMD="npm run typecheck && npm run lint"

$ head -n 16 CLAUDE.md
# Project

- Name: reading-list — a small CLI (`rl add`, `rl list`, `rl done`) to add books in one command and find them again
- Stack: Node, no framework, no database (one JSON file)
- Profile: product (set by dev-harness; guardrails in `.claude/hooks/harness.conf`)
- Intent: `docs/intent.md` (who it is for, what matters, chosen direction). Read it before planning.

## Critical Rules

- IMPORTANT: Never commit secrets. Use env vars. Write the variable name, never the value.
- YOU MUST complete the Verification checklist before you say a task is done.
- YOU MUST make every user-facing error say what went wrong and what to do next (clear errors are the top priority in `docs/intent.md`).
- Keep it a plain CLI with one JSON store: no server, no database.

## Working Principles
```

