# Git-native memory — concrete design

The "how" behind [`strategy-build-vs-integrate.md`](strategy-build-vs-integrate.md)
Option C. This is an **accepted design (✅ — decisions locked 2026-07-08)** for
backlog items P2 (smarter ledger) and P3 (read-priming hook). **Implementation is
still pending — no plugin code has been changed yet.** It specifies a memory layer
that gives claude-mem-style *selectivity* while staying pure markdown, committed
to git, and dependency-free (works in web/vendored installs).

Goal: kill the "reload the whole ledger every session" tax without a database,
worker, or binary.

## 1. Typed entry format

Today `/flywheel:compound` appends free prose to `.claude/flywheel/LEARNINGS.md`,
and `scripts/session-start.sh` injects up to ~50 lines of it verbatim. The new
format keeps it plain markdown but adds a **greppable metadata line** so entries
can be filtered without parsing prose:

```markdown
## gotcha: logout didn't clear the session cookie
<!-- fw: type=gotcha; date=2026-07-08; files=src/auth/login.ts,src/auth/session.ts; spec=user-login; pr=42; branch=feature/login -->

Session cookies survived logout because the redirect fired before `clearSession()`.
Fix: await `clearSession()` before `res.redirect`. Root cause: fire-and-forget in
the handler. Guard: added a test asserting no `Set-Cookie` on the logout response.
```

- **H2 title:** `## <type>: <one-line title>` — human-scannable.
- **Metadata comment:** a single `<!-- fw: k=v; … -->` line. HTML comments are
  **render-invisible, git-diffable, and greppable** — the key trick. Keys:
  `type` (decision|gotcha|pattern|bugfix), `date`, `files` (comma list), `spec`,
  `pr`, `branch`. All optional except `type` + `date`.
- **Body:** the learning — what/why/fix/guard, as prose. Unchanged ethos.

Backward-compatible: old free-prose entries still load; they just don't get
filtered (treated as always-eligible, low priority).

## 2. Selection & injection at SessionStart (no DB)

`scripts/session-start.sh` gains a **relevance pass** instead of a blind
50-line dump. It shells out to `git` (already available) to compute the current
context and grep the metadata lines:

1. **Context** — `branch = git branch --show-current`; `changed = git diff
   --name-only <base>...HEAD` + uncommitted; `spec =` the active spec slug under
   `.claude/flywheel/specs/` if any.
2. **Score each entry** — `+3` if `files ∩ changed`; `+2` if `branch` or `spec`
   matches; `+1` recency (last ~30 days). Ties broken by date.
3. **Inject a budget** — the **top N full entries** (default `N=12`, env
   `FLYWHEEL_LEARNINGS_INJECT`), then a **one-line pointer** for the rest:
   `… 37 more learnings — run /flywheel:recall <query> to pull specifics.`
   This mirrors claude-mem's "relevant full context + cheap index of the rest".

Everything stays a fast, fail-open shell step (the hook's existing contract:
read-only, idempotent, always exit 0). Grep over a markdown file is trivially
cheap at realistic ledger sizes; an optional generated index (§5) is only for
very large ledgers.

## 3. `/flywheel:recall <query>` — progressive disclosure

A new skill (must be added to the README table + `/flywheel:help` per the
docs-consistency test). Behavior:

- **Layer 1 (cheap):** grep titles + metadata for the query; print a numbered
  list of matching `type: title (date, files)` — a few tokens each.
- **Layer 2 (on demand):** the user/agent asks for an entry's number → print the
  full body. Analogous to claude-mem `search` → `get_observations`, but grep over
  markdown instead of FTS5.

This is what lets injection stay small: anything not auto-injected is one cheap
`/recall` away.

## 4. `/flywheel:compound` writes the typed format

Update `skills/compound/SKILL.md` so each captured learning is emitted in the §1
format (it already knows the files touched, the spec, and can read the branch/PR).
No behavior change for the human — just a stricter template.

**Optional semi-auto capture:** a `Stop`-hook (flywheel already ships a Stop hook)
drafts a candidate entry ("what we learned this session") into
`.claude/flywheel/LEARNINGS.staging.md`. It is **never** auto-promoted; the human
runs `/flywheel:compound` to review and move it into the ledger. Automatic
*capture*, human *curation* — the flywheel differentiator preserved.

## 5. Optional flat index (only if needed at scale)

If a ledger ever gets big enough that grep-on-every-SessionStart is noticeable,
`/compound` can also append to `.claude/flywheel/learnings.tsv`:

```
anchor	type	date	files	spec	pr	branch	title
```

Still plain text, still git-diffable, no binary. It's a cache of the metadata
lines — rebuildable from the ledger by a script, so it can never be the source of
truth. **Default: no index; grep the ledger directly.** Add only if measured.

## 6. Read-priming hook (P3) — advisory File-Read-Gate analogue

A **`PreToolUse`** hook on `Read`: before reading file `F`, grep the ledger for
entries whose `files` contains `F`; if any, inject them as a short note
("flywheel: 2 prior learnings touch this file: …"). Key differences from
claude-mem's gate, chosen to stay low-risk:

- **Advisory, never blocking** — the read still happens; we just prime cheap
  context first. (claude-mem *blocks* the read; we don't.)
- **Fast + fail-open** — a `PreToolUse` hook fires on every read, so it must be
  cheap and never error the tool call.
- Optional size threshold later (claude-mem uses 1,500 bytes) if we ever add
  actual read substitution.

Depends on §1 (typed `files=` metadata), so **sequence P2 → P3**.

## 7. Rotation / archival

To keep SessionStart injection bounded as history grows: when the ledger passes a
threshold (entries or bytes), `/compound` moves the oldest low-relevance entries
to `.claude/flywheel/learnings-archive/YYYY-QN.md`. Archived entries stay in git
and remain searchable by `/recall` (which greps the archive too) but are **not**
auto-injected. Injection cost stays flat; nothing is lost.

## 8. Opt-in interop (not a dependency)

SessionStart can *detect* a richer memory system and step aside/complement:

- **claude-mem** present (worker health / its MCP tools available) → note it; let
  its `mem_context` handle broad recall while flywheel injects only its curated,
  branch-scoped learnings.
- **Engram** present (`.engram/` dir) → same idea.

flywheel **never requires** either; interop is a bonus for teams already running
them.

## 9. What changes, file by file (when we build it)

| File | Change |
| --- | --- |
| `skills/compound/SKILL.md` | Emit the §1 typed format; optional staging draft |
| `scripts/session-start.sh` | Relevance pass + budgeted injection (§2) |
| `skills/recall/` (new) | The `/flywheel:recall` skill (§3) + README/help entry |
| `hooks/hooks.json` + new `scripts/read-prime.sh` | Advisory read-priming (§6) |
| `scripts/install-vendored.sh` + `scripts/test-install-vendored.sh` | Vendor + assert the new hook script |
| `.claude-plugin/plugin.json` + `upgrades/vX.Y.Z.md` | Version bump + migration note |

Suggested split into releases: **P2** (§1–§4, the ledger) first; **P3** (§6) next;
§5/§7/§8 as follow-ups once the core is proven.

## Decisions (locked 2026-07-08)

- **Index (§5):** grep the ledger live; **no `.tsv` index** until a measured need.
- **Semi-auto staging (§4):** **deferred** — the first P2 release ships the typed
  format + selective injection + `/recall` only.
- **Relevance scoring (§2):** branch/files/recency is enough for v1; embeddings
  stay a possible **optional** future add-on, kept out of the default.
- **Interop (§8):** **deferred** — land the standalone git-native core first.

Net: the first **P2 release is deliberately small** — typed entries in
`/flywheel:compound`, budgeted relevance injection in `session-start.sh`, and the
`/flywheel:recall` skill. **P3** (read-priming) follows (it needs the `files=`
metadata); §5/§7/§8 are later follow-ups only if measured need arises.
