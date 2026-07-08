# flywheel vs claude-mem

Both persist learnings across sessions and reload them at session start, but they
sit at opposite ends of the spectrum. **flywheel** is a *disciplined-process*
plugin (`spec → plan → work → verify → review → compound`, plus an inner
iterate-until-green loop) whose memory is a deliberately simple, human-readable
markdown ledger. **claude-mem** is *memory/token-efficiency infrastructure* with
automatic capture, AI compression, and searchable storage.

## Side by side

| Dimension | claude-mem | flywheel |
| --- | --- | --- |
| Primary purpose | Persistent memory + token-efficient retrieval infra | Disciplined dev loop; compounding via a learnings ledger |
| Knowledge capture | **Automatic** — every tool call compressed; auto session summaries | **Manual/curated** — `/flywheel:compound` writes learnings |
| What's stored | Structured observations (title/narrative/facts/type/concepts/files) + summaries + prompts | Plain markdown notes in `.claude/flywheel/LEARNINGS.md` |
| Storage engine | **SQLite + FTS5** (+ optional Chroma vectors) | **Flat markdown file** in the repo |
| Retrieval | **Semantic/keyword search**, 3-layer progressive disclosure | **Whole-file reload** at SessionStart |
| Selectivity | Query-scoped, ranked, type/date/project filters | None — all-or-nothing whole-file load |
| Token efficiency on reads | **File Read Gate** (~95%) + Smart Explore (10–19×) | No gate; normal full reads |
| Compression | AI-compresses raw tool I/O (Haiku default) | None — raw human prose |
| Scope | Global cross-project DB (filterable) | Per-repo, committed to source control |
| Model handling | Configurable compression model/provider | Agents pinned to one model (`sonnet`) |
| Transparency | DB + viewer UI; less human-editable | Fully human-readable, git-diffable, PR-reviewable |
| Failure mode at scale | DB grows but retrieval stays bounded | Ledger reload cost grows linearly — a fixed per-session tax |

## Net trade-off

flywheel's ledger is **transparent, versioned, and curated** — only vetted
learnings land, and they're reviewable in git — but it's manual, uncompressed,
and reloaded whole, so its per-session token cost grows with the file and it
can't retrieve *only* what's relevant. claude-mem is **automatic, compressed, and
searchable** with strong token savings — but it's heavier infra (worker service,
DB, MCP), less human-auditable, and captures everything (noise included) rather
than curated lessons.

The interesting design space for flywheel is to **keep the curated,
git-native ledger as the source of truth** while borrowing claude-mem's
*retrieval selectivity* and *token discipline*.

## Ideas flywheel could adopt

1. **Retrieval over whole-file reload.** Index `LEARNINGS.md` entries (a
   lightweight grep/FTS index, or a small SQLite/FTS5 sidecar) and have the
   SessionStart hook inject only the top-N relevant to the current
   branch/spec/task — capping the growing reload tax.
2. **Progressive disclosure.** Store a one-line title per learning; load titles
   first, expand full detail on demand via a `/flywheel:recall <query>` command
   (analogous to `search` → `get_observations`).
3. **Structured, typed entries.** Give each ledger entry lightweight metadata
   (type: bugfix/decision/gotcha/pattern; files; date; spec/PR link) to enable
   filtering without abandoning the markdown-first ethos.
4. **A File-Read-Gate analogue keyed to learnings.** A PreToolUse hook that, when
   about to read a file with recorded learnings, first surfaces the relevant
   ledger entries — cheap context before an expensive read. High ROI, cheap to
   prototype.
5. **Semi-automatic capture.** Auto-draft candidate learnings from the
   verify/review stages into a staging area the human promotes — claude-mem's
   automatic capture + flywheel's curation discipline.
6. **Compress verbose entries.** An occasional cheap-model pass to condense/merge
   redundant ledger entries, keeping reloaded context high-signal.
7. **Cap / rotate the injected context.** An explicit budget (inject only the N
   most recent or most relevant), archiving older entries but keeping them
   searchable — so compounding never silently degrades the attention budget.

Full evidence: [`token-efficiency.md`](token-efficiency.md), [`claude-mem.md`](claude-mem.md).
