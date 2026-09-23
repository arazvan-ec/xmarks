# Spec: P55 — a route deviation says why

**Slug:** `p55-a-deviation-says-why` · **Created:** 2026-09-23 · **Backlog:** P55
**Status:** in progress

**Prime:** P49 (`check-route-honored.sh`), P53 (delegation participates), and the
owner's question on 2026-09-23: *"¿no es mejor que se haga con el modelo
planeado?"* — asked after a session recorded that T1, routed `sonnet/medium`,
ran in the main session instead.

## R — Requirements

`route_escalated_from` records **that** a task left its route; nothing records
**why**. In the tree today: **19** lines carry `route_escalated_from`, **0** carry
a reason, and **18 of the 19** are the same move, `sonnet/medium → opus/high`.
The ladder is being declined by habit, and the record cannot say whether each
decline was a task that needed more, a task too small to be worth a subagent,
or nobody trying.

1. **A deviation carries `route_reason`.** From a new cutoff on, a transition
   that carries `route_escalated_from`, or that drops a planned `+delegate`, and
   has no non-empty `route_reason` is a fatal finding, named.
2. **The reasons are readable in one place.** The gate prints every post-cutoff
   deviation as `slug task planned → ran: reason`, so studying them is one
   command, not a grep across JSONL.
3. **The corpus is not backfilled** (P18): the 19 existing escalations are
   before the cutoff and stay a count, never a finding.

## Success metric

`bash scripts/test-check-route-honored.sh` green with new arms: escalation
without reason exits 1 and is named; with reason exits 0 and the reason is
printed; pre-cutoff escalation without reason stays green. Real tree green;
full sweep and `test-docs-consistency.sh` green.
