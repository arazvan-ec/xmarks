# claude-mem token-efficiency evidence

The headline numbers behind claude-mem's "don't waste tokens" pitch, summarized
from its docs (2026-07-08). These are the empirical case for the ideas flywheel
could borrow (see [`improvement-proposals.md`](improvement-proposals.md)).

## File Read Gate

Substituting a compact timeline for a full file read:

| | Full read | Gate (timeline) |
| --- | --- | --- |
| Tokens (typical) | 5,000–50,000 | ≈370 |
| Cited real example | 18,000 | 970 (**~95% reduction**) |
| Even fetching 3 observations | — | ~1,270 (still **75–97%** savings) |

Trigger conditions: file > 1,500 bytes, project not excluded, prior observations
exist. It returns a timeline + up to 15 ranked observations with escalating
options (free priming → ~300 tok/obs → smart tools 1–2k → full read).

Source: <https://docs.claude-mem.ai/file-read-gate.md>

## Smart Explore benchmark

Test: the claude-mem codebase itself (194 TS files, 1,206 symbols), model
Claude Opus 4.6, baseline "Explore agent" barred from Smart Explore tools.

| Scenario | Smart Explore | Traditional | Advantage |
| --- | --- | --- | --- |
| Discovery (cross-file) | ~14,200 tok | ~252,500 tok | **17.8×** cheaper |
| Targeted reads | ~5,650 tok | ~109,400 tok | **19.4×** cheaper |
| End-to-end combined | ~4,200 tok | ~45,000 tok | **10–12×** cheaper |
| Speed | <2s/call | 5–66s/call | **10–30×** faster |

The baseline needed **101 tool calls** for 5 discovery queries (15–37 each);
Smart Explore answered the combined workflow in ~2 calls.

Source: <https://docs.claude-mem.ai/smart-explore-benchmark.md>

## 3-layer retrieval economics

| Layer | Tool | Cost |
| --- | --- | --- |
| 1 Index | `search` | ~50–100 tok/result |
| 2 Context | `timeline` | ~100–200 tok/observation |
| 3 Details | `get_observations` | ~500–1,000 tok/observation |

vs traditional RAG fetching ~20 observations upfront (10k–20k tokens at ~10%
relevance ≈ 18k wasted). The 3-layer flow totals ~2,500–5,000 tokens (**~50–75%
savings**, ~10× efficiency).

Source: <https://docs.claude-mem.ai/architecture/search-architecture.md>

## Why this matters for flywheel

flywheel's SessionStart hook reloads the **entire** `LEARNINGS.md` ledger every
session (capped at ~50 lines today, but growing and undifferentiated). The
numbers above are the argument for two changes: (1) **retrieve only what's
relevant** instead of reloading whole, and (2) **surface prior learnings before
an expensive file read**. See the comparison and proposals.
