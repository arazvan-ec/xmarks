# flywheel research corpus

Reference material gathered to guide improvements to the **flywheel** plugin.
Everything here is **summarized in our own words from primary sources** (official
Claude Code docs and the claude-mem project docs), with source URLs on every
page so claims are traceable. It is not a verbatim copy of any source.

Compiled 2026-07-08.

## What's here

| File | What it covers |
| --- | --- |
| [`claude-code-loops.md`](claude-code-loops.md) | The official Claude Code loop primitives — `/goal`, `/loop`, `/schedule` (routines), parallel subagents, and dynamic workflows — with exact syntax, hard limits, and the model-routing / token-management guidance. |
| [`claude-mem.md`](claude-mem.md) | What **claude-mem** is and how it works end-to-end: automatic memory compression, the hook lifecycle, SQLite/FTS5 storage, the File Read Gate, and 3-layer retrieval. |
| [`token-efficiency.md`](token-efficiency.md) | The headline token-saving numbers — File Read Gate (~95%), Smart Explore (10–19×), 3-layer retrieval — and why they matter for flywheel. |
| [`flywheel-vs-claude-mem.md`](flywheel-vs-claude-mem.md) | Side-by-side comparison of flywheel's ledger-based compounding against claude-mem's memory infrastructure, and the concrete ideas flywheel could borrow. |
| [`improvement-proposals.md`](improvement-proposals.md) | The synthesized, prioritized roadmap of concrete flywheel improvements drawn from both bodies of research. |
| [`sources.md`](sources.md) | Consolidated list of every source URL, grouped by topic. |

The companion narrative reference, [`../getting-started-with-loops.md`](../getting-started-with-loops.md),
is the adapted version of the ClaudeDevs article that started this work.

## How to use this corpus

- **Deciding what to build next?** Start with [`improvement-proposals.md`](improvement-proposals.md);
  it ranks the options by value / effort / risk and links back to the evidence.
- **Implementing a loop feature?** [`claude-code-loops.md`](claude-code-loops.md)
  has the exact commands, caps, and provider caveats you need to get it right.
- **Working on memory / token efficiency?** [`claude-mem.md`](claude-mem.md) and
  the comparison show what a mature memory layer does and where flywheel's ledger
  falls short.

> Scope note: the numeric limits and version requirements below reflect the docs
> as read on 2026-07-08. Claude Code's routines and dynamic workflows are in
> research preview and may change — re-check the source pages before relying on a
> specific number.
