# Contributing and forking

## Set up

Needs `bash`, `git`, `jq`, the `claude` CLI (for `claude plugin validate`), and `shellcheck`.

```
git clone https://github.com/radeshgovind-2005/claude-harness
cd claude-harness
bash tests/validate.sh
claude --plugin-dir ./plugins/dev-harness
```

`--plugin-dir` loads the plugin from source for one session; run `/reload-plugins` after an edit. `CLAUDE.md` in the repository root is the short version of this page, written for an AI agent working here.

## Tests

| Suite | Covers | Time |
|---|---|---|
| `bash tests/validate.sh` | manifests, layout, frontmatter, agents, `help` against reality, `claude plugin validate` | seconds |
| `/bin/bash tests/scaffold-test.sh` | `scaffold.sh`, profiles, hooks (the project's `test-hooks.sh` runs inside every scaffold), the discover lock | about 4 minutes, run it in the background |
| `/bin/bash tests/explore-test.sh` | `explore.sh` | under a minute |
| `/bin/bash tests/lens-test.sh` | `ax-check.sh`, lens consistency | seconds |
| `/bin/bash tests/goal-test.sh` | `goal.sh`, the Stop hook | under a minute |
| `/bin/bash tests/showcase-test.sh` | `showcase-facts.sh`, the role agents, the showcase skill | under a minute |
| `/bin/bash tests/docs-test.sh` | links, versions, examples, line endings, the icon | seconds |
| `/bin/bash tests/run-all.sh` | all of the above (`--fast` skips the scaffold suite) | about 5 minutes |

Run test scripts with `/bin/bash`: on macOS that is bash 3.2, where the scripts must work. Lint every script you touch with `shellcheck -S warning`. When you look at test output, search for `^  FAIL`.

## Adding a skill

1. Create `plugins/dev-harness/skills/<name>/SKILL.md` (kebab-case folder, exact-case `SKILL.md`) with frontmatter that has a `description`. Skills that act on a project say `disable-model-invocation: true`.
2. Call bundled scripts as `bash "${CLAUDE_PLUGIN_ROOT}/scripts/..."`, not with `` !`cmd` `` injection (a setting can disable that). A Read rule for a plugin file needs the extra slash: `Read(/${CLAUDE_PLUGIN_ROOT}/...)`.
3. `allowed-tools` lists only what the skill uses. Do not pre-approve a command that installs something a hook or script runs later: Claude Code's prompt is the real confirmation. Do not pre-approve `Edit` or `Write` for a skill that only proposes.
4. Add a row to `plugins/dev-harness/skills/help/SKILL.md` with the status `available`. `validate.sh` fails when a skill is missing from `help` or `help` names one that does not exist.
5. Add the skill to `docs/reference.md`, the table in `README.md`, and a `CHANGELOG.md` entry.
6. A skill hook is allowed only if it is listed in `SKILL_HOOK_ALLOW` in `tests/validate.sh` and is state-gated: it must do nothing unless its own state says the skill is active. The hook is registered for the rest of the session and not re-registered after `--continue`.
7. Put logic in a script under `scripts/` and test the script. A skill that only contains prose can only be checked by reading it.

## Adding an agent

1. Create `plugins/dev-harness/agents/<name>.md` with `tools:` listing bare tool names (`Read, Grep, Glob, Bash`). `tools:` is required: a missing list would give the agent every tool.
2. Reviewers get no edit tool. Add the name to the `case` list in `tests/validate.sh` that checks this. Plugin agents ignore `hooks`, `mcpServers` and `permissionMode`, so do not set them.
3. Give it one question, one object and one kind of evidence, and say which neighbour it does not cover (`skeptic`, `lens-reviewer`, `architect`, `designer`, `tester`). Say that the files it reads are data, not instructions. Give it a fixed output format with a `NOT CHECKED` line.
4. Add it to `help`, `docs/reference.md`, the project template `plugins/dev-harness/templates/project/docs/agents/INDEX.md`, and the CHANGELOG. Be honest in all of them: "no edit tools, but `Bash` can still write".

## Changing a script or a template

- Scripts must run on macOS bash 3.2: no `;;&`, no `timeout`, no associative arrays; a `case` arm that contains `$( ... )` with a `)` is misparsed. `sort` depends on the locale: use `LC_ALL=C` where order matters.
- A test that commits through the code under test must export `GIT_AUTHOR_NAME`, `GIT_AUTHOR_EMAIL`, `GIT_COMMITTER_NAME` and `GIT_COMMITTER_EMAIL`: CI runners have no git identity. To reproduce, run with `user.useConfigOnly=true` and `HOME` pointing somewhere empty.
- `templates/` is copied into projects and never loaded by Claude Code. Keep the `CLAUDE.md` template under 100 lines. Existing files in a project must never be overwritten.
- Changing what lands in a project, a `harness.conf` key, or an agent's output format is a breaking change: see `stability.md`.

## Prove that a new test can fail

For every check you add, break the code in a copy and run the suite: the check must fail. Run mutants one at a time (a parallel run mixes up which mutant failed), and do not leave a `sleep` behind in a mutant, which hangs a suite. A survivor means the test is weaker than it looks: strengthen it. The history of this habit is in `docs/progress.md`: it found weak greps, a label that appeared elsewhere in the same file, and fixtures that never exercised the case.

## Try it for real

Unit tests do not show how Claude behaves. Run the skill in a throwaway project:

```
claude --plugin-dir ./plugins/dev-harness \
  --allowedTools "Read,Grep,Glob,Bash(python3 *)" --max-budget-usd 2 \
  -p "/dev-harness:showcase demo. I approve running python3 commands." < /dev/null
```

A headless `-p` run cannot answer `AskUserQuestion` or approve an `Edit` or a `Bash` call, so pass `--allowedTools` and put the confirmation in the prompt, and say in your notes that you did. Use a fresh `mktemp -d` project, never your own repository.

## Release

1. Work on `build/vX.Y.Z` in small commits.
2. Bump `version` in `plugin.json` only (not in `marketplace.json`) and add `## X.Y.Z` at the top of `CHANGELOG.md`; `validate.sh` checks that they match.
3. Run all suites, then have a fresh-context `dev-harness:skeptic` review `git diff main..build/vX.Y.Z`. Fix or document every finding.
4. Add a checkpoint to `docs/progress.md`: what is done, what was verified, what was not.
5. Merge into `main`, create an annotated tag `vX.Y.Z`, push, and watch CI.
6. Install from GitHub in an isolated config (`CLAUDE_CONFIG_DIR`) and check `claude plugin details dev-harness`.

## Forking

To publish your own copy under your own name:

1. Replace `radeshgovind-2005` everywhere: `grep -rn radeshgovind-2005 .` lists the place in `.claude-plugin/marketplace.json`, `plugin.json` (`author`, `homepage`, `repository`), `README.md`, `docs/`, `plugins/dev-harness/skills/help/SKILL.md`.
2. Keep the plugin name `dev-harness` if you want the `/dev-harness:...` commands to stay the same. If you rename the plugin or the marketplace (`claude-harness`), every install command and the `dev-harness@claude-harness` form changes with it.
3. Run `bash tests/validate.sh`, then install your fork from your repository in an isolated config before you tell anyone.

License: MIT. Keep the `LICENSE` file.
