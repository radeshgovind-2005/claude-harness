# `goal`: the session limit and `--continue` (observed)

- Plugin version: 1.0.0
- Date: 2026-11-10
- Command: `/dev-harness:goal test -f never.txt (an impossible check, 30 rounds), then claude --continue`
- How it was run: headless `claude -p` with `--plugin-dir`. A headless run cannot answer prompts or approve tools, so the confirmations are in the prompt and the tools are passed with `--allowedTools`. `claude -p` prints only Claude's final message, so text from earlier in the session is not shown (which is why a report can refer to something "above").
- Project: an empty git repository; the check can never pass, and the model was told to answer "ok" after every hook message and call no tool.

Two limits from the docs, seen for the first time in a real run. After a run of Stop-hook blocks with no tool call in between, Claude Code ended the session on its own: the hook counted 9 Stop events, 19 seconds, 14 turns, USD 0.14 of the USD 1 budget, and a result of `success` with empty text. The goal's state stayed `active`. After `--continue` the hook was **not** registered again (the round counter did not move), and the stale `active` goal stayed until `goal.sh stop` ended it. The first run (state, `--continue`, `goal.sh stop`) and a second identical run (the JSON result below, to see why the session ended) are two separate runs of the same prompt, both ended after 9 Stop events. This is two runs on one machine: the count is what was observed, not a guarantee.

Absolute paths were shortened (`<scratch>`, `~`). Nothing else was edited.

## The session result (`--output-format json`, abridged to its fields)

```
{
  "subtype": "success",
  "is_error": false,
  "num_turns": 14,
  "total_cost_usd": 0.14343050000000002,
  "duration_ms": 18985,
  "result": ""
}

state file at the end: "rounds": 9, "status": "active", "outcome": null
```


## After `--continue`, then `goal.sh stop`

```
--- status after --continue
status: active  outcome: none
check: test -f never.txt
rounds: 9 of 30
minutes: 1 of 20
  stop    goal ended (cleanup after the resume test)
status: finished  outcome: stopped
check: test -f never.txt
rounds: 9 of 30
minutes: 1 of 20
```

