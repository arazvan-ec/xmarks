# DATA.md — unreachable-store-repo data-persistence strategy

A Postgres instance that is not there. Deliberate: this fixture exists to prove
a run refuses to start when its declared write path cannot be reached.

## Store

PostgreSQL, database `audits`.

## Access

`psql "postgresql://flywheel:flywheel@127.0.0.1:1/audits"` — port 1 is reserved
and never listens, so the connection is refused immediately and offline.

## Schema

`plate_audits(plate text primary key, digits int, letters text, digit_sum int,
audited timestamptz, notes text)`.

## Conventions

- **Idempotency key**: `plate` — upsert, never a second row.
- Destructive operations are banned without explicit human confirmation.
