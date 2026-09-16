# Plan: P13 — pillar-2 security-by-design (slice 1, the supply chain)

**Spec:** `.claude/flywheel/specs/p13-pillar2-security.md`
**Status:** proposed. This branch writes the plan; nothing here is executed.

## Routing table

| Tier | Route | Tasks |
| --- | --- | --- |
| T3 judgment | `opus/high` | T1, T2, T3 |
| T2 default | `sonnet/medium` | T4, T5 |
| T1 mechanical | `haiku/low+delegate` | T6 |

The riskiest step is **T3**, the workflow itself: it is the file every consuming
repo's weekly CI executes, a mistake in it breaks their updates silently, and it
cannot be exercised locally — the only feedback is a real Actions run.

**On the mechanical/judgment split.** Only T6 is genuinely mechanical: run a
fixed command list and report. Everything else decides something. T4 looks
mechanical (swap a string in a heredoc) and is not: the heredoc stops being
quoted, so every `$` already inside it changes meaning — a tier-1 executor
following "replace `@main` with the SHA" would ship a template whose
`${{ steps… }}` expressions were eaten by the shell. `a task is tier 1 only if
EVERY part of it is mechanical` (ledger, P40a T6) is the rule that demotes it.

### T1 — Probe: does `github.job_workflow_sha` exist here?
- route: `opus/high`
- changes: none in the repo. A throwaway branch + a scratch reusable workflow
  that echoes the `github` context from a `workflow_call` job, run once.
- check: the field is present and non-empty **for a `workflow_call` job reached
  from a scheduled caller** — the exact trigger shape, not a `push`.
- test-first: n/a (probe)
- why T3: the whole structure rests on the answer. Absent or empty → fall back
  to a baked `FLYWHEEL_SHA`, and T3/T4 are different tasks. This is the P44 T1
  precedent: a platform assumption gets probed, never quoted from docs.
- record the answer in the spec's **E** section whichever way it goes.

### T2 — Red: the gate, failing on the tree as it stands
- route: `opus/high`
- changes: `scripts/check-supply-chain-pin.sh`,
  `scripts/test-check-supply-chain-pin.sh`,
  `scripts/supply-chain-pin-allow.txt`.
- check: `check-supply-chain-pin.sh` exits non-zero on the **unmodified** repo
  and names two lines separately — `install-vendored.sh`'s `uses:` and
  `flywheel-update.yml`'s clone step. The unit test covers both assertions
  independently, plus: an allowlist entry matching nothing fails; an unreadable
  workflow file fails (fail-closed, against the repo's fail-open reflex).
- test-first: yes
- why T3: what counts as "pinned" is the judgment here. A regex that accepts any
  40-hex ref passes a SHA on a fork; one that only reads `uses:` passes the spec's
  revert 2 with the hole open. Getting this wrong produces a gate that is green
  and worthless, which is worse than none.

### T3 — Green: the workflow fetches the commit it was pinned to
- route: `opus/high`
- risk: highest
- changes: `.github/workflows/flywheel-update.yml` — replace the `:27` clone with
  a fetch + `checkout --detach` of T1's SHA, before the `:46` execution step; pin
  `actions/checkout@v4` and `peter-evans/create-pull-request@v7` to SHAs with the
  tag in a trailing comment.
- check: the gate's clone-step assertion goes green; the caller assertion stays
  red (T4 fixes that half) — proving the two halves are independent, which is the
  spec's decisive clause.
- test-first: yes (T2 wrote the assertion)
- verify for real: one `workflow_dispatch` run on a scratch repo before the
  release. A YAML change no one has executed is not verified, and this file only
  ever runs in someone else's CI.

### T4 — Green: the installer writes a pinned caller
- route: `sonnet/medium`
- changes: `scripts/install-vendored.sh` — full-SHA value (the existing
  `SRC_COMMIT` is `rev-parse --short`, invalid as a `uses:` pin), the heredoc at
  `:442-461` unquoted so the SHA interpolates, and every pre-existing `$` inside
  it escaped. `scripts/test-install-vendored.sh` — the template carries a 40-hex
  ref, no `@main`, and the `${{ }}` expressions survive verbatim.
- check: `test-install-vendored.sh` green including the escaping case; the gate
  now green on both halves.
- test-first: yes
- not T1: the quoting change is the whole risk and it is invisible in the diff's
  intent. See the note above the task list.

### T5 — Release
- route: `sonnet/medium`
- changes: `.claude-plugin/plugin.json` version bump; `upgrades/v<next>.md` with
  `requires-action: true` — installed repos carry an `@main` caller until they
  re-vendor, and the note must say so and give the one-line remedy.
- check: `bash scripts/test-docs-consistency.sh`.
- test-first: no
- not delegated: the upgrade note is a judgment about what a consuming repo must
  do, and a delegated release summary is the mistake P40a's T6 paid for.

### T6 — Run the spec's metric, including both reverts
- route: `haiku/low+delegate`
- changes: none — run and report.
- check: the metric command exits 0; then revert 1 (restore `@main`) → red naming
  the `uses:` line; restore; revert 2 (delete the `checkout --detach` step) → red
  naming the clone step; restore. Both reverts recorded verbatim in the report.
- test-first: no
- genuinely mechanical: a fixed command list, two named one-line reverts, and a
  transcript. Nothing is decided.

## Safeguards re-checked

| Spec safeguard | Where the plan addresses it |
| --- | --- |
| gate is fail-closed | T2's own test case, not a comment in the script |
| existing installs keep working | T4's check keeps the current cases green; T5's note carries the remedy |
| allowlist cannot go stale | T2 asserts a non-matching entry fails |
| no new session-start network calls | no task touches `session-start.sh` |
| design branch ships no code | T1–T6 are the *next* cycle; this branch stops at T0 |
| the pin and the clone are one value | T1 establishes it; if it fails, T3/T4 are re-planned before being written |

## Later slices (not planned here)

Slice 2 — M3 contract hashing, M1 framing. Slice 3 — M4 probe-and-refuse, M2,
M6. Both need an answer this plan does not have: `run`'s `SKILL.md` body has
142 B of headroom and `process` 342 B (measured), so their rules go to
`references/` — charged against `worst`, where `run` has 1139 B and `process`
497 B — or the budget file gains an exception with a reason. Deciding that is
the first task of whichever slice goes first, not an afterthought at its release.
