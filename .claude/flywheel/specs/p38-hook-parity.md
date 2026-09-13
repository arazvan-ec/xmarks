# Spec: P38 — hook wiring parity gate

**Slug:** `p38-hook-parity` · **Created:** 2026-09-13 · **Backlog:** P38
**Status:** shipped as **v0.47.0** (PR #60) — the repo was in parity on arrival
(8 registrations agree), proven by mutation in a repo copy and then by a fourth
mutation its own suite does not make: narrowing a matcher on one side only,
which the gate catches in both directions. So matchers are genuinely compared,
not normalized away.
**Prime:** `upgrades/v0.44.1.md`'s post-mortem — v0.44.0 added
`delegation-guard.sh`/`delegation-record.sh` to `hooks/hooks.json` and stopped
there; a vendored repo would have refreshed to 0.44.0 with the guard neither
copied nor registered, silently, because a hook that never fires is
indistinguishable from one with nothing to warn about. Hotfixed by hand in
v0.44.1; the root cause — nothing asserts the two wirings agree — was left
open. This spec closes it.

## R — Requirements

flywheel has two independently-wired hook delivery paths: an **installed**
plugin is wired by `hooks/hooks.json`; a **vendored** repo (the documented path
for Claude Code on the web, which never installs marketplace plugins) is wired
by `scripts/install-vendored.sh`, whose hook list is hand-maintained bash +
a python heredoc. Nothing asserts the two agree. Build a CI gate that does,
covering both directions of drift and the distinct "registered but not copied"
failure mode the 0.44.0/0.44.1 incident actually hit.

## E — Entities

| Entity | Where | Notes |
| --- | --- | --- |
| Hook triple | `(event, matcher-or-"", basename of the .sh command)` | the unit both wirings must agree on; full paths legitimately differ (`${CLAUDE_PLUGIN_ROOT}/scripts/` vs `.claude/flywheel/bin/`) |
| hooks.json wiring | `hooks/hooks.json` `.hooks` | ground truth for the installed path |
| Installer wiring | a throwaway target's `.claude/settings.json` `.hooks`, produced by actually running `install-vendored.sh` | ground truth for the vendored path — never statically parsed |
| Landed script | `<target>/.claude/flywheel/bin/<name>.sh`, executable | registration without a copied script is a separate failure mode from a missing registration |
| Allowlist (unused) | `scripts/hook-parity-allow.txt` | not created — every hook in hooks.json is vendored today; add it only when a hook is legitimately not vendored |

## A — Approach

**Behavioral, not textual.** `install-vendored.sh`'s bash variables and python
heredoc are not statically parsed — a parser for that shape would be as
fragile as the thing it guards, and would drift the same way the hand-written
list already did. Instead: `mktemp -d` a throwaway target, actually run
`bash scripts/install-vendored.sh <target>`, then read what it really wrote to
`<target>/.claude/settings.json`. Comparing real output to real output is the
only comparison a heredoc the parser doesn't understand can't fool.

**Fail loudly, not fail-open.** A CI gate, not a session hook — the posture of
`check-invocation-budget.sh` / `check-fixture-leaks.sh` applies, not the
fail-open posture of the hook scripts (those must never break a session; this
must never let a silent half-install ship). Unusable input exits 2, a real
mismatch exits 1, `SKIP_HOOK_PARITY=1` is a logged, never-silent escape hatch.

**Residual risk, stated plainly:** this gate proves the two wirings **agree**,
not that either is **correct**. A hook added to both places identically wrong
(same wrong matcher) still passes. It also can't catch a hook whose *behavior*
differs between the two copies of a script — `install-vendored.sh` rewrites
`/flywheel:` references but isn't expected to alter hook logic — that class of
drift is out of scope.

## S — Structure

- `scripts/check-hook-parity.sh` — the gate: run the installer, extract
  triples from both JSONs via `python3`, diff both directions, check every
  hooks.json script landed executable in `bin/`.
- `scripts/test-check-hook-parity.sh` — proves it by mutation: copies the repo
  (never the real one) into a scratch dir, breaks one wiring at a time (a
  dropped installer registration, a dropped hooks.json registration, a
  registered-but-uncopied script), asserts each goes red naming the hook, and
  asserts a pristine copy and the real repo go green.
- `.github/workflows/validate-plugins.yml` — one step next to
  `check-invocation-budget.sh` / `check-fixture-leaks.sh`, same style. The
  existing `scripts/test-*.sh` glob discovery already runs the paired test;
  nothing else in the workflow changes.
- No `scripts/hook-parity-allow.txt` — not needed today.

## O — Operations

1. Exit 2 fast on unusable input: no `hooks/hooks.json`, no
   `scripts/install-vendored.sh`, no `python3`.
2. `mktemp -d` a target; `trap` removes it on any exit.
3. Run the installer into the target quietly; a nonzero exit is unusable input
   (exit 2) — a broken install can't be judged for parity.
4. Extract `(event, matcher-or-"", basename)` triples from `hooks/hooks.json`
   and from the target's `.claude/settings.json` the same way.
5. Diff both directions: hooks.json-only triples ("the installer does not
   register it" — the 0.44.0 shape) and installer-only triples ("hooks.json
   does not have it" — the reverse drift), each named on its own line.
6. For every basename hooks.json names, check it landed as an executable file
   under the target's `.claude/flywheel/bin/`; report a miss separately from a
   registration mismatch.
7. Exit 1 if any of the above found something; exit 0 with a one-line OK.

## N — Norms

Match the voice of `check-invocation-budget.sh` and `check-fixture-leaks.sh`: a
short argumentative header naming the incident, a usage/env-var block, an
explicit exit-code contract. bash + stdlib `python3` only, no new dependency.
Terse code — no ceremonial comments beyond what states a constraint the code
can't show itself.

## S — Safeguards

- **Fail loud, always** — no fail-open path; the one escape hatch
  (`SKIP_HOOK_PARITY=1`) always logs.
- **Never mutates the real repo.** The test copies the repo into a scratch dir
  for every mutation case and asserts afterward (`git diff --quiet`) that
  `hooks/hooks.json` and `scripts/install-vendored.sh` are untouched.
- **A vacuous pass is refused**: zero `.sh` hook commands found in
  `hooks/hooks.json` is unusable input (exit 2), not trivial parity.
- **Two failure modes stay distinct**: a missing registration and a
  registered-but-uncopied script get different messages — the 0.44.0 incident
  had both, and a maintainer fixing one must not assume the other is fixed.

## Success metric

One command, exit 0 = PASS:

```bash
bash scripts/test-check-hook-parity.sh && bash scripts/check-hook-parity.sh
```
