# Data strategy and repo extensions

Reference for `/flywheel:process` steps 1 and 4.

## Step 1 — establishing DATA.md

Read `.claude/flywheel/DATA.md`. **If it is missing, create it first**. Detect how this repo persists data before asking the user, by looking for (in order): `DATABASE_URL`/`*_DATABASE_URL` env or `.env(.example)`, `prisma/schema.prisma`, `drizzle.config.*`, `knexfile.*`, `sequelize`/`typeorm` config, `supabase/config.toml`, a `postgres`/`mysql` service in `docker-compose*.yml`, `*.sql` migrations, or an ORM in `package.json`/`requirements.txt`/`pyproject.toml`. Confirm the finding with the user. **No signal is itself a detection**, not a failure to detect: propose the git-native store — durable records as committed markdown/JSON under `data/<process>/`, a write proven by the file carrying the row **and staged** — and ask only to confirm. Open-ended is for conflicting signals, never for none.

**Probe the Access before you write it.** Read-only, with the very tool you are about to name: the connection opens and the target exists; a file store, the directory is writable and inside the repo. Never a test row. If the probe fails, DATA.md is **not written** — name the check that failed and offer the git-native store instead.

Write `.claude/flywheel/DATA.md` with:
- **Store** — the backend (e.g. `PostgreSQL`).
- **Access** — exactly how a run writes to it: the concrete tool/command (`psql "$DATABASE_URL"`, a Postgres/Supabase MCP server + project ref, `npm run db:exec`, an ORM script…). Name the one a run should use.
- **Schema** — the tables/columns processes read and write, or a pointer to the migrations that define them.
- **Conventions** — idempotency key, timestamps, a `flywheel_runs` metadata table if the repo wants run bookkeeping, and safety rules (transactions; never `DROP`/`DELETE`/`TRUNCATE` without explicit human confirmation).

## Step 4 — what an extension doc states

A repo can extend *how* agents intervene in it beyond the fixed contract shape — runtime profiles for multiple competing AIs, branch/PR policy, review gates, capability fallbacks. These conventions are **repo-owned**: they live in `.claude/flywheel/extensions/<name>.md`,, repo-owned.

- An extension doc states: `name`, `applies-to` (all processes or named slugs), the inputs/conventions it adds, its guardrails, and its own append-only Improvement log.
- Before writing or revising a contract, read the repo's `extensions/`; declare the ones the contract honors in its frontmatter (`extensions: [profiles, …]`). The contract stays the source of truth for its Rules; the extension is the source of truth for the shared convention — don't duplicate its text into every contract.
- When the owner asks for a **cross-cutting intervention pattern** (e.g. "the same process run by different AI runtimes with comparable outputs"), the deliverable is an extension doc, not per-contract prose — write it, wire it via frontmatter, and let runs mature it in place.

## Step 5 — maturing an existing process

If `$ARGUMENTS` names a process that already exists, do not recreate it — treat this as a **deliberate revision**: read the contract and its Improvement log, apply the requested change to Rules/Output schema/Persistence, bump `version`, and record the change in the Improvement log. Never silently rewrite the fixed rules.

Append the entry in exactly this shape:

```
### <YYYY-MM-DD> — <one-line what changed>
<why, from this revision's evidence>
```
