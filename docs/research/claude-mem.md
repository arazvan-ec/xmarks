# claude-mem — reference

Summarized from the claude-mem project docs and README (2026-07-08). claude-mem
(by *thedotmack*) is a **persistent memory-compression layer for Claude Code**
and other agents. Its own hero line is "Persistent memory compression system for
Claude Code"; the social pitch behind this research — *"What if you used
Claude-Mem and DIDN'T waste tokens looping for no reason"* — is marketing framing,
but the substance is real and is what makes it relevant to flywheel.

Sources: <https://github.com/thedotmack/claude-mem>, <https://docs.claude-mem.ai/introduction.md>

---

## The token-waste problem it targets

Two distinct kinds of waste:

1. **Lost-continuity waste** — when a session ends or compacts, project knowledge
   is lost, so the agent re-derives what it already learned (re-reading files,
   re-running greps, re-investigating architecture) every new session. claude-mem
   persists compressed observations and re-injects them at session start.
2. **Exploration-loop waste** — agents burn tokens "looping": repeatedly reading
   whole files and fanning out searches to understand code. claude-mem attacks
   this with the **File Read Gate** and **Smart Explore** (AST + progressive
   disclosure), delivering the same understanding for a fraction of the tokens.

The underlying philosophy is context engineering: find the smallest set of
high-signal tokens, because a model's effective attention degrades as context
grows — so prefer just-in-time retrieval over loading everything up front.

Sources: <https://docs.claude-mem.ai/context-engineering.md>

---

## How it works end-to-end

**Components:** (a) plugin **hooks** capturing lifecycle events; (b) a **worker
service** (local HTTP API) that does AI compression via the Claude Agent SDK;
(c) a **SQLite + FTS5 database** at `~/.claude-mem/claude-mem.db`; (d) **MCP
search tools** for progressive-disclosure retrieval; (e) a React viewer UI.

**Data flow:** Claude Code pipes tool-execution data → hooks write raw
observations to SQLite → the worker compresses raw tool I/O into structured
semantic **observations** (title, narrative, key facts, files touched, a `type`
like bugfix/feature/refactor/discovery/decision, and `concepts` like
how-it-works/gotcha/pattern) → summaries go back to the DB → later sessions
retrieve and inject them. The compression model defaults to **`claude-haiku-4-5`**
(cheap), configurable to Gemini/OpenRouter.

**The 5-stage hook lifecycle:**

1. **SessionStart** — starts the worker, queries recent observations (default
   ~50 from the current project across ~10 recent sessions), and injects them
   silently via `hookSpecificOutput.additionalContext`.
2. **UserPromptSubmit** — creates/retrieves the DB session (idempotent by
   `session_id`), strips `<private>` tags, saves the prompt.
3. **PostToolUse** — after *every* tool, fire-and-forget POST (2s timeout) so the
   IDE never blocks; the worker compresses asynchronously.
4. **Stop** — extracts the final transcript and queues an async structured
   **session summary** (what was requested / investigated / discovered /
   completed / next steps).
5. **SessionEnd** — marks the session complete and notifies the UI.

**Storage:** SQLite via `bun:sqlite`. Tables: `sdk_sessions`, `observations`,
`session_summaries`, `user_prompts`. **FTS5** virtual tables index observations,
summaries, and prompts (kept in sync by triggers); queries support phrases and
AND/OR/NOT. An optional **Chroma** vector store adds hybrid semantic search.

Sources: <https://docs.claude-mem.ai/architecture/overview.md>, <https://docs.claude-mem.ai/architecture/hooks.md>, <https://docs.claude-mem.ai/architecture/database.md>

---

## The File Read Gate (see also `token-efficiency.md`)

A **PreToolUse hook** that intercepts file reads. If prior observations exist for
a file (and it is > **1,500 bytes**, and the project isn't excluded), it **blocks
the raw read** and returns a compact **timeline of past work** on that file plus
up to **15 ranked observations**, with four escalating options: semantic priming
(free) → fetch observations (~300 tok each) → smart tools (~1–2k) → full read
(5k–50k). The timeline costs ≈**370 tokens** vs 5,000–50,000 for the full file — a
cited real case went **18,000 → 970 tokens (~95% reduction)**.

Sources: <https://docs.claude-mem.ai/file-read-gate.md>

---

## Retrieval: the 3-layer progressive-disclosure workflow

The MCP memory-search tools implement a cheap→expensive escalation:

- **`search`** (Layer 1, index) — keyword/phrase query, ~50–100 tok/result;
  always start here.
- **`timeline`** (Layer 2, context) — narrative arc around an anchor, ~100–200
  tok/observation.
- **`get_observations`** (Layer 3, details) — full detail for validated IDs,
  ~500–1,000 tok/observation.

vs traditional RAG that fetches ~20 observations upfront (10k–20k tokens at ~10%
relevance): the 3-layer flow totals ~2,500–5,000 tokens (~50–75% savings).

Sources: <https://docs.claude-mem.ai/architecture/search-architecture.md>, <https://docs.claude-mem.ai/usage/search-tools.md>

---

## Config highlights

Env vars in `~/.claude-mem/settings.json`: `CLAUDE_MEM_MODEL`
(default `claude-haiku-4-5-…`), `CLAUDE_MEM_PROVIDER`, `CLAUDE_MEM_CONTEXT_OBSERVATIONS`
(50), `CLAUDE_MEM_CONTEXT_SESSION_COUNT` (10), `CLAUDE_MEM_CONTEXT_OBSERVATION_TYPES`
/ `..._CONCEPTS` (filtering), `CLAUDE_MEM_EXCLUDED_PROJECTS`. Privacy: wrap content
in `<private>` tags to exclude from capture.

Sources: <https://docs.claude-mem.ai/configuration.md>

---

## Note on `docs.claude-mem.ai/branches`

That page (which the task referenced) is **not** a memory feature — it documents
claude-mem's **release branches** (`main` stable → npm; `core-dev` and
`community-edge` source-only), i.e. its promotion workflow. It has no bearing on
memory/token behavior.

Sources: <https://docs.claude-mem.ai/branches.md>
