---
paths:
  - "src/api/**"
---

# API Rules (example — edit or delete)

This file loads only when Claude works on files that match `paths`.

- Validate every request body at the handler boundary.
- Return errors in the standard error shape from `src/api/errors`.
- Every new endpoint needs one test for the success path and one for the main error path.
