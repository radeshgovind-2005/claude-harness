# Your First Workflow

A safe first run: read-only, scoped, cheap.

## Shape

```
list files (max 10)
   → FAN OUT: one auditor per file (small model)
   → REDUCE:  count planned vs returned
   → VERIFY:  one fresh skeptic per finding (keep / drop / unverified)
   → SYNTHESIZE: one ranked report
```

## 1. Prepare

1. `git switch -c audit/first-workflow` (the product profile blocks writes on `main`).
2. `/config workflowSizeGuideline=small`
3. Check the model with `/model`.

## 2. Prompt (replace `<folder>`)

```text
use a workflow to audit the files in <folder>/ for error-handling bugs.
Do not edit any source file.

SCOPE:      List the files first. Audit at most 10 files.
FAN OUT:    One agent per file. Use a smaller model for this stage.
            Each finding must include: file, line, the problem,
            and how it fails in production.
VERIFY:     For each finding, a separate agent with fresh context
            reads the code and tries to disprove it.
            It returns keep or drop, with one reason.
            If it cannot check, mark the finding "unverified", not "drop".
FAN-IN:     Report files planned vs files returned.
            Name every file that returned nothing.
REPORT:     One list, ranked by severity.
            Show verified and unverified findings in separate sections.
            Save it to docs/audits/error-handling.md.
```

## 3. Approve

Select **View raw script** on the first run. Confirm the verify phase and the file cap exist in the code.

## 4. Watch

`/workflows` → open the run. Press `x` to stop it.

## 5. Check (the anchor)

| Check | Pass if |
|---|---|
| Fan-in count | Planned = returned, or missing files are named |
| Spot-check 3 "keep" findings | They are real bugs |
| Spot-check 2 "drop" findings | They really were wrong |
| Token total | You know the cost |

## 6. Save or Fix

- Good run: `/workflows` → select → `s` → save to `.claude/workflows/`.
- Bad run: add an entry to `docs/lessons.md`, then change the prompt.
