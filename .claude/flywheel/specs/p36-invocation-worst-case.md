# Spec: P36 — invocation budget measures the worst case, not the body

**Slug:** `p36-invocation-worst-case` · **Created:** 2026-09-13 · **Backlog:** P36
**Status:** implemented — gate green against the real repo (worst body `work`
5259/5400, worst total `work` 11245/11400), 21/21 test scenarios, test seen red
against the P35 gate before the change
**Prime:** `.claude/flywheel/specs/p35-invocation-context-budget.md` (the gate
this retargets); the "A `SKILL.md` body is capped (P35)" bullet in `CLAUDE.md`.

## R — Requirements

P35 (v0.45.0) capped the bytes of each `skills/*/SKILL.md` and moved detail into
`skills/<name>/references/*.md`. The bodies shrank; **every capped skill got more
expensive to invoke**, because the invocation reads the references too:

| skill | body before P35 | body now | refs | body+refs |
| --- | --- | --- | --- | --- |
| work | 8385 | 5259 | 5986 | 11245 |
| process | 8280 | 4458 | 5873 | 10331 |
| help | 8395 | 4342 | 4537 | 8879 |
| run | 5703 | 4498 | 2406 | 6904 |
| update | 5363 | 4341 | 1708 | 6049 |
| compound | 4716 | 4231 | 1059 | 5290 |

`skills/work/SKILL.md` cites its one reference from three steps (lines 10, 35,
56) any run reaches, so a normal `work` invocation costs ~11.2 KB where it cost
8.4 KB — while the gate printed `OK — worst case work at 5259/5300`. That
ceiling was itself raised from the spec's signed 4500 purely to fit `work`,
handing the other sixteen skills 800–4000 B of unreported slack.

1. Enforce **two numbers per skill**: `body` (SKILL.md bytes) and `worst`
   (body + every distinct reference reachable from it, transitively). `worst`
   must be ungameable — moving a hot-path rule out of the body must not improve
   the measured number.
2. Ceilings become **per-skill with named exceptions**, replacing one global
   number that is really the worst offender's number.
3. The retired single-integer budget file fails loudly; coercing it would leave
   the other ceiling silently undefined.
4. Keep everything the P35 gate does: hollow-body check, dangling citations,
   sorted breakdown on stdout, verdict on stderr after a flush, exit 0/1/2,
   `SKIP_INVOCATION_BUDGET=1` — and detect a dangling citation **inside a
   reference** too, since a rule lost one level down is lost as silently.

## E — Entities

| Entity | What | Where |
| --- | --- | --- |
| `body` | bytes of `skills/<n>/SKILL.md`, always paid | measured per skill |
| `worst` | `body` + every distinct reference reachable from it | measured per skill |
| ceilings | keyed defaults + per-skill exceptions | `scripts/invocation-budget.txt` |

## A — Approach

`worst` walks the citation graph from the body, reusing `CITE_RE` and the
existing repo-relative/bare resolution on reference files too (a bare
`references/x.md` inside `skills/work/references/y.md` resolves against
`skills/work/`). Each distinct resolved path is charged **once** however often
it is cited; the `seen` set doubles as the cycle guard.

`worst` is an **upper bound** and deliberately charges every cited reference,
including one a given run would not open. The alternative is inferring
conditionality from prose ("consult this only when X"), which is not
mechanically knowable — and a gate that guesses is a gate that can be argued
with. The over-charge is a real cost in the case that matters: the run that
follows every citation.

`scripts/invocation-budget.txt` becomes keyed — `body <n>` / `worst <n>`
defaults, `<skill> body=<n> worst=<n>` exceptions, `#` and blank lines ignored.
`FW_INVOCATION_BUDGET` overrides the default body ceiling (tests, probes),
`FW_INVOCATION_WORST` the worst one; exceptions still apply on top.

Ceilings, measured 2026-09-13:

- **body 4800** — ~300 B above the tightest occupant of the default (`run`
  4498, `loop` 4474); a round number, not "worst offender + 41".
- **worst 9000** — a round 121 B above `help` (8879), tighter on purpose: the
  two skills that need room hold named exceptions, so this default houses `help`.
- **`work body=5400 worst=11400`**, **`process worst=10500`** — ~150 B above the
  measured value, and **debts, not new normals**: the follow-up is to pay them
  down, not to raise them again. `work`'s anti-rationalization table must stay
  in the body (commit `e4d552e`) and `work-detail.md` is cited from three
  hot-path steps; `process` cites `contract-template.md` and
  `data-strategy-and-extensions.md` from steps a contract-writing run reaches.

Rejected: a ceiling on `worst` alone (the body is paid even when no citation is
followed); weighting a reference by how many steps cite it (it would reward a
rule being cited once, from the step that matters); coercing the legacy file.

## S — Structure

- `scripts/check-invocation-budget.sh` — two ceilings, transitive walk, a
  breakdown row per skill (`name body worst [OVER body|worst]`)
- `scripts/test-check-invocation-budget.sh` — 21 scenarios, `mktemp -d` fixtures
- `scripts/invocation-budget.txt` — keyed format, replacing the bare `5300`
- The version bump and `upgrades/v<next>.md` are the coordinator's, not this spec's.

## O — Operations

1. Measure the real tree; confirm the table above.
2. Extend the test first — worst over while body fits, per-skill exception,
   transitive citation, a file cited twice counted once, a cycle, a dangling
   citation inside a reference, the legacy bare-number file — and see it red.
3. Rewrite the gate and the budget file; run the test, see it green.
4. Run the gate against the real repo: exit 0 across 17 skills.

## N — Norms

The budget file stays data, not a script: retuning policy is a one-line
reviewable diff the pairing gate ignores. Bash + stdlib `python3` only. Output
stays a table plus one verdict line — this runs in every CI job.

## S — Safeguards

- **Unusable input is loud** (exit 2): missing ceiling, unparseable line, legacy
  bare number, non-numeric override, no `skills/*/SKILL.md`.
- **Cycle-guarded** walk; the test bounds each run with `timeout`, so a
  regression fails CI instead of hanging it.
- Fixtures live in `mktemp -d` under a teardown trap — the real `skills/` is
  never touched — and the breakdown is still asserted to precede the verdict
  with `PYTHONUNBUFFERED` unset (the P35 regression).

## Success metric

One command, exit 0 = PASS:

```bash
bash scripts/test-check-invocation-budget.sh \
  && bash scripts/check-invocation-budget.sh \
  && ! FW_INVOCATION_BUDGET=100 bash scripts/check-invocation-budget.sh \
  && ! FW_INVOCATION_WORST=100 bash scripts/check-invocation-budget.sh \
  && grep -qE '^body 4800$'  scripts/invocation-budget.txt \
  && grep -qE '^worst 9000$' scripts/invocation-budget.txt
```
