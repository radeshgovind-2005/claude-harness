# Parts

The harness grows with the project: a rule that must never break becomes a hook, a repeated procedure a skill, an independent review an agent, facts for one folder a path-scoped rule. A one-time task becomes nothing.

Every part follows one form (`spec.md`, `files/`, `tests/` in `.claude/forge/<name>/`) and passes `forge.sh check` before it is installed: every spec field filled, its tests pass, and its tests fail when the part is removed. Propose one with `/dev-harness:forge`; nothing is installed without your yes. A part used successfully 3 times can be marked `proven` and promoted to the marketplace with `/dev-harness:promote`.

The table below is written by `forge.sh`; do not edit it by hand (`forge.sh list` fails when it drifts).

<!-- parts:index:start -->
| part | type | status | uses | installed | spec |
|---|---|---|---|---|---|
<!-- parts:index:end -->
