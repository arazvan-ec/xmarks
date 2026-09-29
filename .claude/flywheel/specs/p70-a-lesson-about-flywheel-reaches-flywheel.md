# P70 — a lesson about flywheel reaches flywheel

**Status:** signed 2026-09-28 (owner: "arranca todo el trabajo propuesto de forma autónoma", after the B/A/C recommendation).

## R — Requirements

A learning about flywheel itself, captured in a repo that only *uses*
flywheel, must be able to reach this repo's backlog, and the backlog must read
it. Today it stays in that repo's `LEARNINGS.md`, where the plugin's author
never looks.

Measured 2026-09-28 over the owner's 8 candidate repos: 3 carry a ledger, 61
entries, **4 clearly about flywheel** (dead-impact: "flywheel se instala SOLO
vendored…", "un plan ya repartido se enriquece por columna…", "en DATA.md un
write aterriza cuando está commiteado…"; car: the run-report format) and 10
borderline. None reached `docs/research/improvement-proposals.md`.

One channel covers the three sources the owner named: a session in another repo
(1), the owner away from any session (3), and a marketplace user (5).

- In: an issue form + its label; a script that turns one ledger entry into a
  prefilled issue URL; `compound` offering it; `flow-audit` reading the issues.
- Out: auto-submitting anything; a weekly Routine (flow-audit already is the
  ingestion step; scheduling it is the owner's call); packaged-skill runs (case 2,
  deferred until one exists).

## E — Entities

| Entity | Where | Role |
| --- | --- | --- |
| ledger entry | `.claude/flywheel/LEARNINGS.md` | source: `## <type>: <title>` + `fw:` line + prose |
| feedback issue | `arazvan-ec/xmarks`, label `flywheel-feedback` | the channel |
| issue form | `.github/ISSUE_TEMPLATE/flywheel-feedback.yml` | fields `type`, `what`, `evidence`, `version`, `files` |
| audit run | `.claude/flywheel/processes/flow-audit.md` | reads open issues, gives each a disposition |

## A — Approach

`scripts/upstream-issue.sh` renders an entry as a GitHub issue-form URL
(`issues/new?template=…&title=…&<field>=…`). The human reviews it in the browser
and presses submit — the URL is the consent step, so nothing leaves the repo
unseen. When the session holds GitHub write access to the upstream repo,
`compound` may create it through the MCP tools, but only after showing the body
and getting a yes.

Rejected: `compound` opening the issue itself by default. Most sessions in
other repos cannot reach `xmarks`, and a private repo's prose must not be
published to a public one without a human reading it.

## S — Structure

- `scripts/upstream-issue.sh` + `scripts/test-upstream-issue.sh` (new pair)
- `scripts/install-vendored.sh` — vendor it; `scripts/test-install-vendored.sh`
- `skills/compound/SKILL.md` — one line + allowed-tools; detail in
  `skills/compound/references/upstream.md`
- `.github/ISSUE_TEMPLATE/flywheel-feedback.yml`, `.github/workflows/labels.yml`
- `.claude/flywheel/processes/flow-audit.md` — Recall reads the issues
- `README.md` — one short section

## O — Operations

1. Test-first `upstream-issue.sh`.
2. Vendor it.
3. Issue form + label workflow.
4. `compound` line + reference.
5. `flow-audit` input + disposition rule.
6. README; release with P69.

## N — Norms

Bash wrapper + python heredoc like the other scripts; stdlib only. Field ids in
the form and the script are the same literals.

## S — Safeguards

- **Privacy**: `files` keeps only flywheel-surface paths (`skills/`, `scripts/`,
  `hooks/`, `agents/`, `.claude/flywheel/bin/`, `.claude-plugin/`, `upgrades/`);
  the repo's own paths are dropped. Prose goes through the human's review.
- **No self-loop**: in flywheel's own repo the script refuses (exit 3) — the
  entry is already upstream.
- **URL size**: prose truncated so the URL stays under 7,500 characters.
- **Unverified stays visible**: no `evidence=` → the field says so.
- **Unreachable GitHub in flow-audit**: recorded as `feedback: not read (<why>)`,
  never silently empty.
- **cannot see:** a lesson the session never compounds, and one compound files
  as domain when it is about flywheel.

## Success metric

`bash scripts/test-upstream-issue.sh` exits 0, **and**
`bash scripts/test-install-vendored.sh` exits 0 with the script vendored, **and**
`bash scripts/sweep.sh` ends `N/N passed`.
