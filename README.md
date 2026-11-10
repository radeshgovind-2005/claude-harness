# claude-harness

A Claude Code plugin marketplace with one plugin: **dev-harness**.

dev-harness sets up and runs software projects the way experienced Claude Code users do. Before anything gets built, it works out what you're making, who it's for, and what matters most. It then scaffolds memory files and guardrails that suit the kind of project: a prototype, a product, or an assignment. Changes get reviewed by a fresh-context skeptic, and every correction is kept as a lesson so the mistake doesn't come back.

> **Status: v0.1.0 (skeleton).** Only `/dev-harness:help` works so far. The other skills arrive milestone by milestone; see [CHANGELOG.md](CHANGELOG.md) and the roadmap below.

## Install

In Claude Code:

```
/plugin marketplace add radeshgovind-2005/claude-harness
/plugin install dev-harness@claude-harness
```

Then run `/dev-harness:help`.

Or from a shell:

```bash
claude plugin marketplace add radeshgovind-2005/claude-harness
```

```bash
claude plugin install dev-harness@claude-harness
```

Updates: `claude plugin update dev-harness@claude-harness`. Third-party marketplaces don't auto-update by default.

## Design in one paragraph

Skills and agents live in the plugin and work in every project. Strict hooks, like blocking edits on `main` or running checks before Claude stops, are copied **into** a project only when you pick a profile with `new` or `add`. The plugin itself ships no hooks, so it never blocks you in a project that didn't opt in. Rules that must never break are hooks, not lines in CLAUDE.md. Local hooks stop mistakes, not deliberate bypass, so also turn on branch protection and required CI on your Git host.

## Roadmap

| Version | Adds |
|---|---|
| 0.1.0 | Marketplace, plugin skeleton, `help` |
| 0.2.0 | `discover`, `new`, profiles, guardrail hooks copied into projects |
| 0.3.0 | `add`, `skeptic` agent, `lesson`, memory files |
| 0.4.0 | `explore`, `lens`, `goal` |
| 0.5.0 | `showcase`, `architect` / `designer` / `tester` agents |
| 1.0.0 | Full docs, examples, full test pass |

The full design is in [BRIEF.md](BRIEF.md).

## Develop or fork

```bash
bash tests/validate.sh
```

```bash
claude --plugin-dir ./plugins/dev-harness
```

The first command validates both manifests, the layout rules, and runs `claude plugin validate`. The second loads the plugin from source for a session; run `/reload-plugins` after edits.

To publish your fork, change `owner` in `.claude-plugin/marketplace.json` and the URLs in `plugin.json`. Keep the plugin name `dev-harness`.

## License

MIT. See [LICENSE](LICENSE).
