---
name: goal
description: Goal loop judged by a command. Work toward a success check (a command that must exit 0) with a budget of rounds and minutes. A Stop hook runs the check each time you try to finish, sends you back with the failure, and ends the loop on success or when the budget is gone. Checkpoints go to docs/progress.md.
when_to_use: The user wants Claude to keep working until something verifiable is true ("keep going until the tests in tests/api pass", "until lint is clean"), and can state it as a command.
argument-hint: "<what must be true, ideally as a command that exits 0>"
disable-model-invocation: true
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/goal.sh *)
hooks:
  Stop:
    - hooks:
        - type: command
          command: "\"${CLAUDE_PLUGIN_ROOT}/skills/goal/goal-stop.sh\""
          timeout: 180
---

Work toward a goal until a command says it is met. Input from the user: $ARGUMENTS

The judge is an exit code, not your opinion. A Stop hook (`goal-stop.sh`) runs the success check each time you try to finish. If it fails, you are sent back with its output. If it passes, or the budget is used up, you are asked for a final report and the loop ends. This differs on purpose from Claude Code's built-in `/goal`, where a small model reads the conversation and decides.

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/goal.sh start  --session ${CLAUDE_SESSION_ID} --check "<command>" [--rounds N] [--minutes M]
bash ${CLAUDE_PLUGIN_ROOT}/scripts/goal.sh status --session ${CLAUDE_SESSION_ID}
bash ${CLAUDE_PLUGIN_ROOT}/scripts/goal.sh stop   --session ${CLAUDE_SESSION_ID} --reason "<why>"
```

## 1. Fix the success check (ask, do not guess)

- Turn the user's goal into **one command, on one line, that exits 0 only when the goal is true**: for example `npm test --silent` or `pytest tests/api -q`. Prefer a command that already exists. If the goal cannot be a command (taste, design), say so and offer `/dev-harness:explore` (a number to improve) or `/dev-harness:lens` (a review) instead.
- **Run it once now.** If it already passes, there is nothing to do: tell the user and stop. If it fails, show the failure so the user can see it is the right thing to fix.
- **Show the exact command and get an explicit yes** (AskUserQuestion). The hook will run it in this project after every round, with the user's permissions.

## 2. Set the budget

- **Rounds**: default 10. A round is one time you end your turn and the check runs, not one tool call.
- **Minutes**: default 30, measured from the start.
- **Tokens are not budgeted.** Hooks receive no token count, so no hook can enforce one. For a headless run, add `--max-budget-usd` to the `claude -p` command. Say this once, plainly.
- Suggest a budget that fits the task; ask only if the user did not give one.

## 3. Start, then work

1. Run `goal.sh start` with the confirmed command and budget. Only after it prints `add`, the loop is on. If it prints `FAIL`, stop and report it.
2. Work in the smallest steps that move the check toward passing. Run the check yourself as you go.
3. When you think it passes, finish normally. **Do not claim success yourself:** the hook runs the check and decides.
4. Each time the hook sends you back, do what it says: append a short checkpoint (Done / Verified / Next) to `docs/progress.md`, then take the next smallest step. If the same step has failed twice, change approach and say why in the checkpoint.
5. When the hook reports `GOAL MET` or `GOAL BUDGET REACHED`, write the final report it asks for, then stop. For a budget stop, say plainly that the goal was **not** met, what is left, and the next step.

## Rules

- **Never change the success check, or what it reads, to make it pass**: not the command, not the test expectations, not the data it measures. Fix the work, not the judge. If the check is wrong, run `goal.sh stop --reason "check is wrong: ..."` and tell the user.
- Do not stop the goal to escape a hard step. Stop it only when you need something from the user that you cannot get otherwise, and say exactly what.
- Do not start a second goal in the same session while one is active.
- Product profile: the usual hooks still apply on every step (no edits on `main`, `verify.sh` on stop). A failure from those is real; fix it.

## Limits (state these if the user asks, and in your final report when they matter)

- The loop lives in the session where this skill ran. After `--continue` or a resumed session the hook is **not** registered again; `goal.sh status` may still show an active goal. Run `goal.sh stop` to clear it.
- A goal ends when the check passes, the budget is gone, or someone runs `goal.sh stop`. If the state file is damaged, the hook fails open and the loop just ends (it prints why).
- The state file is outside the project but not tamper-proof against shell commands. The success check is only as good as its coverage: say what it does not cover.
- Claude Code itself ends a turn after 8 stop-hook blocks in a row with no tool call in between. A loop that does real work resets that count.
