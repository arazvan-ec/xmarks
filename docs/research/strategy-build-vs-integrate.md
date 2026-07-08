# Strategy: build vs integrate — and the git-native memory bet

The central strategic question for flywheel's memory/token-efficiency work
(backlog P2/P3). Started 2026-07-08; **status 🟡 in progress** — this is a
discussion document, not a decision yet. See the [journal](journal.md) threads
T1/T2.

## The question (Q3)

Both **claude-mem** (SQLite/FTS5 + a worker service + the File Read Gate) and
gentle-ai's **Engram** (automatic capture, a git-committable `.engram/` store,
MCP `mem_context`/`mem_search`, a TUI) already exist and are mature. So: should
flywheel **build** its own memory infrastructure, **integrate** one of theirs, or
**differentiate** with a lighter approach?

## Three options

### Option A — Build our own memory infra
Reinvent the stack: a SQLite/FTS5 sidecar, MCP search tools, a blocking
file-read gate.
- **Pros:** full control; best-in-class token savings if done well.
- **Cons:** we'd be re-building claude-mem/Engram from scratch and competing
  head-on with two mature projects; it breaks flywheel's "pure-markdown plugin,
  no binaries, no services" identity; high effort, high maintenance. **Not
  recommended.**

### Option B — Integrate an existing system
Depend on / defer to claude-mem or Engram for memory; flywheel focuses on its
process discipline (`spec → … → compound` + gates).
- **Pros:** don't reinvent; users get mature memory immediately.
- **Cons:** a heavy external dependency (worker service or Go binary) coupled to
  another project's lifecycle; it breaks the vendored/web install path (a
  markdown-only plugin can't require a background worker); flywheel loses control
  of a core value (the learnings ledger). Viable only as an **opt-in interop**,
  not a hard dependency.

### Option C — Differentiate: git-native curated memory ⭐ (recommended)
Lean into what flywheel uniquely is. Keep memory **plain-markdown, curated, and
committed to the repo** — but borrow the *selectivity* and *token discipline*
from the others without their infrastructure.

## Why git-native is a real differentiator (not a limitation)

claude-mem and Engram optimize for **automatic recall of everything** into a
global or side store (a DB / `.engram/`). flywheel can optimize for something they
don't: **curated, reviewable, versioned team knowledge that lives inside the repo
and travels with the code.** That is a distinct product, not a worse one.

Unique properties of the git-native approach:

- **Curated, high-signal** — only vetted learnings land (via `/flywheel:compound`),
  so the reloaded context is signal, not raw capture noise.
- **Git-diffable & PR-reviewable** — learnings are reviewed like code; bad ones
  get caught in review. Neither a DB nor `.engram/` gives you a PR diff of "what
  the agent decided to remember."
- **Branch/PR-scoped** — the killer property: learnings live on the branch that
  produced them and **merge with the code**. A decision made while building
  feature X arrives, in context, with feature X. Global stores can't do this.
- **Zero-infra** — no binary, no worker, no port. It therefore **works in web /
  vendored sessions**, which is exactly where a background service can't run.
- **Portable** — clone the repo, get the memory. No separate install/sync.

This also matches flywheel's stated lineage (it cites *compound engineering*):
knowledge that compounds **in the repo**, reviewed like code, is the whole idea.

## Concrete design (git-native, dependency-free)

How to get claude-mem's *selectivity* while staying markdown-only:

1. **Storage** — stays plain markdown, committed: `.claude/flywheel/LEARNINGS.md`
   (optionally split into `.claude/flywheel/learnings/*.md` per topic as it grows).
2. **Curation** — `/flywheel:compound` remains the vetted writer. Optionally, a
   `Stop`-hook drafts a candidate ("what we learned this session") into a staging
   area that a human promotes — automatic *capture*, human *curation*.
3. **Structure** — typed entries with light metadata (type:
   bugfix/decision/gotcha/pattern; files touched; date; spec/PR link). Enables
   cheap filtering without a DB.
4. **Selective injection without a DB** — the `SessionStart` hook greps the typed
   entries and injects **only those matching the current branch / spec / changed
   files**, not the whole file. A generated flat index (e.g. a `.tsv` of
   `title \t files \t date \t anchor`) gives claude-mem-style progressive
   disclosure with zero binary dependency.
5. **File-read priming (P3)** — an **advisory** `PreToolUse` hook that surfaces
   the git-native learnings for a file *before* an expensive read. The
   flywheel-native, dependency-free analogue of the File Read Gate (advisory, so
   it never blocks — lower risk than claude-mem's blocking gate).
6. **Interop, not dependency** — optionally *detect* claude-mem/Engram and defer
   to them when present (best of both worlds), but **never require** them.

## Trade-offs, honestly

- **Pros:** zero infra; works everywhere (web/vendored); diffable/reviewable;
  branch/PR-scoped; curated (high signal); portable with the repo.
- **Cons:** keyword/grep retrieval, **no semantic search** (could add an optional
  embeddings sidecar later if ever needed); **curated, not exhaustive** by design
  (that's the point, but it means some context isn't auto-captured); at large
  history sizes it needs an **archive/rotation** policy to keep injection cheap.

## Recommendation

**Option C.** Borrow the *ideas* — selective injection, model routing, delegation
triggers, read-priming — not the *infrastructure*. Keep flywheel lightweight,
git-native, and curated; offer opt-in interop with claude-mem/Engram for teams
that already run them.

## Open questions to resolve together

- Is keyword/grep selectivity enough, or do we ever want an **optional** embeddings
  add-on (kept out of the default, to preserve zero-infra)?
- Semi-automatic capture: how aggressive, and exactly where does the human gate
  sit (promote-to-ledger step)?
- Do we ship the optional claude-mem/Engram interop, or stay fully standalone for
  now?
- Rotation/archival policy: when does an entry move from "injected" to "archived
  but searchable"?
