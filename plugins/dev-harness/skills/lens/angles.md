# Lens angles

One checklist per angle. `/dev-harness:lens` pastes the matching block into each reviewer's prompt. Keep each list short: a checklist that is not read does nothing.

## UX — the person who uses what was built

Stand in for the receiver named in `docs/intent.md`: the user, the grader, the client.

1. **First run.** From a clean start, what is the first thing they see or have to do? Can they reach the main result without reading the source?
2. **Errors.** Break an input on purpose (empty, wrong type, missing file). Does the message say what went wrong and what to do next?
3. **Empty and edge states.** What do they see with no data, one item, a very long item?
4. **The promise.** Does the result match what `docs/intent.md` says matters most? Name any priority from the intent that the work ignores.
5. **Wording and flow.** Is anything they must know hidden in a place they will not look?

## DX — the next developer who works on it

Stand in for someone who clones the repository today and has an hour.

1. **Setup.** Follow the README or `CLAUDE.md` commands exactly. Which one fails, or needs knowledge that is not written down?
2. **Commands.** Run the documented test, lint and typecheck commands if they are fast. Do they pass? Do they exist?
3. **Tests that explain themselves.** When a test fails, does the output say what broke? Would a test fail if the business logic broke?
4. **Where things live.** Can they find where to change X in under five minutes? Are names consistent with `docs/conventions.md`?
5. **Surprises.** Hidden global state, undocumented environment variables, steps that only work in the author's shell.

## AX — an AI agent working in the project

Stand in for a fresh agent session with only `CLAUDE.md` and the files. The `ax-check.sh` output is given as fact; do not repeat it, build on it.

1. **Router.** Does `CLAUDE.md` tell the agent what to read for each kind of task, and do those files hold what the table promises? Open two routed files and check.
2. **Commands.** Pick three commands from `CLAUDE.md`. Do they exist and run from the stated place?
3. **Rules that can be broken.** Which critical rules in `CLAUDE.md` have no hook, test or CI behind them? A rule that matters and is only text is a finding.
4. **Blocked actions.** When a hook blocks something, does its message say why and what to do instead? Read the hook scripts' messages.
5. **Resuming.** Could a new session continue from `docs/progress.md` alone? What would it have to guess?
6. **Verification.** Does the checklist say how to prove a task is done, with a command an agent can run?
