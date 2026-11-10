# claude-harness

- Name: claude-harness, a Claude Code plugin marketplace with one plugin, `dev-harness` (skills, agents, scaffolding scripts, project templates).
- Stack: bash 3.2-compatible scripts, Markdown skills and agents, JSON manifests. No build step.
- Plugin version lives ONLY in `plugins/dev-harness/.claude-plugin/plugin.json`. The top `## x.y.z` in `CHANGELOG.md` must equal it.

## Critical Rules

- IMPORTANT: Never commit secrets. Never push, create a release or delete files without asking the user. (These two rules are text only: this repository has no guardrail hooks, and CI checks manifests, docs and scripts, not secrets or pushes.)
- YOU MUST run the suites below before you say a change is done, and say which you ran.
- The plugin ships NO always-on hooks. Strict hooks live in `plugins/dev-harness/templates/` and are copied into projects that opt in. Only `discover` and `goal` may declare a skill-frontmatter hook, and each must be state-gated.
- Agents list `tools:` explicitly and never include an edit tool (`Bash` can still write; say so honestly).

## Commands

- Validate manifests, layout, help vs reality: `bash tests/validate.sh`
- Scaffold and project hook tests (about 4 min, run in the background): `/bin/bash tests/scaffold-test.sh`
- One suite: `/bin/bash tests/explore-test.sh` (also `lens-test.sh`, `goal-test.sh`, `showcase-test.sh`)
- Docs, examples, links, versions, line endings, icon (run after any change to README, `docs/` or `examples/`): `/bin/bash tests/docs-test.sh`
- Everything, one summary (`--fast` skips the 4-minute scaffold suite and says so): `/bin/bash tests/run-all.sh`
- Shell lint: `shellcheck -S warning <script>`
- Try the plugin from source: `claude --plugin-dir ./plugins/dev-harness`

## Layout

- `plugins/dev-harness/skills/<name>/SKILL.md`: one folder per skill (kebab-case, exact-case `SKILL.md`).
- `plugins/dev-harness/agents/<name>.md`: read-only reviewers.
- `plugins/dev-harness/scripts/`: `scaffold.sh`, `explore.sh`, `goal.sh`, `ax-check.sh`, `showcase-facts.sh`, `lib.sh`.
- `plugins/dev-harness/templates/`: copied INTO projects (router, docs, hooks, CI). Never loaded by Claude Code.
- `tests/`: one suite per area. `docs/`: user and contributor docs.

## Gotchas (each cost a debugging session)

- macOS bash 3.2: no `;;&`, no `timeout`, no associative arrays; a `case` arm containing `$( ... )` with `)` is misparsed. Test scripts with `/bin/bash`.
- `sort` is locale-dependent: use `LC_ALL=C` in tests that compare file lists.
- zsh (the tool shell) does not word-split unquoted variables; a `d=$(fn)` helper runs in a subshell, so a `cd` inside it does not persist.
- Never `rm -rf "$VAR"` in tool calls (the author's own Claude Code setup blocks it; this repository does not). Use fresh `mktemp -d` dirs.
- CI runners have no git identity: a test that commits through the code under test must export `GIT_AUTHOR_*` and `GIT_COMMITTER_*`.
- `allowed-tools` Read rules for plugin files need `Read(/${CLAUDE_PLUGIN_ROOT}/...)` (extra slash). Never pre-approve a command that installs something a hook or script runs later.
- Skill-frontmatter hooks stay registered for the rest of the session and are not re-registered after `--continue`. `CLAUDE_PLUGIN_DATA` is not set in hook processes under `--plugin-dir`.
- Headless `claude -p` cannot answer `AskUserQuestion` or approve tools: pass `--allowedTools` and put the confirmation in the prompt.
- `grep` test output with `^  FAIL`. Run mutation mutants one at a time.

## Routing

| If the task is…                              | Read first            |
|----------------------------------------------|-----------------------|
| Adding or changing a skill, agent or script  | `docs/contributing.md` |
| How the pieces fit, what is code vs text     | `docs/how-it-works.md` |
| What must not change in 1.x                  | `docs/stability.md`    |
| What a skill or agent does, its output       | `docs/reference.md`    |
| Resuming work, what was verified             | `docs/progress.md`     |
| Why it is designed this way                  | `docs/brief.md`        |
| What shipped when                            | `CHANGELOG.md`         |

## Verification (Definition of Done)

- [ ] `bash tests/validate.sh` passes, and the suite for the area you changed passes (name them)
- [ ] `shellcheck -S warning` is clean on every script you touched
- [ ] A new check was proven to fail with a broken copy (mutation), not only to pass
- [ ] CHANGELOG and `docs/progress.md` say what was and was not verified
- [ ] Non-trivial change: `dev-harness:skeptic` reviewed `git diff main..<branch>` in fresh context
