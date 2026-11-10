# claude-harness

A Claude Code plugin marketplace with one plugin, **dev-harness**. It sets up and runs software projects the way experienced Claude Code users do: it works out who the work is for before anything is built, gives the project memory and guardrails that fit the kind of work (a prototype, a product or an assignment), has fresh-context reviewers check changes, and turns every correction into a lesson so the mistake does not come back.

> **Status: v1.0.0.** Nine skills and five agents. From 1.0.0 the user-facing surface is stable: see [docs/stability.md](docs/stability.md). Works on macOS and Linux; Windows is not tested.

## Install

You need Claude Code, `git` and `jq`. In Claude Code:

```
/plugin marketplace add radeshgovind-2005/claude-harness
/plugin install dev-harness@claude-harness
```

Then run `/dev-harness:help`: it prints the version and every skill and agent. Installing adds skills and agents only. The plugin ships no hooks, so nothing changes in your projects until you run a skill. Updates: `claude plugin update dev-harness@claude-harness`.

## The five-minute tour

In a project folder:

```
/dev-harness:new a CLI that tracks my reading list
```

1. **Discover.** Claude says back what it thinks the work is about (guesses labelled), asks only what is missing, proposes two or three directions (one bold), and saves the decision to `docs/intent.md`. No code is written yet.
2. **Profile.** You pick how strict the guardrails are.
3. **Scaffold.** It adds a short `CLAUDE.md` (a router that tells Claude which doc to read for which task), `docs/` (intent, architecture, conventions, lessons, progress), the guardrail hooks, and a CI check that the hooks still work. It never overwrites a file you have.

| Profile | For | `main` | Check when Claude stops | `git push` asks |
|---|---|---|---|---|
| prototype | spikes, demos, learning | allowed | off | no |
| product | real users or a team | blocked | typecheck and lint | yes |
| assignment | graded or course work | allowed | the tests | no |

Step by step, with the other profiles: [docs/getting-started.md](docs/getting-started.md).

## Does it get in my way?

No. The plugin itself ships no hooks. Guardrails exist only in a project where you ran `/dev-harness:new` or `/dev-harness:add guardrails`. Once they are there, the shell guard stops these (it exits 2 and tells Claude why, for example `BLOCKED: Force push is not allowed`):

- force push (`--force`, `-f`, `--force-with-lease`, `+refspec`) and `git commit --no-verify`
- `cat .env` and edits to `.env`, lockfiles, private keys and the hooks themselves
- `curl ... | sh`, `rm -rf /` and `rm -rf ~/`

Ordinary commands such as `rm -rf build` and `ls` pass through. Riskier ones (`git reset --hard`, `git clean -f`, shell writes to the hooks) ask you first.

These are checked, not just claimed: the project's own `test-hooks.sh` copies the hooks into a temporary repository and tries each barrier under every profile (172 checks).

```bash
bash .claude/hooks/test-hooks.sh
```

The hooks catch common mistakes, not a determined bypass, and the command list is best-effort. Also turn on branch protection and required CI on your Git host.

## What it gives you

| Skill | Use it when |
|---|---|
| `new`, `add <part>` | set up a whole project, or add one part (guardrails, reviewer, lessons, memory, workflows, rules) |
| `discover` | before building: who is it for, what matters, where to push. Writes `docs/intent.md` |
| `lesson` | you corrected Claude. Records it, updates a similar lesson instead of duplicating, asks before promoting a rule to `CLAUDE.md` |
| `explore` | make a number better, one change at a time. A script measures, keeps what improves, reverts what does not, logs it |
| `goal` | keep working until a command exits 0, with a budget of rounds and minutes. Not the built-in `/goal`: the judge is your command, not a model |
| `lens` | three fresh reviewers look from outside: the user (UX), the next developer (DX), an AI agent (AX) |
| `showcase` | find the most impressive part and draft a demo, README section and talking points. Every claim is run or read, and labelled |
| `help` | this list, with the installed version |

Five agents, each with one question (call them as `dev-harness:<name>`). Pick the one whose question it is:

| Agent | Asks | Its evidence |
|---|---|---|
| `skeptic` | Is this change wrong? | a failing scenario, the project's own checks |
| `lens-reviewer` | What does this person hit? | commands run as that person |
| `architect` | Is the structure right, and what does each option cost? | counted imports, 2-3 options |
| `designer` | Is the interface well made? | computed contrast, missing states |
| `tester` | Would the tests catch a break? | mutants made in a temporary copy |

Every skill and agent in detail: [docs/reference.md](docs/reference.md). Real output from each, captured on toy projects: [examples/](examples/README.md).

## Honest limits

- **Hooks stop mistakes, not bypass.** They are not a sandbox.
- **The reviewer agents have no edit tools, but their `Bash` can still write.** Check `git status` after a review.
- **`goal` has no token budget** (hooks get no token count) and its hook is not re-registered after `--continue`.
- **The `discover` lock covers file-edit tools only**, in the session where it ran.
- **Not tested:** Windows, and a real interactive `discover` on a real idea by anyone but the author.

The full list: [docs/how-it-works.md](docs/how-it-works.md).

## Docs

| | |
|---|---|
| [docs/getting-started.md](docs/getting-started.md) | install, the three profiles, day to day |
| [docs/reference.md](docs/reference.md) | every skill, agent and script |
| [docs/how-it-works.md](docs/how-it-works.md) | what code enforces and what text advises; platforms; limits |
| [docs/stability.md](docs/stability.md) | what will not change in 1.x |
| [docs/contributing.md](docs/contributing.md) | tests, adding a skill or agent, releasing, forking |
| [docs/brief.md](docs/brief.md) | the original design brief |
| [CHANGELOG.md](CHANGELOG.md) | what shipped when |

## Develop or fork

```bash
bash tests/validate.sh
```

```bash
claude --plugin-dir ./plugins/dev-harness
```

The first command validates the manifests, the layout rules and `help`, and runs `claude plugin validate`. The second loads the plugin from source; run `/reload-plugins` after an edit. All the test suites, how to add a skill or agent, and what to change in a fork (the owner name appears in several places): [docs/contributing.md](docs/contributing.md).

## License

MIT. See [LICENSE](LICENSE).
