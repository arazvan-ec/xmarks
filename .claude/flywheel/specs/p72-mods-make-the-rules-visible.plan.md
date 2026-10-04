# P72 plan

| Tier | Route | Tasks |
| --- | --- | --- |
| T2 default | `sonnet/medium` | T4, T6, T7, T8, T9, T10 |
| T3 judgment | `opus/high` | T0, T1, T2, T3, T5, T11, T12 |

Riskiest: T0 — every later task depends on where mods live and how they ship.

## Every task runs this loop (owner convention, 2026-10-04)

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
- changes: mods/, scripts/test-mods.sh, scripts/check-release-bump.sh, scripts/install-vendored.sh, CLAUDE.md
- check: `bash scripts/test-mods.sh`
- test-first: yes
- learn: can one plugin carry bash hooks and TS modules together, and what does the installer have to do?

### T1 — Big Brother Token (live read/write meter)
- route: `opus/high`
- changes: mods/big-brother-token/
- check: `bash scripts/test-mods.sh big-brother-token`
- test-first: yes
- learn: do live bytes match what read-meter.sh records at close? where do they diverge?

### T2 — Memory Hole (a list is a file, enforced)
- route: `opus/high`
- changes: mods/memory-hole/
- check: `bash scripts/test-mods.sh memory-hole`
- test-first: yes
- learn: how reliably does a prompt look like a list? false positives cost a blocked session

### T3 — Ventanilla Única (sweep as stamps)
- route: `opus/high`
- changes: mods/ventanilla-unica/
- check: `bash scripts/test-mods.sh ventanilla-unica`
- test-first: yes
- learn: can a mod observe sweep.sh per gate without re-implementing it?

### T4 — Social Credit (score + re-education)
- route: `sonnet/medium`
- changes: mods/social-credit/
- check: `bash scripts/test-mods.sh social-credit`
- test-first: yes
- learn: does a prompt.compose section change behaviour, measured over a session?

### T5 — Thought Police (final-reply classifier)
- route: `opus/high`
- changes: mods/thought-police/
- check: `bash scripts/test-mods.sh thought-police`
- test-first: yes
- learn: is it at parity with toolbar.sh stop? if yes, propose retiring the bash hook

### T6 — Newspeak (criterion before work)
- route: `sonnet/medium`
- changes: mods/newspeak/
- check: `bash scripts/test-mods.sh newspeak`
- test-first: yes
- learn: what share of real owner prompts carry no success criterion?

### T7 — Ration Book (session budget)
- route: `sonnet/medium`
- changes: mods/ration-book/
- check: `bash scripts/test-mods.sh ration-book`
- test-first: yes
- learn: what budget is right? derive it from T1's data, not a guess

### T8 — Black Market (exceptions ledger)
- route: `sonnet/medium`
- changes: mods/black-market/
- check: `bash scripts/test-mods.sh black-market`
- test-first: yes
- learn: how much exception debt does the repo actually carry?

### T9 — Citizen File (/expediente pane)
- route: `sonnet/medium`
- changes: mods/citizen-file/
- check: `bash scripts/test-mods.sh citizen-file`
- test-first: yes
- learn: does a live pane replace the gate-time HTML report, or duplicate it?

### T10 — Telescreen (learnings band)
- route: `sonnet/medium`
- changes: mods/telescreen/
- check: `bash scripts/test-mods.sh telescreen`
- test-first: yes
- learn: does showing a learning at use-time prevent a repeat, or is it noise?

### T11 — The Supervisor (continuous evaluator)
- route: `opus/high`
- changes: mods/supervisor/
- check: `bash scripts/test-mods.sh supervisor`
- test-first: yes
- learn: what does a supervising subagent cost per turn against what it catches?

### T12 — General Strike (red-gate circuit breaker)
- route: `opus/high`
- changes: mods/general-strike/
- check: `bash scripts/test-mods.sh general-strike`
- test-first: yes
- learn: what threshold separates a stuck loop from normal red-green TDD?
