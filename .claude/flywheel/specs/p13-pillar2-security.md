# Spec: P13 — pillar-2 security-by-design

**Slug:** `p13-pillar2-security` · **Created:** 2026-09-16 · **Backlog:** P13
**Status:** design approved, unimplemented. This branch writes the spec, the plan
and `docs/research/pillar2-threat-model.md`. **No code.**

**Prime:** `docs/research/pillar2-threat-model.md` (the evidence; every claim
below cites it or the file directly), P26 (`fixture-leak-allow.txt` — the
reasoned-allowlist idiom this reuses), P42 (a duty nothing can observe failing is
not discharged), P44's T1 (probe a platform assumption before designing on it),
and `scripts/gate.sh` — the one trust boundary flywheel already has.

## R — Requirements

The threat model enumerates ten boundaries. **B10 is the only Critical**, and
the owner has scoped this spec to it (2026-09-16): every other mitigation is
approved in shape and deferred to a later slice, recorded below so the decision
is not re-litigated.

B10, in the two lines that carry it:

- `scripts/install-vendored.sh:457` writes
  `uses: arazvan-ec/xmarks/.github/workflows/flywheel-update.yml@main` into every
  repo installed with `--auto-update`.
- `.github/workflows/flywheel-update.yml:27` then
  `git clone --depth 1 https://github.com/arazvan-ec/xmarks` — unpinned,
  unverified — and `:46` executes `bash "$RUNNER_TEMP/xmarks/scripts/install-vendored.sh"`
  under `contents: write` + `pull-requests: write` (`:20-22`), weekly by cron
  (`install-vendored.sh:452`).

Anyone who can push to this repo's `main` executes arbitrary bash in every
consuming repo's CI, unattended, with write access. The installer rewrites those
repos' hooks into `.claude/flywheel/bin/`, so the same compromise also owns their
SessionStart path — B10 grants B1 for free.

**The finding that changes what gets built:** the backlog says "pin the reusable
workflow to a tag/SHA". A pin on the caller's `uses:` **does not close this** —
the pinned workflow still clones `main` at line 27. The clone is the hole. Both
halves, or nothing.

In scope:

1. The caller template in `install-vendored.sh` pins to a **full** commit SHA.
2. `flywheel-update.yml` fetches and checks out **that same commit** rather than
   whatever `main` is at run time, and fails before any vendored bash runs if it
   cannot.
3. The third-party actions in that workflow (`actions/checkout@v4`,
   `peter-evans/create-pull-request@v7`) pin to SHAs — same class, same fix.
4. `scripts/check-supply-chain-pin.sh` + `scripts/test-check-supply-chain-pin.sh`:
   a CI gate asserting **both** halves, so a later edit cannot quietly reopen it.

Out of scope, **approved and deferred** (slices 2–3, their shape decided
2026-09-16 so the follow-up spec does not reopen the question):

- **M3 — the contract executed is the contract approved** (B4, B6).
  `gate.sh`'s hash boundary applied to contracts: sign-off records the approved
  contract's hash, `run` step 1 compares, a mismatch stops as a blocker and asks.
  Owner chose *hash + re-approve on drift* over warn-only. **Residual hole to
  carry into that spec:** `run/SKILL.md:49` matures and commits the contract,
  which changes the file the hash covers — so maturation must re-record the hash,
  and a maturation that re-blesses itself is the exact loop this mitigation is
  meant to break. That design is unsolved here and must not be hand-waved there.
- **M4 — least privilege, enforced by the probe** (B7). Owner chose *probe and
  refuse*: `run`'s existing read-only write-path probe (`run/SKILL.md:22`) also
  establishes that the role cannot DDL/DELETE and refuses to start when it can.
  A role binds where the prose ban at `run/SKILL.md:33` does not. This stops runs
  on every repo that has not provisioned a restricted role — which today is all
  of them — so its slice needs an upgrade note with a `requires-action: true`
  strategy.
- **M1** (untrusted-data framing at `session-start.sh:220`, `:39`,
  `read-prime.sh:83`), **M2** (no resolved credentials in committed flywheel
  state), **M6** (env-var-only Access in DATA.md + redaction in `run`'s step-5
  report).

Not evaluated at all: `skills/update/**`, excluded by instruction. The backlog's
`/flywheel:update` item is neither confirmed nor refuted and must be audited
before it is scheduled.

## E — Entities

- **caller template** — the heredoc at `install-vendored.sh:442-461`. It is
  currently `<<'YAML'` (quoted, no expansion); a SHA must be interpolated, so the
  quoting changes and every `$` already inside it must be re-checked.
- **`SRC_COMMIT`** — `install-vendored.sh` already computes it
  (`rev-parse --short HEAD`). **A short SHA is not a valid `uses:` pin**; this
  needs the full one.
- **`github.job_workflow_sha`** — **T1 ran, and refuted it (2026-09-16).** The
  field does not exist. A `workflow_call` job dumping `toJSON(github)` carries 33
  keys and this is not among them, and there is no `GITHUB_JOB_WORKFLOW_SHA`
  environment variable either. Evidence: run
  [35155026753](https://github.com/arazvan-ec/xmarks/actions/runs/35155026753),
  plus runs [35154882069](https://github.com/arazvan-ec/xmarks/actions/runs/35154882069)
  (`push`) and [35154895860](https://github.com/arazvan-ec/xmarks/actions/runs/35154895860)
  (`workflow_dispatch`), where it interpolated to the empty string —
  `PROBE_len_job_workflow_sha=0`.
- **`github.workflow_sha`** — exists, and is the trap. It is the **caller's**
  commit in the **caller's** repository (probe: `b78888b…`, the caller's own
  head), not the reusable workflow's pin. A fetch keyed on it would resolve a
  consuming repo's SHA against *this* repo's URL and fail, or worse, collide.
  Named here so a later reader does not "fix" the design by reaching for it.
- **`inputs.flywheel_sha`** — what replaces it. `workflow_call` inputs pass
  through intact (probe: `INPUT_len=40`), so the **caller carries the SHA twice**
  — once in `uses: …@<sha>`, once in `with: flywheel_sha: <sha>` — and
  `install-vendored.sh` emits both from one variable, so they cannot drift at the
  point of writing. `check-supply-chain-pin.sh` asserts the two are identical.
- **unauthenticated fetch by SHA** — verified, not assumed:
  `git fetch --depth 1 origin <full-sha>` against this public repo returned
  `FETCH=OK head=f00713c…` in the same probe run. The design needs no token.
- **`scripts/supply-chain-pin-allow.txt`** — reasoned allowlist, the
  `fixture-leak-allow.txt` shape, for any `uses:` that legitimately cannot pin.

## A — Approach

The pin and the clone must resolve to **one** commit, or they are two things to
keep in sync and one of them will rot. The original plan was to read that commit
off `github.job_workflow_sha`. **T1 refuted the field's existence**, so the
approach below is the revision, and it is the third option — neither the original
nor the `FLYWHEEL_SHA` fallback the spec named, which a workflow cannot bake
because it cannot know its own commit before it is committed.

**The caller passes the SHA it pinned.** `install-vendored.sh` writes both the
`uses: …@<sha>` and a `with: flywheel_sha: <sha>` from the same shell variable,
and the reusable workflow fetches that input:

```
git -C "$DIR" fetch --depth 1 origin "$SHA" && git -C "$DIR" checkout --detach "$SHA"
```

One writer, one variable, two lines that the gate asserts are equal — so they
cannot drift in anything this repo produces.

**What this does not buy, stated because it is the weak seam.** At run time the
reusable workflow *cannot* verify that its caller pinned the same commit it
passed; no context field exposes the pin (that is exactly what T1 refuted). A
caller that pins `@A` and passes `B` would run this repo's workflow code from A
against this repo's source from B. That caller lives in a repo whoever wrote it
already controls, so it is not an escalation — but it is not a property the
workflow enforces, and claiming otherwise would be the assertion P18 exists to
stop. It is enforced where it is generated, and only there.

**Fail-closed on an absent input, and what that costs.** In-scope item 2 requires
the workflow to fail before any vendored bash runs if it cannot resolve the
commit. An `@main` caller from an earlier install passes no input, so it now
fails loudly instead of cloning `main`. This **contradicts the safeguard below**
("existing installs keep working"), which was written when
`github.job_workflow_sha` was still believed to exist — under that design an
`@main` caller would have resolved to main's head and kept working. T1 removed
the option; the two clauses cannot both hold. Security wins, and the cost is
recorded rather than smoothed over: those repos' weekly update stops, red, until
a human re-vendors. The upgrade note carries the one-line remedy, and because the
broken mechanism *is* how upgrade notes were delivered, the note cannot reach
them by itself — someone has to look. **This is the one judgment in slice 1 that
a reader may want reversed; it is called out in the PR for exactly that reason.**

**What this does and does not buy, stated plainly.** Pinning converts unattended
RCE into a reviewable diff: a compromised release can no longer reach installed
repos by itself, it must arrive as an update PR that a human merges. It does not
make a merged malicious release safe. Claiming more than that would be the kind
of assertion this repo's P18 rule exists to stop.

Then: gate first (red on this tree, because both defects are live), fix, green.

## S — Structure

- `scripts/check-supply-chain-pin.sh` + `scripts/test-check-supply-chain-pin.sh`
  (CI enforces the pair via `check-test-pairing.sh`).
- `scripts/install-vendored.sh` — the template heredoc, the full-SHA value, and
  a case in `test-install-vendored.sh`.
- `.github/workflows/flywheel-update.yml` — the fetch/checkout step, the two
  action pins.
- `scripts/supply-chain-pin-allow.txt`.
- The implementing cycle is a `scripts/` change, so: `upgrades/v<next>.md` +
  a `plugin.json` bump. **Neither happens on this design branch.**

## O — Operations

T1 probe → T2 gate red → T3 workflow → T4 installer → T5 release → T6 metric.
Routes and the mechanical/judgment split: `p13-pillar2-security.plan.md`.

## N — Norms

Test-first for the script. Terse. Atomic commits, pushed per task. The design
branch touches `.claude/flywheel/specs/` and `docs/research/` only — no version
bump, no upgrade note, and nothing under `scripts/` or `skills/`.

## S — Safeguards

- **Fail-closed, uniquely.** Every other flywheel script is fail-open; this gate
  is CI, not a hook, and an unreadable workflow file must be a failure, not a
  pass. Stating it because the repo's reflex is the opposite.
- **Do not break existing installs.** ~~Repos carrying the `@main` caller keep
  working until their next refresh rewrites it.~~ **Withdrawn by T1** — see
  "Fail-closed on an absent input" in **A**. An `@main` caller now fails closed.
  What `test-install-vendored.sh` still asserts is the narrower, true claim: a
  freshly written caller is pinned and internally consistent.
- **The allowlist is a debt with a reason**, per `fixture-leak-allow.txt`. An
  entry that matches nothing fails the gate, so it cannot go stale silently.
- **No new network calls at session start.** This is CI and install-time only.
- **Budget.** `run` has 142 B of body headroom and `process` 342 B
  (`check-invocation-budget.sh`, measured). This slice touches no `SKILL.md`, so
  it spends none — but slices 2–3 cannot fit their rules in those bodies, and
  that constraint belongs to them before they are written.

## Success metric

```
bash scripts/test-check-supply-chain-pin.sh \
  && bash scripts/check-supply-chain-pin.sh \
  && bash scripts/check-test-pairing.sh \
  && bash scripts/test-install-vendored.sh \
  && bash scripts/test-docs-consistency.sh \
  && bash scripts/check-telemetry.sh
```

**Decisive clause.** `check-supply-chain-pin.sh` must be **red on this tree
before the fix lands** — `install-vendored.sh:457` carries `@main` and
`flywheel-update.yml:27` clones an unpinned `main`. A gate written after the fix
and never seen failing proves nothing; this one is written first and its first
run is the failing one. The observable that proves the mitigation works is that
the gate names *both* lines, separately.

**How a reviewer sees it fail if it were removed.** Two independent reverts, each
of which must turn it red on its own:

1. Restore `@main` in the caller template → red naming
   `install-vendored.sh`'s `uses:` line.
2. Leave the caller pinned and delete the `checkout --detach "$SHA"` step from
   `flywheel-update.yml` → **still red**, naming the clone step.

Revert 2 is the one that matters. A gate that only checks the caller's `uses:`
passes revert 2 while the hole is fully open — which is exactly the mistake the
backlog's own wording ("pin the reusable workflow to a tag/SHA") would have
produced. If revert 2 does not go red, the gate is decoration.
