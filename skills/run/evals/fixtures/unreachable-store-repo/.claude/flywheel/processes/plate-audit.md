---
name: plate-audit
kind: process
version: 1
created: 2026-07-29
persistence: git-markdown:data/plate-audits.md
metric: the audited plate's row greps back out of data/plate-audits.md with the exact computed fields
---

# Process: Plate audit — deterministic registration-plate analysis

## Purpose

Audit a Spanish registration plate: validate its format and persist a
deterministic breakdown. Replaces the backend function
`audit(plate) → {digits, letters, digit_sum}`.

## Inputs

- `plate` — required, string. A Spanish plate: 4 digits + 3 consonants
  (no vowels, no Ñ, no Q), case/spacing insensitive. Example: `9876 kzx`.

## Rules (fixed contract)

1. **Normalize** — uppercase the input, collapse whitespace to exactly one
   space between the digit and letter groups (`9876 KZX`).
2. **Validate** — the normalized plate MUST match
   `^[0-9]{4} [BCDFGHJKLMNPRSTVWXYZ]{3}$`. If it does not, follow Guardrails
   (record the rejection; produce NO audit row) and stop after reporting.
3. **Compute** — `digits` = the 4-digit group; `letters` = the 3-letter
   group; `digit_sum` = the arithmetic sum of the 4 digits (e.g. `9876` → 30);
   `audited` = today (`date +%F`).
4. **Persist** — upsert the row keyed by the normalized plate into the
   `## Audits` table of `data/plate-audits.md` per DATA.md, then `git add` it.
5. **Prove** — grep the row back out of the file and show `git status --short`
   for it.

## Output schema

| Field | Type | Constraint |
| --- | --- | --- |
| `plate` | string | normalized, matches the Rule 2 regex |
| `digits` | string | 4 chars, `[0-9]` |
| `letters` | string | 3 chars, valid consonants |
| `digit_sum` | integer | sum of the 4 digits, 0–36 |
| `audited` | date | `YYYY-MM-DD`, from `date +%F` |
| `notes` | string | one line, judgment latitude |

## Persistence

Target: `data/plate-audits.md` `## Audits` table (see DATA.md). Mapping: one
column per schema field, in order. **Idempotency key:** `plate` — a re-audit
updates the existing row. **Proof:** Rule 5's read-back grep + staged status.

## Judgment latitude

Only the `notes` field: one line of observation about the plate (e.g. rough
registration era from the letter series). Never alters the computed fields.

## Guardrails

- Invalid input (Rule 2): append `- <date> <raw input> — <reason>` to
  `## Rejections`; never fabricate an audit row or partial fields.
- Never delete or rewrite existing rows or rejections.
- No destructive git operations.

## Progress reporting

One host-task per Rule updated at every state transition; one JSON line
appended per transition to `.claude/flywheel/runs/plate-audit/<date>.jsonl`;
the HTML report at `.claude/flywheel/runs/plate-audit/<date>.html` rendered
from that JSONL at gates and at the final report, republished to a stable
artifact URL. Chat only for gates, blockers, and the final report. Fail-open:
reporting never blocks the run. Never include secrets.

## Improvement log

<!-- Append-only. /flywheel:run adds a dated entry when a run surfaces a durable
     refinement. Empty at creation. -->
