# `showcase` run on this repository, before the docs were written

- Plugin version: 0.5.0
- Date: 2026-11-10
- Command: `/dev-harness:showcase the README front page for friends who may install it ...`
- How it was run: headless `claude -p` with `--plugin-dir`. A headless run cannot answer prompts or approve tools, so the confirmations are in the prompt and the tools are passed with `--allowedTools`.
- Project: this repository, same state as the `lens` example.

The pick (the opt-in guardrails, and that they are tested) became the README's "Does it get in my way?" section. Its DO NOT CLAIM list caught a profile detail it had not confirmed.

Absolute paths were shortened (`<scratch>`, `~`). Nothing else was edited.

## What Claude reported

```
**PICK:** The opt-in guardrail hooks that `/dev-harness:new` copies into a project. They block force push, `--no-verify`, reading `.env` and `curl | sh` for real, and a test suite proves it.

**FOR:** Friends who may install it. This is an assumption. `docs/intent.md` doesn't exist (the facts script says: "who this is for is unknown (run /dev-harness:discover)"), so I took the audience from your request. I treated them as developers who already use Claude Code and want to know "what happens to my repo if I turn this on?"

**WHY:**
- The README front page has to answer "is this safe to install, and what does it do for me?" The plugin ships no always-on hooks (`plugins/dev-harness/.claude-plugin/plugin.json`, validate.sh reports `Hooks (0)`). The hooks only exist in a project that opted in. That is both the safest and the most distinctive thing to say.
- **Lost: `goal`** (the loop is judged by a command's exit code, not by a model). It's distinctive, but it needs a live Claude session to show, and `goal-test.sh` is not what I ran. The README already explains it well.
- **Lost: `explore`** (the number decides). `docs/experiments.md` doesn't exist, so there is no measured gain from this repo itself ("no measured gains"). The mechanism is tested but not demonstrated on a result.

**DEMO** (about 60 seconds; nothing is written outside temp dirs the tests clean up):
1. `bash plugins/dev-harness/templates/project/.claude/hooks/test-hooks.sh`
   You see: `Result: 172 passed, 0 failed` (includes `[product] force push is blocked`, `[product] --no-verify is blocked`, `[product] curl | sh is blocked`, `[product] rm -rf build is allowed`)
2. Pipe a command to the hook by hand: `jq -n --arg c 'git push --force origin feature' --arg d "$PWD" '{tool_name:"Bash",cwd:$d,tool_input:{command:$c}}' | CLAUDE_PROJECT_DIR=$PWD bash plugins/dev-harness/templates/project/.claude/hooks/guard-bash.sh`
   You see: exit 2, `BLOCKED: Force push is not allowed (this includes -f, --force-with-lease and +refspec).`
   The same call with `rm -rf build` or `ls` exits 0 with no output.
3. `bash tests/validate.sh`
   You see: `dev-harness loads Skills (9)`, `Agents (5)`, and `Result: 57 passed, 0 failed, 0 skipped`.
4. `/bin/bash tests/scaffold-test.sh` (takes a few minutes)
   You see: `Result: 195 passed, 0 failed`.

`git status --short -uall` was empty after all of this, so the demo left no files in the repo.

**README SECTION** (draft, not written yet). The README already covers profiles in `## Use`, so this would be a short "Does it get in my way?" block placed after `## Install`. It is not a duplicate of an existing section:

```markdown
## Does it get in my way?

No. The plugin itself ships no hooks. Guardrails only exist in a project where you run
`/dev-harness:new` or `/dev-harness:add guardrails` and pick a profile.

Once they are in, they stop these commands. The Bash guard exits 2 and prints, for example,
`BLOCKED: Force push is not allowed`:

- force push (`--force`, `-f`, `--force-with-lease`, `+refspec`)
- `git commit --no-verify`
- `cat .env` and edits to `.env`, lockfiles, private keys and the hooks themselves
- `curl ... | sh`
- `rm -rf /`, `rm -rf ~/`

Ordinary commands such as `rm -rf build` and `ls` pass through.

These are checked, not just claimed. A dry-run script copies the hooks into a temporary repo and
tries each barrier under every profile (172 checks, none touch your repo):

    bash .claude/hooks/test-hooks.sh

These hooks catch common mistakes, not a determined bypass. Also turn on branch protection and
required CI on your Git host.
```

**TALKING POINTS:**
1. The plugin ships no hooks; they are copied into a project only when you opt in. [VERIFIED: `bash tests/validate.sh` printed "Hooks (0)" and 57/57; READ: CLAUDE.md "The plugin ships NO always-on hooks"]
2. Force push, `--no-verify`, `cat .env` and `curl | sh` each get a `BLOCKED:` message and exit 2. [VERIFIED: ran `guard-bash.sh` by hand with each command]
3. Normal work such as `rm -rf build` and `ls` isn't blocked. [VERIFIED: same hand run, exit 0]
4. The guardrails have a dry-run self-test that doesn't touch your repo: 172 checks, 0 failed. [VERIFIED: `test-hooks.sh`; READ: `test-hooks.sh:3-4,10` (temp repo)]
5. Scaffolding never overwrites your files: an existing `CLAUDE.md`, `docs/lessons.md` and hook stay byte-for-byte unchanged. [READ: `tests/scaffold-test.sh:65-73`; VERIFIED: the suite passed 195/195]
6. The hooks are honest about limits. They stop mistakes, not deliberate bypass. [READ: `guard-bash.sh:35` comment "catch common mistakes, not deliberate bypass"]

**DO NOT CLAIM:**
- **Any profile specifics beyond what's in the README (for example "`main` is blocked on `product`").** The hook tests show `commit on main is blocked`, but I did not confirm which profile sets that, and I never read it from `scaffold.sh` (my grep for the setting names found nothing there). It's `UNVERIFIED` here. The `/dev-harness:new` skill text says it, and that is prose.
- **"Safe" or "can't be bypassed".** The hook's own comment and the README say it is a best-effort list, not a sandbox.
- **Anything about `/dev-harness:new` interactively** (discover conversation, profile picker). I could not run a live session, and `docs/progress.md` lists "a real interactive discover conversation" as not verified.
- **Any number of "files scaffolded" or run time.** I did not count them. "A few minutes" for the scaffold suite is my observation of one run, not a measurement.
- **That the install works on Windows or on CRLF checkouts.** `docs/progress.md` lists this as unverified.
- **Anything about `explore` gains.** There's no `docs/experiments.md`, so there is no measured result.
- **The agents' "never edits"** as a guarantee. The README says they can still write through `Bash`.

**NOT VERIFIED:**
- I did not run `goal-test.sh`, `explore-test.sh`, `lens-test.sh` or `showcase-test.sh`. They were not needed for this pick.
- I did not run `/dev-harness:new` in a real session, because a headless run can't answer its questions.
- I did not run `shellcheck`.
- I did not check what the README looks like on GitHub.
- I did not verify the install from GitHub today. `docs/progress.md` says it was checked for v0.5.0, which is prose.
- **Version drift.** The README says v0.5.0, and the top of CLAUDE.md says the version lives only in `plugin.json`. I didn't compare the two, so don't quote a version in the new section.

**Do you want me to add the "Does it get in my way?" section to `README.md`, after `## Install`?** I haven't written anything. If you say yes, I'll make that one edit and show the `git diff`.
```

