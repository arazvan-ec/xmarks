# Agent-native processes — flywheel's second pillar

**Status:** shipped v0.15.0 (skills `process` + `run`, `DATA.md` convention).
**Owner intent captured:** 2026-07-10 (arazvan).

This document records *what the repo owner asked flywheel to become*, and the
design that answers it. It is the durable home for the vision so any future
session understands the direction without replaying the conversation. The
one-paragraph north-star also lives in the root [`CLAUDE.md`](../../CLAUDE.md).

## The ask, in the owner's words (paraphrased)

> Make this plugin help the repos where I install it work like this:
> 1. Develop ideas about the repo using flywheel.
> 2. Use Claude sessions to *operate* the repo — e.g. "start an analysis of a
>    car" — with a command/skill that does the task the way a backend would:
>    fixed rules, plus Claude's own capacity to improve the analysis.
> 3. I don't want a static code backend — use Claude as the execution process.
> 4. Those executions must persist data the way the repo already does (e.g. this
>    kind of repo writes to Postgres, so that's how you persist too).
> 5. Every process I ask for — or new idea — becomes a command/skill that creates
>    a reusable prompt to start it, saves it, and improves it with your own
>    thinking. So each request has **fixed rules** plus a **maturation process**
>    you run, getting better with each execution.
> 6. This is how you focus flywheel toward being *agent-native*
>    (https://every.to/go-agent-native), right?

Yes to (6): "agent-native" means the agent is a first-class part of the runtime,
not a feature bolted onto a human-centric app. flywheel already treats Claude as
the **development** runtime (the spec→…→compound loop). This pillar extends the
same stance to the **operational** runtime.

## The two pillars

| | Pillar 1 — build the software | Pillar 2 — operate the software (new) |
| --- | --- | --- |
| Loop | spec → plan → work → verify → review → compound | process → run → (mature) |
| Claude is… | the developer | the backend / runtime |
| Unit | a change to the codebase | a domain operation ("analyze a car") |
| Output | committed code | a persisted record in the repo's datastore |
| Memory | `LEARNINGS.md` (cross-cutting) | each process's own **Improvement log** |
| Rigor | "done" = objective check green | "done" = output conforms + persist verified |

Pillar 2 reuses pillar 1's philosophy — nothing is "done" on reasoning alone; a
run must *observe* its write land, exactly as `/flywheel:work` must see a test go
green.

## Design

### A process is a prompt-contract, not code (points 2, 3, 5)

`/flywheel:process <description>` scaffolds `.claude/flywheel/processes/<slug>.md`:
frontmatter (`name`, `kind: process`, `version`, `created`, `persistence`,
optional `metric`) + sections **Purpose / Inputs / Rules (fixed contract) /
Output schema / Persistence / Judgment latitude / Guardrails / Improvement log**.

The split that makes point 5 work:
- **Fixed rules** — Rules, Output schema, Persistence, Guardrails. Deterministic;
  two runs on the same input yield the same structured result.
- **Maturation** — the append-only Improvement log, plus a `version` bump when a
  run's evidence justifies changing the fixed sections. The contract gets
  sharper over time *from real executions*, not from speculation.
- **Judgment latitude** — the bounded region where Claude's reasoning improves
  the *quality* of the output (the "use your potential" part) without ever
  overriding the fixed rules.

### Claude is the execution (points 2, 3)

`/flywheel:run <slug> [input]` loads the contract and executes it as the runtime:
follow Rules, apply latitude, emit the Output schema. No generated service, no
static handler — the skill *is* the handler. This is the literal agent-native
move: the operation's logic lives in a contract the agent runs, and improves.

### Persistence follows the repo, not flywheel (point 4)

flywheel must not impose a datastore. `.claude/flywheel/DATA.md` declares the
repo's existing strategy once — **Store / Access / Schema / Conventions** — and
every run writes through it. For a Postgres repo that's `INSERT … ON CONFLICT`
via whatever client the repo uses (a Postgres/Supabase MCP server, `psql`, an
ORM script). The run must *prove* the write (affected rows or read-back) and be
idempotent on a declared key. `/flywheel:process` bootstraps `DATA.md` by
detecting the repo's store (ORM configs, `DATABASE_URL`, `supabase/`, migrations,
compose services) before asking.

### Self-improvement is evidence-gated (point 5)

The failure mode of "improve every run" is drift. So maturation is bounded: at
most one refinement per run, only from that run's evidence, and changes to the
fixed rules are versioned and explained in the Improvement log. When a lesson is
*cross-process* (not specific to one contract) it belongs in the shared ledger
via `/flywheel:compound`, not the process file.

## Worked example (the owner's "analyze a car")

```
/flywheel:process "analyze a used car by registration plate: valuation,
                    risk flags, and a buy/avoid recommendation"
# → detects Postgres (DATABASE_URL + prisma/schema.prisma), writes DATA.md,
#   writes processes/analyze-car.md with fixed Rules + an Output schema that
#   maps to a car_analyses table, persistence = postgres:public.car_analyses.

/flywheel:run analyze-car 1234ABC
# → Claude runs the fixed rules (pull the record, compute valuation band, apply
#   risk heuristics, form the recommendation), applies judgment latitude to the
#   write-up, UPSERTs into car_analyses on plate, reads the row back to confirm,
#   reports the row id. Notices "mileage was null and Rules didn't say what to
#   do" → appends one Improvement-log entry pinning that rule for next time.
```

## Non-goals / boundaries

- Not a replacement for real production backends where latency, throughput, or
  hard SLAs dominate — this is for operations where *judgment per item* is the
  value and volume is human-scale.
- Not a new datastore or ORM — flywheel persists through the repo's own strategy.
- Not autonomous by default — `/flywheel:run` executes one operation per
  invocation; schedule/loop it with the existing proactive-loop guidance
  (`docs/proactive-loops.md`) if you want it unattended, with the usual budget
  discipline.

## Files (v0.15.0)

- `skills/process/SKILL.md`, `skills/run/SKILL.md` — the two commands.
- `.claude/flywheel/processes/<slug>.md`, `.claude/flywheel/DATA.md` — state kept
  in the repo flywheel is used on (like specs/ and LEARNINGS.md).
- README + `/flywheel:help` + the SessionStart banner document the pillar; the
  vendoring installer picks up both skills automatically (skills are
  auto-discovered), so web repos get them on re-vendor.
