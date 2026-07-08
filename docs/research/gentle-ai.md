# gentle-ai — reference

Summarized from the gentle-ai GitHub repo and docs (2026-07-08). Consulted while
evaluating flywheel against the broader landscape.

## What it is

An **"ecosystem configurator" for AI coding agents** (from *Gentleman
Programming*), written in Go (CLI). It's not an agent — it layers **persistent
memory + a spec-driven workflow + a skills registry + per-phase model routing +
MCP integration + security-first personas** onto existing agents. It targets
**15 agents** (Claude Code, OpenCode, Cursor, Gemini CLI, VS Code Copilot, Codex,
Windsurf, Antigravity, and more), from "full delegation" to "solo-agent".

Maturity signals: ~**4.7k stars**, **224+ releases**, **v1.44.0** (Jul 2026),
MIT, Go 95%. Actively maintained.

## Engram (persistent memory)

- **Automatic capture** — saves decisions/discoveries/context in the background
  ("without you doing anything"); `mem_save` captures the prompt best-effort.
- **Storage** — a `.engram/` directory that can be **committed to git**;
  project-indexed with observation counts and dedup. Human-inspectable (not
  opaque embeddings).
- **Retrieval/injection** — via **MCP tools**: `mem_context` (recent session
  history, called at session start → selective, not whole-ledger) and `mem_search`
  (keyword). CLI: `engram tui` (browse), `engram search`, `engram sync`
  (export/import team memories), `engram projects`.

*How it differs from flywheel's ledger:* Engram is automatic, indexed,
searchable, and cross-project; flywheel's `LEARNINGS.md` is manual/curated,
plain-markdown, and reloaded whole. Note both can be git-committed — but Engram's
`.engram/` is a side store, whereas flywheel's ledger is designed to be
**branch/PR-scoped repo content** (see [strategy](strategy-build-vs-integrate.md)).

## SDD workflow (spec-driven development)

Six phases — **explore → propose → spec → design → implement → verify** — but
**deliberately non-prescriptive** ("Small request? The agent just does it. No
ceremony."). The orchestrator is a **delegating conductor**: it resolves the
skill registry once and passes the relevant `SKILL.md` paths + one concrete role
into each sub-agent (each a "full agent with its own session, tools, and
context").

### Delegation triggers (the standout idea → flywheel P7)

Concrete thresholds for *when* to delegate to a fresh-context sub-agent:
- **"4-file rule"** — reading 4+ files warrants delegating exploration.
- **"Multi-file write rule"** — touching 2+ non-trivial files requires a fresh
  review before completion.
- **"Long-session rule"** — after ~20 tool calls or ~5 exploratory reads, pause
  and re-plan.
- Plus PR-prep, incident-recovery, and adversarial-review triggers.

### Per-phase model routing

Assign different models to different phases — "a powerful model for design and a
faster one for implementation" — where the agent supports it. (This is flywheel
**P1** validated in a mature, popular tool.)

### Verification / review

A **"fresh review rule"** requires fresh context for adversarial review of diffs,
conflicts, and PR readiness — gates before commit/push. (flywheel already does
this via its parallel `reviewer-*` agents.)

## Relevance to flywheel

- **Validates** P1 (per-phase/role model routing) and the selective-memory
  direction (P2/P3).
- **Adds** P7 (delegation triggers) — a concrete idea flywheel lacked.
- **Sharpens** the build-vs-integrate question: with Engram *and* claude-mem
  mature, flywheel should differentiate (git-native curated memory) rather than
  reinvent — see [`strategy-build-vs-integrate.md`](strategy-build-vs-integrate.md).
- **Contrast in philosophy:** gentle-ai is intentionally low-ceremony/adaptive;
  flywheel is high-discipline with hard gates + a deterministic `Stop`-hook. A
  product choice, not a defect on either side.

## Sources

- Repo — <https://github.com/Gentleman-Programming/gentle-ai>
- Intended usage / SDD — <https://github.com/Gentleman-Programming/gentle-ai/blob/main/docs/intended-usage.md>
- Engram — <https://github.com/Gentleman-Programming/gentle-ai/blob/main/docs/engram.md>
- Architecture — <https://github.com/Gentleman-Programming/gentle-ai/blob/main/docs/architecture.md>
- Skill registry — <https://github.com/Gentleman-Programming/gentle-ai/blob/main/docs/skill-registry.md>
