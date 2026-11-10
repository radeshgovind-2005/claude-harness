# Lessons

Past mistakes and the rule each one created. Newest first.
Add one entry per correction. Keep each entry to 3 lines.
If a lesson applies to every task, propose to move it into `CLAUDE.md`.
Delete a lesson when the code or a hook now prevents the mistake.

## Format

```
### YYYY-MM-DD — <short title>
- Mistake: <what went wrong>
- Rule: <the imperative rule that prevents it>
```

## Entries

### 2026-01-01 — Example: silent skip
- Mistake: Reported "migration complete" while 14 rows failed a constraint.
- Rule: Report row counts (expected vs processed) for every data migration.
