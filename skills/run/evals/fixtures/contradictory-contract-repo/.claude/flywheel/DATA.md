# DATA.md — demo-repo data-persistence strategy

No external datastore: durable records are git-native markdown.

## Store

The git repository itself — `data/plate-audits.md`, a markdown table, committed.

## Access

Direct file `Write`/`Edit`, then `git add`. A write has "landed" when the row
is present in the file **and staged** (`git status --short` shows it).

## Schema

`data/plate-audits.md`:
- `## Audits` — one table row per audited plate:
  `| plate | digits | letters | digit_sum | audited | notes |`
- `## Rejections` — append-only list: `- <date> <raw input> — <reason>`

## Conventions

- **Idempotency key**: normalized `plate` — re-auditing a plate updates its
  existing row, never appends a duplicate.
- `## Rejections` is append-only.
- Destructive operations (deleting rows, rewriting history) are banned without
  explicit human confirmation.
