---
name: flow-audit
kind: process
version: 2
created: 2026-07-13
persistence: git-markdown:docs/research/improvement-proposals.md
metric: all three scripts/test-*.sh exit 0 AND the Decision log gains exactly one new dated `flow-audit` entry for this run
---

# Process: Flow audit — self-improve the flywheel flow

## Purpose

Recurring self-audit of flywheel's entire surface (both pillars: the dev loop
and the agent-native runtime) that converts verified findings into numbered
proposals in the living backlog. Replaces the ad-hoc "someone reads everything
and writes up improvements" chore a maintainer would otherwise do by hand — the
backend function is "audit(scope) → prioritized findings + backlog delta".

## Inputs

- `scope` — optional, default `full`. One of `full | pillar-1 | pillar-2 |
  hooks-scripts | docs`. Bounds what the reviewers read.
- `focus` — optional free text (e.g. "token cost", "onboarding friction") that
  sharpens every reviewer's prompt. Example: `/flywheel:run flow-audit full "token cost"`.

## Rules (fixed contract)

1. **Recall** — read `docs/research/improvement-proposals.md` (Status table +
   Decision log) and root `CLAUDE.md`. Note every still-open question from prior
   entries; the audit must not re-open what a logged decision already settled.
2. **Verify** — run `bash scripts/test-docs-consistency.sh`,
   `bash scripts/test-install-vendored.sh`, `bash scripts/test-read-prime.sh`;
   record each exit code. Any red check is automatically a **Critical** finding.
3. **Review** — dispatch four **parallel, fresh-context** specialist reviewers
   over the scope: `reviewer-correctness`, `reviewer-security`,
   `reviewer-performance` (their contracts in `agents/reviewer-*.md`; for this
   repo "performance" means token/hook cost), plus an **agent-native coherence**
   reviewer scored against `CLAUDE.md`'s north-star and
   `docs/research/agent-native-processes.md`.
4. **Synthesize** — merge the four reports: dedupe by `(file, problem)`, sort
   Critical → High → Medium → Low. Every finding must carry `severity |
   file:line-or-area | problem (1 line) | concrete fix (1 line)`.
5. **Screen against the backlog** — drop findings already covered by an existing
   proposal or an explicit decision-log rejection, unless this run's evidence
   shows the decision's own revisit-trigger has fired.
6. **Owner gate** — present the synthesized findings and the proposed backlog
   delta (packages, severities, disposition) to the owner and get explicit
   sign-off **before** persisting anything. The owner may drop, merge or
   re-scope proposals; only the signed set proceeds.
7. **Persist** per `DATA.md` — append new `## P<n> — <title>` sections, their
   Status + Priority rows, and **one** decision-log entry (date, scope, finding
   counts by severity, proposals opened, verify status). Stage everything with
   `git add`.
8. **Prove the write** — grep the new decision-log entry and each new `P<n>`
   heading back out of the file; report the matches. Unproven = not persisted.
9. **Mature** — append ≤1 evidence-based refinement from this run to the
   Improvement log below.

## Output schema

| Field | Type | Constraint |
| --- | --- | --- |
| `run_date` | date `YYYY-MM-DD` | from `date +%F` |
| `scope` / `focus` | string | as invoked |
| `verify_status` | 3 × `pass\|fail` | one per test script, with exit codes |
| `findings[]` | list | `{severity: Critical\|High\|Medium\|Low, location: file:line-or-area, problem: 1 line, fix: 1 line}` |
| `proposals_opened[]` | list | `{id: P<n>, title, value, effort, risk, version_bump: yes\|no}` — ids continue the existing sequence |
| `decision_log_entry` | string | the exact text persisted |

## Persistence

Target: `docs/research/improvement-proposals.md` (see `DATA.md` for the full
schema). Mapping: `proposals_opened[]` → Status-table rows + Priority rows + one
`## P<n>` section each; `decision_log_entry` → appended to `## Decision log`,
newest at the bottom. **Idempotency key:** `(run_date, flow-audit, scope)` — a
same-day rerun with the same scope updates its own entry rather than appending a
second. **Proof:** Rule 8's read-back grep.

## Judgment latitude

Where reasoning is expected to improve the output, never override the Rules:
severity calls; which findings merit a full proposal vs a one-line quick-fix
note inside the decision-log entry; Value/Effort/Risk scoring; the recommended
sequencing among new proposals; the prose quality of each proposal's Why/What.

## Guardrails

- **Docs-only writes.** A run touches only `docs/research/**` and this contract.
  It must never modify `skills/`, `agents/`, `hooks/`, or `scripts/` — that is a
  release (pillar 1): open a proposal and let `/flywheel:loop` build it.
- Decision log is append-only; never delete, edit, or renumber existing
  proposals (per `DATA.md`).
- A failed verify script does not abort the run — the failure **is** a finding —
  but `verify_status` must say `fail` and the decision-log entry must flag it.
- Do not mark any proposal shipped; only a merged release does that.
- No plugin version bump from a run (docs-only).

## Improvement log

<!-- Append-only. /flywheel:run adds a dated entry when a run surfaces a durable
     refinement. -->

### 2026-07-13 — v2: owner sign-off gate before persistence (run #1)

Run #1 evidence: mid-run the owner asked to consolidate all reviewer reports and
see the synthesis before anything was written — v1's Rules went straight from
screening (Rule 5) to persisting. Added Rule 6 (present the synthesis + proposed
backlog delta, get explicit sign-off; only the signed set persists) and
renumbered the tail (persist 7, prove 8, mature 9). Fixed-rule change →
version 1 → 2.
