#!/usr/bin/env bash
# PostToolUse (Edit|Write|MultiEdit)
# Formats the edited file with the project's own formatter, if one exists.
# Never blocks: always exits 0.

input=$(cat)
file=$(jq -r '.tool_input.file_path // empty' <<<"$input")
[ -z "$file" ] || [ ! -f "$file" ] && exit 0

root="${CLAUDE_PROJECT_DIR:-$PWD}"

case "$file" in
  *.js|*.jsx|*.ts|*.tsx|*.json|*.css|*.scss|*.md|*.html|*.yml|*.yaml)
    [ -x "$root/node_modules/.bin/prettier" ] && "$root/node_modules/.bin/prettier" --write "$file" >/dev/null 2>&1 ;;
  *.py)
    command -v ruff >/dev/null 2>&1 && ruff format "$file" >/dev/null 2>&1 ;;
  *.go)
    command -v gofmt >/dev/null 2>&1 && gofmt -w "$file" >/dev/null 2>&1 ;;
  *.rs)
    command -v rustfmt >/dev/null 2>&1 && rustfmt "$file" >/dev/null 2>&1 ;;
esac

exit 0
