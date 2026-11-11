---
name: <kebab-case-name>
type: <hook | skill | agent | rule>
status: experimental
uses: 0
# hooks only (delete for other types):
event: <PreToolUse | PostToolUse | UserPromptSubmit | Stop | SessionStart | PreCompact | ...>
matcher: <tool names such as Bash or Edit|Write; leave empty for events without a matcher>
timeout: 30
---

# <name>

A part is a folder: this `spec.md`, `files/` (what gets installed) and `tests/` (executable `*.sh`, each exits 0).
`forge.sh check` refuses a part with an empty or placeholder section, files that do not fit the type, a
failing test, or tests that still pass when `files/` is emptied. Tests run from a copy of the part folder,
with `PART_DIR` and `FILES_DIR` set: use `"$FILES_DIR/<file>"`, never a path in the project.

## Purpose
<The mistake or gap this fixes. Name the real case: the lesson, the misfire, the repeated request.>

## Which type and why
<One of: hook (a rule that must never break), skill (a repeatable procedure or loop), agent (independent
judgment or review in fresh context, read-only), rule (facts for one folder or file type). A one-time task
is not a part: do it and stop. Say why this type and not the next one.>

## Trigger
<When it runs: the hook event and matcher, the skill's "use when", the agent's caller, the rule's paths.>

## Inputs and outputs
<Fixed formats. What it reads; what it prints or returns, line by line; its exit codes.>

## Method or loop
<The steps. For a loop: the measure, the keep-or-stop decision, and where it logs.>

## Unacceptable
<Hard stops: what it must never do (for example: block without saying how to fix; edit files; pass silently).>

## Success check
<A real signal, not an opinion: a command, an exit code, a count, a test that fails without the part.>

## Tests
<Which tests/*.sh exist, what each proves, and which one fails when the part is broken or missing.>

## Budget
<For loops: rounds, minutes or runs, and what happens at the limit. Otherwise: n/a — and the reason.>
