# Spec: P51 — the effort ladder has the rung the CLI has

**Slug:** `p51-the-ladder-has-the-rung` · **Created:** 2026-09-20 · **Backlog:** P51
**Status:** in progress.

**Prime:** P27 (route tiers), P49 (`check-route-honored.sh`, which reports an
unrankable route rather than reading it as honored) and the question P49 left
open for the owner.

## R — Requirements

P49 shipped with a question it refused to answer itself: **26 telemetry lines
carry `opus/xhigh`, an effort `plan-route.sh`'s ladder does not define**
(`low|medium|high|max`). A route nothing can rank is compared against nothing, so
those 26 transitions sit outside every comparison the gate makes.

The owner has answered, and the CLI reference confirms it: the effort levels are
**`low`, `medium`, `high`, `xhigh`, `max`** — `xhigh` sits **between `high` and
`max`** — plus `ultracode`, which is `xhigh` with orchestration on rather than a
sixth level. The repo's own `docs/research/claude-code-loops.md` already said so
in passing (*"`/effort ultracode` (xhigh reasoning + auto orchestration)"*), which
is where the ladder should have picked it up.

One assertion: **`xhigh` is a legal, rankable effort, ordered above `high` and
below `max`.**

Out of scope, deliberately: **adding a tier 4 to `route-tiers.txt`.** The ladder
and the tier table answer different questions — see **Entities**. Making
`opus/xhigh` a named tier would move the top tier, and the top tier is where
every plan's riskiest step is *required* to run. That is a policy change for
every future plan, and nobody asked for one.

Also out of scope: `ultracode` as an effort value. It is a mode, not a rung, and
no line in the corpus carries it.

## E — Entities

- **effort ladder** (`EFFORT_LADDER` in `plan-route.sh`) — the **vocabulary and
  ordering**: which efforts are legal and which of two is higher. Consumed by
  `check-route-honored.sh` through `--json` to rank a recorded route against a
  planned one.
- **tier table** (`route-tiers.txt`) — **policy**: which `(model, effort)` pairs
  are named tiers, and which is the top one the riskiest step must reach.
  Changing this changes what plans are allowed to say; changing the ladder only
  changes what can be ranked.

## A — Approach

One tuple, one element. The ladder is already the single authority both scripts
read — P49's `--json` made sure of that — so the rung is added in exactly one
place and `check-route-honored.sh` inherits it without an edit.

The consequence is checked, not assumed: with `xhigh` rankable, p13's three
`opus/xhigh` transitions stop reporting as *unrankable* and start reporting as
what they are — a run **above** the `opus/high` the plan bought, with no
`route_escalated_from`. They predate the cutoff, so they stay counted notices and
the tree stays green. That transition from one notice to another is the visible
proof the rung took effect.

## S — Structure

- `scripts/plan-route.sh` + `scripts/test-plan-route.sh`
- `.claude-plugin/plugin.json` → **0.67.0** · `upgrades/v0.67.0.md`
- `docs/research/improvement-proposals.md` — P51, and P49's open question closed.

## O — Operations

See the plan.

## N — Norms

Test-first. Terse code. Atomic commits, pushed per task. Every plan task writes
its own transition line — P49's gate is watching.

## S — Safeguards

- **The rung must not redden the tree.** p13's three lines move from one notice
  to a different notice, never to a failure, because they predate the cutoff.
  Checked on the real tree, not assumed.
- **`max` keeps its place.** `xhigh` is inserted, not appended: appending it
  would rank `max` *below* `xhigh` and silently invert every comparison
  involving the top of the ladder.
- **The tier table is untouched.** The riskiest-step rule still points at tier 3.
- **A plan may now route `opus/xhigh`,** which the linter used to reject. That is
  the point — but it means the riskiest-step check must still pass for a plan
  that uses it, since `xhigh` outranks `high`.

## Success metric

```
export TMPDIR="$(mktemp -d)"
for t in scripts/test-*.sh; do bash "$t" || echo "RED $t"; done
for g in scripts/check-*.sh; do bash "$g" || echo "RED $g"; done
```

Decisive clause, on the real corpus: `check-route-honored.sh` stops reporting
p13's three transitions as *unrankable* and reports them as an unrecorded
upgrade over the plan's `opus/high`, **as pre-cutoff notices** — the tree stays
green, and 26 lines that no comparison could reach are now inside one.
