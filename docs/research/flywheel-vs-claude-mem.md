# flywheel vs claude-mem vs gentle-ai

Three tools now occupy adjacent space. **flywheel** is a *disciplined-process*
Claude Code plugin (`spec → plan → work → verify → review → compound`, plus an
inner iterate-until-green loop) whose memory is a deliberately simple, curated
markdown ledger. **claude-mem** is *memory/token-efficiency infrastructure*
(automatic capture, AI compression, SQLite/FTS5 + a worker + the File Read Gate).
**gentle-ai** is a cross-agent *ecosystem configurator* (Go CLI) bundling
persistent memory (Engram), an SDD workflow, model routing, and delegation
triggers across 15 agents. See [`claude-mem.md`](claude-mem.md) and
[`gentle-ai.md`](gentle-ai.md) for the details.

## Side by side

| Dimension | flywheel | claude-mem | gentle-ai |
| --- | --- | --- | --- |
| Form factor | Claude Code plugin (markdown) | npm package + worker service | Go CLI / binary |
| Scope | Claude Code only | Claude Code (+ some agents) | 15 agents |
| Primary purpose | Disciplined dev loop + compounding | Memory + token-efficient retrieval | Ecosystem config: memory + SDD + routing |
| Knowledge capture | **Manual/curated** (`/compound`) | **Automatic** (every tool call, compressed) | **Automatic** (Engram, background) |
| What's stored | Plain markdown ledger | Structured observations + summaries | Engram observations (git-committable `.engram/`) |
| Storage engine | Flat markdown in the repo | SQLite + FTS5 (+ optional vectors) | Indexed `.engram/` store |
| Retrieval | Whole-file reload at SessionStart | Semantic/keyword, 3-layer disclosure | MCP `mem_context` / `mem_search` (selective) |
| Token efficiency on reads | No gate | File Read Gate (~95%) + Smart Explore (10–19×) | Selective injection (no published gate/benchmark) |
| Model routing | **None** (all agents `sonnet`) | Configurable compression model | **Per-phase routing** built in |
| Delegation heuristics | None | n/a | **Delegation triggers** (4-file / long-session rules) |
| Memory locality | Designed for **branch/PR-scoped repo content** | Global DB (project-filterable) | `.engram/` side store (git-committable) |
| Transparency | Fully human-readable, PR-reviewable | DB + viewer UI | TUI + human-inspectable store |
| Infra weight | **None** (no binary/service) | Worker service + DB | Go binary + MCP |
| Failure mode at scale | Reload cost grows (fixed per-session tax) | Bounded via search | Bounded via search |

## Net trade-off

flywheel's ledger is **transparent, versioned, and curated** — but manual,
uncompressed, and reloaded whole (a growing per-session tax with no relevance
filtering). claude-mem and gentle-ai are **automatic, indexed, and selective**
with real token savings — but heavier infra (a worker service / a Go binary),
less human-auditable, and they capture *everything* rather than curated lessons.

The productive design space for flywheel is to **keep the curated, git-native
ledger as the source of truth** while borrowing the others' *selectivity* and
*token discipline* — analyzed in [`strategy-build-vs-integrate.md`](strategy-build-vs-integrate.md).

## Ideas flywheel could adopt

1. **Retrieval over whole-file reload** — inject only the top-N ledger entries
   relevant to the current branch/spec (a grep/flat index; no DB required). → P2
2. **Progressive disclosure** — load titles first; expand on demand via
   `/flywheel:recall <query>`. → P2
3. **Structured, typed entries** — metadata (type/files/date/spec-PR link) for
   cheap filtering, without abandoning markdown. → P2
4. **A File-Read-Gate analogue** keyed to learnings (advisory PreToolUse hook). → P3
5. **Model routing by role/phase** — validated by both claude-mem (Haiku for
   compression) and gentle-ai (per-phase routing). → P1
6. **Delegation triggers** (from gentle-ai) — concrete thresholds for *when* to
   spin up a fresh-context subagent (4-file rule, long-session rule). → **P7**
7. **Semi-automatic capture** — auto-draft candidate learnings at verify/review/
   Stop into a staging area a human promotes. → P2

Full evidence: [`token-efficiency.md`](token-efficiency.md), [`claude-mem.md`](claude-mem.md), [`gentle-ai.md`](gentle-ai.md).
