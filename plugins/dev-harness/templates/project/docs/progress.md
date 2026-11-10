# Progress

Handoff notes so a new session can resume without asking what happened. Newest checkpoint first.
Write one checkpoint after each significant step, and always before you stop.
Keep each checkpoint short. Delete checkpoints that no longer help a new session.

## Format

```
## Checkpoint <name or version> — YYYY-MM-DD

### Done
- <what changed>

### Verified
- <what you checked, and the command or test that proves it>

### Not verified
- <what you did not or could not check, and why>

### Next
- <the next step, concrete enough to start from>
```

"Not verified" is never empty by habit. If everything was checked, write "nothing".

## Checkpoints

## Checkpoint 0 — YYYY-MM-DD

### Done
- Project set up with dev-harness (replace this entry with your first real checkpoint).

### Verified
- Hook tests passed when the guardrails were installed (`.claude/hooks/test-hooks.sh`).

### Not verified
- Nothing built yet.

### Next
- Fill the `<placeholders>` in `CLAUDE.md`, then start on the first task in `docs/intent.md`.
