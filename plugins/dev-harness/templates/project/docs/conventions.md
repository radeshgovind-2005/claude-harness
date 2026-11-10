# Conventions

Only rules that differ from language defaults, or that tools do not enforce.
If a linter or formatter enforces a rule, do not write it here.

## Naming

- <Files: kebab-case.ts>
- <Branches: `<type>/<short-description>`, e.g. `fix/login-timeout`>

## Code

- <Use named exports only. No default exports.>
- <Errors: throw typed errors from `src/errors/`. Never throw strings.>

## Tests

- <Test files live next to source: `foo.ts` → `foo.test.ts`.>
- <Test behavior, not implementation details.>

## Do Not

- <Do not add a new dependency without asking.>
- <Do not use `any`. Use `unknown` and narrow it.>
