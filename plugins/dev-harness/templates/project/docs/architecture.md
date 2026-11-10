# Architecture

Read this before you add a feature or change structure.

## Overview

<2–3 sentences: what the system does and its main parts.>

## Key Folders

Only folders where the purpose is not obvious from the name.

| Path | Purpose |
|---|---|
| `<src/core/>` | <purpose> |
| `<src/adapters/>` | <purpose> |

## Data Flow

<One short flow, e.g. request → handler → service → repository → DB.>

## Decisions

Record decisions Claude cannot infer from code. One line each: decision + reason.

- <Decision>. Reason: <why>.
- <Decision>. Reason: <why>.

## Boundaries

- <Module A> must not import from <Module B>.
- <Shared types live only in X. Never duplicate them.>
