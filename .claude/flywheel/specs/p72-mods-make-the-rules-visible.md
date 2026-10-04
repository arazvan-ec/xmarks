# P72 — mods make the rules visible

**Status:** signed 2026-10-04 (owner: "hacer un plan para implementar todas las cosas que has propuesto en el orden que recomiendas. Cada avance tiene que tener su learning…").

## R — Requirements

Claude Code 2.1.289 loads **mods** (plugin folders of TS hook modules: panes,
bands, status entries, toasts, `tool.call` deny/rewrite, `prompt.submit` /
`prompt.compose` rewrite, `$.store`, `$.model.classify`, `$.agent.register`).
Flywheel's rules today are either bash hooks or prose in CLAUDE.md, and its
meters (`read-meter.sh`, telemetry) are only seen at gates and close.

Ship 12 mods, dystopian in voice, each bound to a rule or meter flywheel
already has. Order is the owner-approved recommendation; every step re-checks
it (see the understanding gate in the plan).

| # | Mod | Rule / meter it surfaces | Mechanism |
| --- | --- | --- | --- |
| 1 | Big Brother Token | `cost.bytes_in`, `read-meter.sh`, writing-token discipline | Pane + toast; `tool.call` after `next`, `session.usage` |
| 2 | Memory Hole | "a list you were handed is a file" | `prompt.submit` detects a list; `tool.call` denies Edit/Write until a `.plan.md` exists |
| 3 | Ventanilla Única | `sweep.sh` gates | Pane of stamps filled as each gate exits |
| 4 | Social Credit | edit-over-rewrite, test-first, closure with evidence | `$.ui.status` score in `$.store`; `prompt.compose` re-education section |
| 5 | Thought Police | progress toolbar, never echo files | `model.classify` on the final reply; native successor to `toolbar.sh stop` |
| 6 | Newspeak | "ask for the criterion" | `prompt.submit` flags bare-verb items without a success criterion |
| 7 | Ration Book | invocation budget, extended to the session | Pane of coupons; `audio.play` at 80 %; read needs authorization at 100 % |
| 8 | Black Market | `SKIP_*` / `Release-Exception` escape hatches | public ledger of exceptions in `$.store`; debt pane |
| 9 | Citizen File | run telemetry + the above | `/expediente` command opens a Pane over `runs/*.jsonl` |
| 10 | Telescreen | `LEARNINGS.md` | AbovePrompt band with slogans from relevant entries |
| 11 | The Supervisor | `evaluator` agent, continuous | `$.agent.register`; asks every N turns what closed with evidence |
| 12 | General Strike | red-gate rate | denies non-diagnostic tools past a threshold, routes to `/flywheel:debug` |

- In: the 12 mods, a gate for them, the release rule covering their path,
  README listing. (Installer dropped at T0: mods ship through the marketplace.)
- Out: mods with no flywheel rule behind them; any mod enabled without the
  person's hot-reload consent; network calls (`$.http`) from a mod.

## E — Entities

| Entity | Where | Role |
| --- | --- | --- |
| mod | `mods/<name>/`, its own plugin in marketplace.json | plugin folder: manifest, `hooks/hooks.json`, `register.tsx`, `*.test.ts` |
| mod gate | `scripts/check-mods.sh` (T0) | per mod: structure, marketplace listing, `claude plugin validate --strict`, `claude plugin test`, own version ahead of base |
| ledger | `.claude/flywheel/LEARNINGS.md` | one entry per closed step — the input of the next step's gate |

## A — Approach

T0 is a spike that answers what the brainstorm left open (where mods live,
whether `hooks.json` can carry bash hooks and `modules` together, how the
installer vendors them, whether `mods/` becomes a release-bearing path) and
builds the harness. Mods 1–3 come first: highest value per effort, data already
exists, and each proves a different mechanism (observe / deny / render a
process). 4–9 reuse the meter and violation detection those build. 10–12 last:
cosmetic, expensive, and most invasive respectively.

## S — Success metric

Per mod: `bash scripts/check-mods.sh origin/main <name>` green (validate + its tests), the
behaviour shown working in a hot-reloaded session, and one ledger entry tagged
`spec=p72-mods-make-the-rules-visible`. Overall: 13 tasks closed or explicitly
dropped by the owner, 13 ledger entries.

## O — Operations

A change to a mod bumps that mod's own `plugin.json` version (check-mods.sh);
flywheel's version moves only when `scripts/` etc. do. Run `bash scripts/sweep.sh` before every push.

## N — Notes / risks

- Hot reload needs the person's consent per session; tests must not depend on it.
- A mod that denies tools (2, 7, 12) can lock a session: each needs an escape
  the owner controls, logged, never silent.
- Mod 5 overlaps `toolbar.sh`; migrate only when parity is proven, never run both
  blocking.

## S — Safeguards

The understanding gate in the plan: no step starts without a written go /
reorder / drop verdict grounded in the previous step's learning.

## Roadmap — one cycle per step

The 13 steps are not one plan: `check-route-honored.sh` requires a started plan to
record every task before it merges, so a 13-step plan spread over many PRs can
never be green. Each step opens its own cycle when its gate says go —
`p72-tN-<name>.md` + `.plan.md`, one or a few tasks — and this table is updated
when it closes. Order and per-step questions as signed:

| Step | Mod | Route | Check | Status |
| --- | --- | --- | --- | --- |
| T0 | foundation: `mods/<name>/` plugins + `check-mods.sh` | `opus/high` | `bash scripts/test-check-mods.sh` | ✅ v0.84.0 |
| T0b | Resource Committee (model/effort per prompt), owner-inserted 2026-10-04 | `opus/high` | `bash scripts/check-mods.sh origin/main resource-committee` | ✅ v0.85.0 — `p72-t0b-resource-committee` |
| T1 | Big Brother Token | `opus/high` | `bash scripts/check-mods.sh origin/main big-brother-token` | next |
| T2 | Memory Hole | `opus/high` | `… memory-hole` | — |
| T3 | Ventanilla Única | `opus/high` | `… ventanilla-unica` | — |
| T4 | Social Credit | `sonnet/medium` | `… social-credit` | — |
| T5 | Thought Police | `opus/high` | `… thought-police` | — |
| T6 | Newspeak | `sonnet/medium` | `… newspeak` | — |
| T7 | Ration Book | `sonnet/medium` | `… ration-book` | — |
| T8 | Black Market | `sonnet/medium` | `… black-market` | — |
| T9 | Citizen File | `sonnet/medium` | `… citizen-file` | — |
| T10 | Telescreen | `sonnet/medium` | `… telescreen` | — |
| T11 | The Supervisor | `opus/high` | `… supervisor` | — |
| T12 | General Strike | `opus/high` | `… general-strike` | — |

### Every step runs this loop (owner convention, 2026-10-04)

1. **Understand** — re-read the spec's purpose and the ledger entry the previous
   task left (`/flywheel:recall p72`). One line: what does it change?
2. **Analyze** — write the verdict under the task as `- gate: go | reorder | drop
   — <reason>` *before* any code. Reorder freely; a drop is proposed to the
   owner, never done silently.
3. **Build** — test-first; the check below green.
4. **Learn** — append one LEARNINGS.md entry with `spec=p72-mods-make-the-rules-visible`
   answering the task's `learn:` question. No entry, not closed.

### T0 — foundation: where mods live, how they ship, how they are tested
- route: `opus/high`
- risk: highest
- changes: scripts/check-mods.sh, scripts/test-check-mods.sh, .github/workflows/validate-plugins.yml, .claude/CLAUDE.md
- check: `bash scripts/test-check-mods.sh`
- test-first: yes
- learn: can one plugin carry bash hooks and TS modules together, and what does the installer have to do?
- gate: go, reshaped. Probed on `git archive` copies with CLI 2.1.289: (A) `modules` beside `hooks` in flywheel's own hooks.json validates `--strict`; (B) a separate plugin at `mods/<name>/` listed in marketplace.json validates once it carries `author`, and `claude plugin test` runs its `*.test.ts` (TestBody is `($, on)`). Chose **B**: three of the mods deny tools, so each has to be opt-in (`/plugin install <mod>@xmarks`) and carry its own version; A would force every mod on every flywheel install. That changes three things in T0: (1) the installer has no part, since mods reach users through the marketplace and never the vendored path, so `install-vendored.sh` leaves this task; (2) the release rule for `mods/` is the mod's own version, ahead of the base's, not flywheel's; (3) the harness is a gate, `scripts/check-mods.sh` paired with `test-check-mods.sh` (CLAUDE.md pairing rule), wired in CI. Each later task's check becomes `bash scripts/check-mods.sh origin/main <mod>`.

### T1 — Big Brother Token (live read/write meter)
- route: `opus/high`
- changes: mods/big-brother-token/
- check: `bash scripts/check-mods.sh origin/main big-brother-token`
- test-first: yes
- learn: do live bytes match what read-meter.sh records at close? where do they diverge?

### T2 — Memory Hole (a list is a file, enforced)
- route: `opus/high`
- changes: mods/memory-hole/
- check: `bash scripts/check-mods.sh origin/main memory-hole`
- test-first: yes
- learn: how reliably does a prompt look like a list? false positives cost a blocked session

### T3 — Ventanilla Única (sweep as stamps)
- route: `opus/high`
- changes: mods/ventanilla-unica/
- check: `bash scripts/check-mods.sh origin/main ventanilla-unica`
- test-first: yes
- learn: can a mod observe sweep.sh per gate without re-implementing it?

### T4 — Social Credit (score + re-education)
- route: `sonnet/medium`
- changes: mods/social-credit/
- check: `bash scripts/check-mods.sh origin/main social-credit`
- test-first: yes
- learn: does a prompt.compose section change behaviour, measured over a session?

### T5 — Thought Police (final-reply classifier)
- route: `opus/high`
- changes: mods/thought-police/
- check: `bash scripts/check-mods.sh origin/main thought-police`
- test-first: yes
- learn: is it at parity with toolbar.sh stop? if yes, propose retiring the bash hook

### T6 — Newspeak (criterion before work)
- route: `sonnet/medium`
- changes: mods/newspeak/
- check: `bash scripts/check-mods.sh origin/main newspeak`
- test-first: yes
- learn: what share of real owner prompts carry no success criterion?

### T7 — Ration Book (session budget)
- route: `sonnet/medium`
- changes: mods/ration-book/
- check: `bash scripts/check-mods.sh origin/main ration-book`
- test-first: yes
- learn: what budget is right? derive it from T1's data, not a guess

### T8 — Black Market (exceptions ledger)
- route: `sonnet/medium`
- changes: mods/black-market/
- check: `bash scripts/check-mods.sh origin/main black-market`
- test-first: yes
- learn: how much exception debt does the repo actually carry?

### T9 — Citizen File (/expediente pane)
- route: `sonnet/medium`
- changes: mods/citizen-file/
- check: `bash scripts/check-mods.sh origin/main citizen-file`
- test-first: yes
- learn: does a live pane replace the gate-time HTML report, or duplicate it?

### T10 — Telescreen (learnings band)
- route: `sonnet/medium`
- changes: mods/telescreen/
- check: `bash scripts/check-mods.sh origin/main telescreen`
- test-first: yes
- learn: does showing a learning at use-time prevent a repeat, or is it noise?

### T11 — The Supervisor (continuous evaluator)
- route: `opus/high`
- changes: mods/supervisor/
- check: `bash scripts/check-mods.sh origin/main supervisor`
- test-first: yes
- learn: what does a supervising subagent cost per turn against what it catches?

### T12 — General Strike (red-gate circuit breaker)
- route: `opus/high`
- changes: mods/general-strike/
- check: `bash scripts/check-mods.sh origin/main general-strike`
- test-first: yes
- learn: what threshold separates a stuck loop from normal red-green TDD?
