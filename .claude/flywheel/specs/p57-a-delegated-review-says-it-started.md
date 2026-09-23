# Spec: P57 — a delegated review says it started

**Slug:** `p57-a-delegated-review-says-it-started` · **Created:** 2026-09-23 · **Backlog:** P57
**Status:** in progress

**Prime:** `scripts/delegation-guard.sh` (P37/P41 ask-only contract), and PR #95.

## R — Requirements

On PR #95 a `/code-review 95 --comment` session was launched in a new cloud
session. It went idle after 8 minutes having posted nothing — the container had
no `gh` and it did not reach for the GitHub MCP tools — and the parent could not
tell "found nothing", "could not post" and "still running" apart, because a
silent child looks identical in all three. The owner asked for a template so a
delegated review always **confirms its start on the PR** (a "review started"
comment first thing), which proves GitHub access in minute one.

1. **A template** `skills/review/references/delegated-review.md`: the child's
   prompt with placeholders for repo, PR and review command. It orders: post a
   start comment carrying the marker `fw-review-start`, via the GitHub MCP tools
   (never `gh`); review; post findings as one review with inline comments; post
   a "no findings" comment when there are none; if GitHub tools are missing,
   say so in the final message and list the findings there.
2. **The guard asks when the template was skipped.** `delegation-guard.sh`
   gains a REVIEW family: a delegated prompt that asks for a review
   (`/code-review`, `/flywheel:review`, or "review" with a PR anchor) and lacks
   `fw-review-start` returns `ask`, naming the template. Ask-only, fail-open,
   like every other family.
3. **`/flywheel:review` cites the template** from the step that delegates.

## Success metric

`bash scripts/test-delegation-guard.sh` green with new arms: a review prompt
without the marker asks with REVIEW; with it, silent; a non-review prompt never
raises REVIEW. Invocation budget, docs-consistency and the full sweep green.
