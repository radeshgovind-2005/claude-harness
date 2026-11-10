# Getting started

You need Claude Code, `git`, and `jq`. `shellcheck` is needed only if you work on the plugin itself.

## Install

In Claude Code:

```
/plugin marketplace add radeshgovind-2005/claude-harness
/plugin install dev-harness@claude-harness
```

Then run `/dev-harness:help`. It prints the plugin version and every skill and agent. The plugin ships no hooks, so installing it changes nothing about how Claude Code behaves until you run a skill.

## Pick a profile

A profile is how strict the project's guardrails are. You pick it when you run `new` (or `add guardrails`).

| | prototype | product | assignment |
|---|---|---|---|
| For | spikes, demos, learning | real users or a team | graded or course work |
| Edits, commits, pushes on `main` | allowed | blocked | allowed |
| Check when Claude stops | off | typecheck and lint | the tests |
| `git push` asks first | no | yes | no |
| Claude explains each step | no | no | yes |

Every profile blocks force push, `--no-verify`, reading `.env`, `rm -rf /` and `curl | sh`, and protects the hooks and `harness.conf` from Claude's edits. You change a profile by editing `.claude/hooks/harness.conf` yourself.

## Walkthrough 1: a new idea (prototype)

```
/dev-harness:new a CLI that tracks my reading list
```

1. **Discover.** Claude reads what you gave it, says "here is what I think this is about" (guesses are labelled), and asks only what is missing, at most three questions per round. It proposes two or three directions, one of them bold, and you pick and adjust. It writes `docs/intent.md` with `status: decided`. No code is written, and while the status is `discovering` a hook blocks edits to every other file.
2. **Profile and verify command.** You choose `prototype`. The stop check stays empty.
3. **Files, then guardrails.** `scaffold.sh` adds `CLAUDE.md`, `docs/` and `.claude/rules/`, fills the placeholders in `CLAUDE.md` from the intent, then adds the hooks and runs their self-test last. It never overwrites a file you already have.
4. **Report.** It lists what was added and skipped, and what is still yours to do: commit, and any `<cmd>` placeholder left.

## Walkthrough 2: an existing project (product)

```
/dev-harness:discover
/dev-harness:new --profile product
```

Run `discover` first if there is no `docs/intent.md`. `new` offers to switch to a `chore/dev-harness-setup` branch because the product profile blocks edits on `main` as soon as the guardrails land. It proposes a `VERIFY_CMD` from `package.json`, `pyproject.toml`, a `Makefile` and similar (typecheck plus lint, under 60 seconds) and asks you to confirm. Afterwards:

- Commit the setup yourself.
- Turn on branch protection and require the `dev-harness-hooks` check on your Git host. Local hooks stop mistakes, not a deliberate bypass.
- `permissions.allow` rules in `.claude/settings.json` apply only once you trust the folder; hooks and `deny` and `ask` rules apply at once.

To add one piece to a project that already has others, use `/dev-harness:add <part>`.

## Walkthrough 3: an assignment

```
/dev-harness:new --profile assignment here is the assignment text: ...
```

Paste the brief. Discovery works out who grades it and how, so the intent records what the grader cares about. The assignment profile makes Claude explain each step and runs your tests when it tries to stop. Near the end, `/dev-harness:showcase` finds the strongest part to put in front of the grader.

## Day to day

| You want to | Run |
|---|---|
| Record a correction so it does not repeat | `/dev-harness:lesson ran the tests in the wrong folder` |
| Have a fresh reviewer try to disprove a change | ask for the `dev-harness:skeptic` agent with only the goal and the diff |
| See the work from the user, the next developer and an AI agent | `/dev-harness:lens the onboarding flow` |
| Make a number better, one change at a time | `/dev-harness:explore cut p95 latency of /search` |
| Keep going until a command passes, with a budget | `/dev-harness:goal pytest tests/api -q passes` |
| Decide what to show off | `/dev-harness:showcase tutor demo` |
| Judge structure, an interface, or the tests | the `dev-harness:architect`, `dev-harness:designer` or `dev-harness:tester` agent |

`reference.md` says what each one reads, writes and never does.

## What to check yourself

- Read `docs/intent.md` after `discover`. It is the file every later session reads, and a wrong guess there is carried forward.
- Check `git status` after any reviewer agent has run. None has an edit tool, but their `Bash` can still write, and a test run can leave caches.
- The author has not yet run `discover` in a real interactive conversation on a real idea; the flows above were tested with scripted answers. If you try it, a `/dev-harness:lesson` about what it missed is the most useful feedback.
