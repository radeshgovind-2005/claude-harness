# `dev-harness:architect` on a 22-line project

- Plugin version: 1.0.0
- Date: 2026-11-10
- Command: `Use the dev-harness:architect agent: is the structure ready for adding a second payment provider next quarter?`
- How it was run: headless `claude -p` with `--plugin-dir`. A headless run cannot answer prompts or approve tools, so the confirmations are in the prompt and the tools are passed with `--allowedTools`.
- Project: a toy Python billing tool with an import cycle and a catch-all `core.py`; its README says a second payment provider is planned.

Note that it questions the premise: there is no first provider to generalise yet.

Absolute paths were shortened (`<scratch>`, `~`). Nothing else was edited.

## The agent's report

```
STATUS: CONCERNS
QUESTION: Is the structure ready for adding a second payment provider next quarter?
PURPOSE: A small billing tool that will gain a second payment provider next quarter (README, 3 lines; docs/intent.md does not exist). Assumption: one maintainer, small codebase, so the bar is "cheap to change", not "layered".

CURRENT STRUCTURE:
- 6 files, 22 lines in total (`wc -l`). core.py 10, billing.py 4, reports.py 3, cli.py 2.
- core.py is a grab-bag: DB connection, user loading, SMTP, JSON rendering, tax, audit log, plus thin wrappers `charge` and `monthly` that call back into billing and reports.
- Imports (`grep -rn import app`): core -> billing, reports; billing -> core; reports -> core, billing; cli -> core, billing, reports.
- Cycles: core <-> billing and core <-> reports. These work only because the imports are module-level (`from app import X`) and the attributes are used inside functions.
- Fan-in: core is imported by 3 of 4 modules. Fan-out: core and cli each import 2-3 modules.
- No provider concept exists. billing.apply (billing.py:2-4) calls core.audit("charge") and returns amt + tax. It does not call any payment provider. There is no gateway call, no provider config and no provider-specific code to generalise.

CONCERNS (most severe first):
1. [severity: medium] app/billing.py:2-4 — There is no payment seam to put a second provider behind, because there is not even a first provider. The word "charge" appears only as an audit string and as the wrapper `core.charge` (core.py:7). The code computes amount plus tax and logs it.
   Evidence: `def apply(u, amt): core.audit("charge"); return amt + core.tax(amt)`
   Change it would block or spread across: Adding provider #2 means first adding provider #1 (a real call, and credentials/config). The seam should be designed against the real first provider, not guessed now.
2. [severity: medium] app/core.py:2 and core.py:7-8 — core imports billing and reports, and billing and reports import core. The central module depends on its own dependents. A provider module that needs core (for audit, user, tax) will form another cycle.
   Evidence: `from app import billing, reports` (core.py:2); `def charge(u, amt): return billing.apply(u, amt)` (core.py:7)
   Change it would block or spread across: Any new provider module either imports core (a third cycle) or core must import it (more fan-out). Moving `charge` and `monthly` out of core, or deleting them, would remove the cycles. Nothing in app/ calls either wrapper (grep shows no callers).
3. [severity: low] app/core.py:3,10 — Import-time side effects: `sqlite3.connect("x.db")` runs on import and `audit` writes to a relative path. Tests of a provider would touch a real DB file and log, and the working directory decides where they land.
   Evidence: `DB = sqlite3.connect("x.db")`
   Change it would block or spread across: Testing any provider code that imports core. This is a smaller issue at 22 lines, but it will matter once real provider calls are added.
4. [severity: low] app/billing.py:2 and app/reports.py:3 — Billing hard-codes the amount rules (`core.tax` at a flat 0.2), and reports calls `billing.apply(u, 1)` with a literal 1. If a second provider has different fees, currency or tax, the rule has no home besides core.
   Evidence: `def tax(amt): return amt * 0.2`; `"due": billing.apply(u, 1)`
   Change it would block or spread across: Per-provider fee or tax differences. Reports would also trigger the charge side effect (audit write) every time a report is built.

OPTIONS:
A. Leave the structure alone until provider #1 exists, then do a small cleanup first (the smallest step)
   Buys: No speculative design. At 22 lines the code can be reshaped in an hour. The seam is shaped by the real provider's call.
   Costs: The cycles and the import-time DB remain until then. The cleanup has to happen next quarter as part of the work.
   Wrong when: Provider #1 is added quickly with the same shortcuts (calls placed inside core), so that the cycles grow.
B. Do the cleanup now: delete or move core.charge/monthly, so core no longer imports billing/reports. Move tax and audit out of core if they are used only by billing. Keep billing as the one place that does charging, with no interface yet.
   Buys: Removes both cycles (about 5 lines changed). Provider code later has a clean spot to land. The change is cheap now and gets harder once real code exists.
   Costs: A small amount of churn for a feature that is not started. Without a first provider, the new boundaries are partly a guess.
   Wrong when: Billing is about to be rewritten anyway (then the cleanup is wasted).
C. Define a provider interface now (a `Provider` class with `charge(user, amount)`, a registry, a config switch) and implement a stub for the second one.
   Buys: A visible extension point.
   Costs: Designed with zero real providers to learn from; likely to be wrong when real APIs differ (auth, refunds, webhooks). This is more structure than 22 lines justify.
   Wrong when: Almost always at this size. It becomes right only after one real provider exists and you can see what the second one has to differ on.

RECOMMENDATION: B, then add the first real provider inside billing.py. Introduce a second provider and only then extract an interface, using two real implementations as the guide. The project is tiny, so the structure is "not ready" mainly in the sense that there is nothing to extend yet; the cycles are cheap to remove now (nothing calls core.charge or core.monthly) and cost more once provider code and credentials arrive. If you would rather not touch it, A is acceptable, but do the cleanup removal as the first commit of the provider work.

NOT CHECKED: Bugs (e.g. smtplib.SMTP("localhost") with no close, unclosed audit file handle, `core.send_mail("a", ...)` with a fake recipient, `reports.build(1)` hard-coded in cli) are for skeptic. Test coverage: no tests exist (git ls-files); that belongs to tester. Whether a real payment provider is hidden elsewhere (other branches, private repos, env config): only the single commit `b00661c` and 6 tracked files were examined.

Correction: in the last line of the recommendation I wrote "do the cleanup removal as the first commit"; the agent's text reads "do the cycle removal as the first commit of the provider work." The rest is verbatim.
```

