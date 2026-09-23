# Review of PR #91 and #92 (v0.63.0 → v0.71.0) — and a retro on the review

**Date:** 2026-09-23 · **Scope:** analysis only, nothing changed. Covers the two
latest merges on `main`: **#91** (`1c72332`, P48–P53, v0.64–v0.69) and **#92**
(`e6b6efd`, task closure + gate coherence, v0.70–v0.71). 78 files, ~4,500 added
lines. #88–#90 (P40b re-decision, P47) are out of scope.

**Provenance** of every finding is marked: **own** = reproduced or read by the
session that wrote this; **agent** = reproduced by a delegated reviewer and only
spot-read here, not re-run.

## 1. What shipped

**#91 — make the loop's own record measurable**
- P48 (v0.64): a post-cutoff transition line must carry `phase`;
  `run-cost.sh --all` rolls the corpus up by phase and route.
- P49 (v0.65): `check-route-honored.sh` — the route a plan assigned vs the one
  its run recorded. Fatal: a planned task with no transition line, or a run above
  its tier without `route_escalated_from`.
- P50 (v0.66): `read-meter.sh` gains `max_read` and `by_tool`.
- P51 (v0.67): `xhigh` joins the tier ladder.
- P52 (v0.68): `check-ci-gate-parity.sh` — every shipped `check-*.sh` is invoked in CI.
- P53 (v0.69): three Codex findings, including an exclusive `--since` cut.

**#92 — executable task closure, and the gates made to agree**
- v0.70: `check-task-closure.sh` runs each plan task's `check:`. Verdicts PASS /
  FAIL / PENDING / UNRUNNABLE never collapse. Execution is bounded by
  `task-closure-allow.txt`, run as argv with no shell. Wired into CI,
  `/flywheel:verify` and the vendored installer.
- v0.71 (gate-coherence): one cutoff registry (`cutoffs.txt` + `fw_cutoffs.py`),
  one task-id reader (`fw_tasks.py`), test pairing sees `.py`.
- CLAUDE.md: task-list discipline and the progress toolbar.
- list-intake (P56): spec + plan only, **not built**.

## 2. Health

| Check | Result | Provenance |
|---|---|---|
| `scripts/test-*.sh` (30) | 29/30 first run; `test-read-meter.sh` failed, then 6/6 on re-run | own |
| docs-consistency, release-bump, version-citations, invocation-budget, test-pairing, `claude plugin validate --strict` | green | agent |
| 13 `check-*` gates on the real tree | green (ci-gate-parity 13/13) | agent |
| CI on `main` @ `e6b6efd` | green | own |
| CI on `main` @ `1c72332` | **red** — `1 of 27 failed: scripts/test-read-meter.sh` | own (job log) |
| `run-cost --all` totals recomputed by hand | match (bytes_in 2,009,450 · bytes_out 581,534 · 101 lines) | agent |
| Model names in shipped files | none (commit trailers only) | agent |

## 3. Findings, ranked

### Security
1. **The closure allowlist authorizes a name shape, not a script**
   (`scripts/task-closure-allow.txt`, `scripts/check-task-closure.sh:100-138`).
   `scripts/(test|check)-*.sh` admits a script the same PR adds; a plan citing a
   new `scripts/check-evil.sh` reported PASS and ran it. In CI this adds no
   exposure, since CI already runs every PR-authored `test-*.sh`. It does add
   exposure on local `/flywheel:verify` of someone else's branch, which
   contradicts the "security boundary" claim. The Codex-P1 fix (metacharacters
   refused, argv without a shell) holds for `&&`, `;`, `|`, `$()`, redirects and
   newlines. *Pattern: own · repro: agent.*
2. **Pre-cutoff corpus exemption trusts the author date** (`git log %aI`,
   `check-task-closure.sh:140-189`). A new broken plan committed with
   `GIT_AUTHOR_DATE=2000-01-01` is exempt forever, exit 0. *Agent.*

### Correctness
3. **`check-route-honored.sh` is nondeterministic on ties** (`:159`). `max()`
   over a `set`: when merged tasks (`T1-T2`) tie on tier, the hash seed picks
   the winner. `PYTHONHASHSEED` 1–5 → exit 0, 6/7/9/10 → exit 1 on an identical
   tree. Fix: a deterministic secondary key (task id). *Code read: own · repro: agent.*
4. **Every cutoff is compared as a string, not an instant**
   (`check-route-honored.sh:156`, `check-telemetry.sh:133`, the date compare in
   `check-task-closure.sh`). `"…20:00:00.5Z" >= "…20:00:00Z"` is `False`, so a
   post-cutoff violation with fractional seconds or a non-`Z` offset downgrades
   from fatal to notice. The corpus already mixes `+00:00` and `Z`. *Own.*
5. **`test-read-meter.sh` is flaky and turned `main` red after #91.** The
   fixture assumes two feeds land in the same second
   (`scripts/test-read-meter.sh:308`). #92 did not fix it. *Own.*
6. **ci-gate-parity counts a gate under `if: false` as invoked**: a line regex
   with only comment stripping. *Agent.*
7. **Task closure is unusable in consumer repos.** The allowlist admits only
   `scripts/(test|check)-*.sh`, `claude plugin validate`, `true|false`, and is
   not extensible. A repo whose checks are `npm test` or `pytest` gets
   UNRUNNABLE and exit 1 on every new plan, and `/flywheel:verify` skips the step
   silently when the script is absent. *Allowlist: own · consumer behavior: agent.*

### Process — the loop not applied to itself
8. **Zero `verify` transitions across all 9 cycles.** `review` appears in one
   cycle, `compound` in one (p50), no line carries `verdict`, and no HTML report
   exists (the last one is from July). This is exactly the defect P48 measured.
   *Own (phase counts per run file).*
9. **Missing close records and self-contradicting docs.** p48 has no
   `.plan.md`. deterministic-task-closure, gate-coherence and list-intake have no
   Status line. P54's heading says 🔵 while its row says 🟡. P56 is 🟢
   ("approved to build") with no recorded owner approval. *Agent.*
10. **The new CLAUDE.md conventions are prose only.** No skill, hook or gate
    enforces them, and they got no spec although CLAUDE.md requires one for
    prose changes. The piece that would make them workable (list-intake) is
    unbuilt: `skills/plan` hard-stops without a spec. *Agent.*
11. **`SKIP_*` has three conventions**: reason required (`SKIP_RELEASE_BUMP`),
    any non-empty value (route, closure, parity), `=1` only (telemetry,
    test-pairing). gate-coherence did not catch it. *Own.*
12. **`Release` tagged v0.64–v0.69 while `Validate plugins` was red.** The two
    workflows are independent. *Own.*

## 4. Growth and debt

| Metric | v0.63 | v0.71 | Provenance |
|---|---|---|---|
| `check-*.sh` gates | 10 | 13 | own |
| Lines in `scripts/` | 9,082 | 11,229 (+24%) | own |
| Steps in `validate-plugins.yml` | 12 | 16 | agent |
| Local gate time | ~4 s | ~96 s (92 s task-closure) | agent, measured under load |
| `skills/work` body budget | — | 5,659 of 5,700 B (41 B left) | own |

- Task closure re-runs tests the suite step already runs, roughly doubling the job.
- Two new LEARNINGS entries (lines ~938 and ~993) near-duplicate older ones (~224/89, ~386).

## 5. Recommendations

1. De-flake read-meter: pin the fixture timestamps instead of using the wall clock.
2. Make route-honored's tie-break deterministic.
3. Compare cutoffs as instants via one parser in `fw_cutoffs.py`, with a boundary arm.
4. Turn the allowlist into trusted identities (paths present on the base) and let a consumer repo extend it.
5. Derive the corpus exemption from something other than author date.
6. Make `Release` depend on a green `Validate plugins`.
7. Run a real `verify` (with its transition line) on the next cycle before adding more gates.

---

## Retro: how this review was done

**Method.** The session read the diffstat of the latest merges to pick a scope,
ran the full test suite in the background, and fanned out three reviewers in
parallel: #92 correctness/security, #91 telemetry gates, docs/process
coherence. It then pulled `main`'s CI history and #92's review threads,
spot-checked the reviewers' headline claims, and wrote the synthesis.
About 6 minutes of wall time for the fan-out and about 290k subagent tokens.

### What worked
- **Going to primary sources beyond the diff.** Reading CI runs on `main`
  surfaced the two findings a diff can't show: `main` red after #91, and
  `Release` tagging anyway. They became findings 5 and 12.
- **Independent parallel slices.** Three reviewers with non-overlapping scopes
  returned no duplicated work and no conflicting claims.
- **Calibrating a delegated severity.** The security reviewer rated finding 1
  CRITICAL. Checking what CI already executes showed it adds no exposure in CI,
  only on local verify. The severity was restated with that nuance rather than
  relayed.
- **Spot checks on the claims that carried the ranking**: the `set`/`max`
  line, the string comparison, the allowlist regex, the `SKIP_*` lines, and the
  per-cycle phase counts.

### What didn't
- **Timing-sensitive tests ran under contention.** The suite ran concurrently
  with three reviewers, and the read-meter failure is a same-second race. Load
  plausibly caused the local red. The CI log confirms the flake independently,
  but the local run alone would not have been evidence. The auditor's 92 s / 96 s
  timings were taken under the same load and are unreliable as absolutes.
- **"Reproduced" was said about repros this session never ran.** The first
  chat version wrote "Reproducido" for the `PYTHONHASHSEED`, `if: false`,
  author-date and `check-evil.sh` findings. Those were the reviewers' repros.
  This document fixes it with the provenance column; the chat version did not.
- **Scope was chosen, not stated.** #91 + #92 was a reasonable read of "the
  latest changes", but the exclusion of #88–#90 was never said until now.
- **Uneven coverage of review history.** #92's review threads were read; #91's
  were not.
- **Nothing was persisted until asked.** The analysis lived only in chat. It
  also had no materialized item list, so there was no check that every reviewer
  finding made it into the synthesis. One did get dropped along the way (the
  `phase` free-text fragmentation into 13 buckets, reviewer #91 finding 4). It is
  noted here as a low-severity design gap rather than silently lost.
- **Some progress messages were narration** ("still waiting for…") that the
  user did not need.

### Next time
1. Run timing-sensitive suites alone, or re-run any failure in isolation before calling it evidence.
2. Carry provenance (own / agent) from the first draft, not after being asked.
3. State the scope and its exclusions in the first line of the report.
4. Read review threads on every PR in scope, not just the latest.
5. Write the findings list to a file as reviewers report, and reconcile it before synthesizing.
