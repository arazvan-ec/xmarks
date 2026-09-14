# Plan: P41 — flywheel can honor its own `+delegate`

**Spec:** `.claude/flywheel/specs/p41-honor-delegation-on-flywheel.md` (signed 2026-09-14)

## Routing table

| Tier | Route | Tasks |
| --- | --- | --- |
| T3 judgment | `opus/high` | T3 |
| T2 default | `sonnet/medium` | T1, T2 |
| T1 mechanical | `haiku/low` | T4, T5, T6 |

The riskiest step is **T3**: `install-vendored.sh` is the install path every
consuming repo depends on, and a flag that narrows the wrong block half-wires
someone else's repo silently — the exact failure v0.44.0 shipped and P38 was
built to catch.

**No `+delegate` anywhere in this plan, by construction.** This plan builds the
mechanism that makes delegation honorable; it cannot use it. The bootstrap runs
in this context and the routes say so rather than promising a tier the run
cannot buy.

### T1 — Red: the parity cases
- route: `sonnet/medium`
- changes: `scripts/test-check-agent-parity.sh` — parity holds on a clean tree;
  a drifted copy fails; a source agent with no registered copy fails; an orphan
  copy with no source fails; the skip escape hatch is logged, never silent.
- check: `bash scripts/test-check-agent-parity.sh` fails naming a parity case,
  not a missing file.
- test-first: yes

### T2 — Green: check-agent-parity.sh
- route: `sonnet/medium`
- changes: `scripts/check-agent-parity.sh` — compare `agents/*.md` against
  `.claude/agents/*.md` through the installer's rewrite, both directions.
- check: `bash scripts/test-check-agent-parity.sh` prints ALL PASS.
- test-first: yes

### T3 — `--agents-only`, and the self-target guard narrowed to it
- route: `opus/high`
- risk: highest
- changes: `scripts/install-vendored.sh` — new flag; self-target refused for
  every mode except `--agents-only`; the mode writes under `.claude/agents/`
  only. `scripts/test-install-vendored.sh` — cases for the new mode, the still
  refused full self-install, and the untouched behavior of a normal install.
- check: `bash scripts/test-install-vendored.sh` green with the existing cases
  unedited; `bash scripts/install-vendored.sh --agents-only .` writes only
  `.claude/agents/`; `bash scripts/install-vendored.sh .` still exits non-zero.
- test-first: yes

### T4 — Register the six agents
- route: `haiku/low`
- changes: `.claude/agents/{evaluator,executor,reviewer-correctness,reviewer-performance,reviewer-security,verifier}.md`
  committed, produced by the new mode.
- check: `bash scripts/check-agent-parity.sh` green; `git status` clean after a
  re-run of the self-install.
- test-first: no

### T5 — CI, docs, release
- route: `haiku/low`
- changes: the parity gate wired into `.github/workflows/`; README mention of
  `--agents-only`; `.claude-plugin/plugin.json` bump; `upgrades/v<version>.md`.
- check: `bash scripts/test-docs-consistency.sh` and
  `bash scripts/check-test-pairing.sh` green; the upgrade file's frontmatter
  version matches the manifest.
- test-first: no

### T6 — Run the spec's success metric
- route: `haiku/low`
- changes: none — run and report.
- check: the metric command exits 0, the refused-full-self-install clause
  included.
- test-first: no

## Safeguards re-checked

| Spec safeguard | Where the plan addresses it |
| --- | --- |
| drift between the two copies | T1/T2 build the gate before T4 creates the copies |
| full install unchanged | T3's check requires the existing cases green, unedited |
| `--agents-only` writes nothing else | asserted in T3's check, not just intended |
| hooks still inactive here | stated in the spec, untouched by every task |
| this session cannot benefit | T6 stops at the machine-checkable clauses; the executor observation is the next session's |
