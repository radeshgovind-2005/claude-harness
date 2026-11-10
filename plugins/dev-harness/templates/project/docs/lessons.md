# Lessons

Past mistakes and the rule each one created. Newest first.
Add one entry per correction with `/dev-harness:lesson`. Keep each entry to 3 lines.
A similar lesson is updated, not duplicated.
If a lesson applies to every task, propose to move it into `CLAUDE.md`. Ask first.
Delete a lesson when the code or a hook now prevents the mistake.

## Format

```
### YYYY-MM-DD — [tag] <short title>
- Mistake: <what went wrong>
- Rule: <the imperative rule that prevents it>
```

`[tag]` is one lowercase word for the area. `[discover]` marks a lesson about the discovery process; `/dev-harness:discover` reads those first.

## Entries

### 2026-01-01 — [example] Example: silent skip
- Mistake: Reported "migration complete" while 14 rows failed a constraint.
- Rule: Report row counts (expected vs processed) for every data migration.
