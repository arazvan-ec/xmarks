# Spec: P41 — flywheel can honor its own `+delegate`

**Slug:** `p41-honor-delegation-on-flywheel` · **Created:** 2026-09-14 · **Backlog:** P41
**Status:** shipped as v0.49.0 — metric PASS (parity 6/6, both test suites green,
self-install idempotent with no diff, full self-install still refused,
`claude plugin validate --strict` passed). **Acceptance observation RECORDED**
2026-09-14: the `executor` subagent type resolved and ran T6 of this plan, in the
same session that wrote the files — see the correction under Requirements 3.
**Prime:** P27 (stage routing — the thing that cannot be honored); P32 ("test it,
or stop implying it is tested" — the same dishonesty, one layer down); P38
(`check-hook-parity.sh`) — this reuses its shape and its lesson; the
`install-vendored.sh` header, which documents the web-session cause.

## R — Requirements

flywheel prescribes `route: haiku/low+delegate` and ships `agents/executor.md` to
serve it. In its own repo neither works, for three stacked reasons found by
probing, not by reading:

1. Claude Code on the web **never installs marketplace plugins** declared in
   `.claude/settings.json` (the installer's own header documents this). So a web
   session on this repo has no flywheel skills, no agents and no hooks.
2. `install-vendored.sh` — the mechanism that fixes (1) for every consuming repo
   — **refuses to self-target** (`error: target is the flywheel repo itself`).
   The one door out is closed for flywheel itself.
3. Agent discovery for a **new** `.claude/agents/` directory is not immediate:
   two probes right after creating it both returned `Agent type 'executor' not
   found`. **Corrected 2026-09-14:** the types did appear later in the same
   session, so registration is delayed, not strictly session-start scoped as
   first written. The design does not change — a fresh clone must carry the
   copies to have them at session start, and a delay of unknown length is not
   something a plan's routes can depend on.

Net effect: the plugin's own dev loop can never execute the route it tells every
other repo to plan. P32 named this failure mode for reviewer dispatch; this is
the same one for the executor, and it silently degrades every flywheel-on-
flywheel plan to a tier it did not choose.

In scope:

1. `install-vendored.sh --agents-only` — vendors `agents/*.md` into
   `.claude/agents/` and **nothing else**: no skills, no hooks, no settings
   rewiring. Permitted when target == source; the full install stays refused
   there.
2. The six agent files **committed** at `.claude/agents/`. They must exist at
   clone time: discovery happens at session start, so anything generated *by* a
   session loses the race for that session.
3. `scripts/check-agent-parity.sh` — a CI gate that `agents/*.md` and
   `.claude/agents/*.md` agree, both directions, plus its paired test.
4. Release: bump + `upgrades/v<version>.md`, README mention of the new mode.

Out of scope:

- Vendoring flywheel's **skills** into its own repo. 17 duplicated bodies that
  drift on every edit is precisely why the self-target guard exists; this opens
  one door, it does not remove the wall.
- Making the plugin's **hooks** active in this repo (the delegation guard still
  will not fire here). Named as known-remaining, not fixed.

## E — Entities

| Entity | What | Where |
| --- | --- | --- |
| self-install mode | `--agents-only`, self-target allowed | `scripts/install-vendored.sh` |
| registered agents | six files, byte-identical to source | `.claude/agents/*.md` |
| parity gate | source vs registered, both directions | `scripts/check-agent-parity.sh` (+ paired test) |
| CI wiring | the gate runs on every push | `.github/workflows/` |

## A — Approach

Committed copies plus a parity gate — the P38 shape, applied one layer down.

Measured, not assumed: the installer's `/flywheel:` → `/flywheel-` rewrite is a
**no-op for agents** — all six contain zero `/flywheel:` references, and the
rewritten output is byte-identical to the source today. So parity is a plain
`cmp`, and the gate's real job is catching the day someone adds the first
`/flywheel:` reference to an agent, which would make the two files legitimately
diverge and needs a decision, not a silent copy.

Rejected alternatives:

- **Symlink `.claude/agents` → `../agents`.** Zero duplication, but symlinked
  discovery is documented for *skills* and **undocumented for agents**; it also
  breaks on Windows checkouts. Not a foundation for a release gate.
- **Generate the copies from the SessionStart hook.** Elegant on paper, loses
  the race in fact: the files must exist before the session starts to be
  discovered, so a fresh clone's first session would still be unable to delegate.
- **Allow the full self-install.** Duplicates every skill into
  `.claude/skills/flywheel-*` and drifts on every skill edit. The guard is right;
  it is just too wide.

Trade-off accepted: six files exist twice in the tree. The gate is what makes
that safe, and it is the same bargain P38 already struck for hooks.

## S — Structure

`install-vendored.sh`: a `--agents-only` flag that narrows the install to the
agents block and relaxes the self-target guard for that mode alone.
`check-agent-parity.sh`: new, plus `test-check-agent-parity.sh` (pairing is CI
enforced). `.claude/agents/*.md`: six committed files. No new hook, no new
permission surface, no change to what the full install does.

## O — Operations

1. Red: `scripts/test-check-agent-parity.sh` — parity holds; a drifted copy
   fails; a source file with no registered copy fails; an orphan copy fails.
2. Green: `scripts/check-agent-parity.sh`.
3. `--agents-only` in the installer + the narrowed self-target guard.
4. Commit the six `.claude/agents/*.md`.
5. Wire the gate into CI; README + upgrade note; bump.

## N — Norms

Test-first for both scripts (CLAUDE.md). Terse code, comments only where they
state a constraint. Atomic commits, pushed per task (P28). Every `scripts/`
change is a release.

## S — Safeguards

- **Drift is the whole risk.** Two copies of an agent, one edited — the gate is
  the only thing standing between that and a repo that delegates to a stale
  executor. It fails CI, both directions, orphans included.
- The full install's behavior must not change: `test-install-vendored.sh` stays
  green unedited, and self-target stays refused without `--agents-only`.
- `--agents-only` writes only under `.claude/agents/` — it must not touch
  settings.json, skills, or `bin/`, so it can never half-wire a repo.
- **Known-remaining, stated not hidden:** flywheel's hooks are still inactive in
  its own repo, so `delegation-guard.sh` does not fire on flywheel-on-flywheel
  delegation. This spec does not fix that.
- **The observation is the only proof.** Registration timing is not
  contractual, so "the agents are registered" may never be claimed from the fact
  that the files exist — only from a subagent invocation that actually resolved.

## Success metric

```
bash scripts/check-agent-parity.sh \
  && bash scripts/test-check-agent-parity.sh \
  && bash scripts/check-test-pairing.sh \
  && bash scripts/test-install-vendored.sh \
  && bash scripts/install-vendored.sh --agents-only . >/dev/null \
  && git diff --quiet .claude/agents/ \
  && ! bash scripts/install-vendored.sh . 2>/dev/null
```

Re-running the self-install produces **no diff** (idempotent and in sync), and
the full self-install is still refused.

**Acceptance observation — RECORDED 2026-09-14:** the `executor` subagent type
resolved and executed T6 of this plan (the metric run itself), returning PASS on
all six clauses with a clean tree. The route `haiku/low+delegate` was honored by
the loop for the first time in this repo's history.
