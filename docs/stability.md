# Stability

From 1.0.0 dev-harness follows semantic versioning. A change that breaks anything in "Stable in 1.x" needs 2.0.0. Everything else may change in a minor or patch release.

The plugin version lives in one place, `plugins/dev-harness/.claude-plugin/plugin.json`. Claude Code uses that field, not the git tag, to decide that an update exists. `CHANGELOG.md` has one entry per version, and `tests/validate.sh` fails if its top entry differs from `plugin.json`.

## Stable in 1.x

| Surface | What is frozen |
|---|---|
| Skill names and arguments | `help`, `discover`, `new`, `add`, `lesson`, `explore`, `lens`, `goal`, `showcase`. Their argument forms in `reference.md` (for example `add <part>` with the parts `guardrails`, `reviewer`, `lessons`, `memory`, `workflows`, `rules`, `all`). New skills and new optional arguments may be added |
| Agent names | `skeptic`, `lens-reviewer`, `architect`, `designer`, `tester`, called as `dev-harness:<name>` |
| Agent output formats | The first line of each report (`STATUS: ...`, or `ANGLE: ...` for `lens-reviewer`) and the section names in `reference.md`. A new optional section may be added; none is renamed or removed |
| Project configuration | `.claude/hooks/harness.conf` keys `PROFILE`, `BLOCK_MAIN`, `VERIFY_CMD`, and their meaning. The three profiles `prototype`, `product`, `assignment` |
| `scaffold.sh` | Its phases (`files`, `guardrails`), flags (`--profile`, `--part`, `--verify-cmd`, `--merge-settings`, `--dry-run`) and the status words in its output (`add`, `skip`, `merge`, `update`, `ok`, `note`, `FAIL`). It never overwrites a file |
| What lands in a project | `CLAUDE.md` (a router under 100 lines), `docs/INDEX.md`, `architecture.md`, `conventions.md`, `workflow.md`, `lessons.md`, `progress.md`, `experiments.md`, `docs/agents/`, `.claude/hooks/*.sh`, `.claude/settings.json`, `.claude/rules/`, the `dev-harness-hooks` CI workflow. `docs/intent.md` is written by `discover`, not by `scaffold.sh`, and its template and `status:` values (`discovering`, `decided`) are frozen too |
| `explore` log | The `docs/experiments.md` Metric lines (`Name`, `Measured by`, `Direction`, `Target`) and the log table columns |
| Safety stance | The plugin ships no always-on hooks. Strict hooks are copied into a project only when the user opts in. A skill that registers a hook for its session (`discover`, `goal`) keeps it state-gated. Agents have no edit tools |

## Not frozen

- The wording of skill and agent prompts, help text and messages.
- The `guard-bash.sh` list of commands it blocks or asks about. It is best-effort and will grow. A command that was blocked may stay blocked; one that was allowed may start to ask.
- The internal scripts' options other than those above (`explore.sh`, `goal.sh`, `ax-check.sh`, `showcase-facts.sh`, `lib.sh`), the `goal` state file, and the `FACT` and `PASS/WARN/FAIL` line texts.
- Test counts, CI layout, and the contents of `examples/`.

## What counts as breaking

Renaming or removing something in the table; changing what a `harness.conf` key means; making `scaffold.sh` overwrite or move a file; adding a hook to the plugin itself; giving an agent an edit tool. Fixing a bug in how a profile's hooks behave is not breaking, even if a command now asks that used to pass, as long as the profile's documented table in `how-it-works.md` stays true.

## Reporting a break

Open an issue at <https://github.com/radeshgovind-2005/claude-harness/issues> with the plugin version (`/dev-harness:help` prints it) and what changed.
