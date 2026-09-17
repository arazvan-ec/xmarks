# Spec: P47 — the release convention, enforced in the direction it is written

**Slug:** `p47-release-gate-direction` · **Created:** 2026-09-17 · **Backlog:** P47
**Status:** shipped as v0.63.0 — metric PASS. 25 discovered `scripts/test-*.sh`
and 10 `check-*` gates green under an isolated `TMPDIR`; `claude plugin validate
. --strict` passes. Both decisive clauses hold on real history rather than a
fixture: `check-version-citations.sh` is green on the tree as it stands (4
pointers, all resolving, no exclusion list) and red on that same tree with the
0.61.0 renumber put back, naming the workflow once; `check-release-bump.sh`
exits 1 on PR #85 replayed against its real base and reports 0.62.0 → 0.63.0
here.

**Prime:** P22 (`check-test-pairing.sh`, the only gate here that already reasons
about a diff against a merge base), P46 (an assertion that cannot fire on a live
run), and the ledger entries *"asserting a step is PRESENT says nothing about
what it operates on"* and *"a gate can be green, correct, and never run"*.

## R — Requirements

CLAUDE.md: *every change to `skills/`, `agents/`, `hooks/` or `scripts/` is a
release* — bump `.claude-plugin/plugin.json`, add `upgrades/v<version>.md` — and
it names `test-docs-consistency.sh` as the enforcement. That gate reads the
version out of `plugin.json` and asserts a matching note exists. It enforces the
**converse**: it can only see releases that were declared, never changes that
should have declared one.

Two misses, both green at the time:

| miss | what shipped | what no gate asked |
| --- | --- | --- |
| PR #85 | `scripts/gate.sh` + `scripts/test-gate.sh`, no bump, no note | this diff touched `scripts/` — where is the bump? |
| the 0.61.0 renumber | a shipped `::error::` telling a refused third-party repo to go read an upgrade note for the slice's pre-renumber number | does that note exist? |

In scope, two assertions, each seen red before its green:

1. **Bump implied by path.** If the diff against the merge base touches
   `skills/`, `agents/`, `hooks/` or `scripts/`, then `plugin.json`'s version
   must be **ahead of** the base's — not merely different from it, see
   **Safeguards** — **and** `upgrades/v<new>.md` must exist. Escape hatch: a
   labelled exception carrying a reason — never a silent pass.
2. **A remedy pointer resolves.** A citation in tracked text that *sends a
   reader to* an upgrade note must name a note that is there.

Out of scope, deliberately — see **Safeguards** for the reasoning:

- Blocking a docs-only PR. Assertion 1 keys on the four release-bearing
  directories precisely so `docs/research/` stays free.
- Asserting that every `v<x.y.z>` **named** in prose resolves to a file.

## E — Entities

- **release-bearing path** — `skills/`, `agents/`, `hooks/`, `scripts/`. The four
  CLAUDE.md names, no more: the convention is the spec, not this gate's taste.
- **mention** — text that *names* a version or an upgrade note: a changelog line,
  an `evidence=` field, a backlog row describing a defect. A historical fact.
- **remedy pointer** — text that *sends the reader to* an upgrade note: a link
  whose target is the note, or a directive (`see`, `read`, `follow`, `consult`,
  `refer to`) immediately preceding its path. A destination, and therefore a
  claim that the destination exists.

## A — Approach

**Assertion 1** is `check-test-pairing.sh`'s shape with a different question, and
reuses its base-ref resolution verbatim so the two gates cannot disagree about
what "the base" is. `plugin.json` is read at the base with `git show` and in the
working tree, because a bump is a *difference*, not a value.

**Assertion 2 is the whole design problem.** The repo's prose names old versions
constantly and legitimately — upgrade notes reference predecessors, the backlog
says "shipped v0.42.0", learnings carry `evidence=`. A rule of *"every version
mentioned must have a file"* is red on all of that. Counted on the tree as it
stands: exactly one cited upgrade note does not exist — `0.59.0`, named twice in
`docs/research/improvement-proposals.md`, **both times in the backlog entry that
documents this very defect**. A naive rule reddens on the description of the bug
it exists to catch, and the only way out is an exclusion list, which is the
loosening this cycle is supposed to avoid.

So the rule keys on the **claim the text makes**, not on the version appearing.
"The renumber left `<note>` cited" asserts nothing about the file system; it is
a mention. "See `<note>`" asserts the file is there, to a reader who in the
failing case is a third-party repo that cannot see this tree at all. Only the
second is checkable, and only the second was ever wrong.

Those two examples are written with a placeholder because the gate cannot tell
an illustrative quotation from a live pointer — it read the first draft of this
paragraph and was right to. That is the rule's standing cost, paid here first.

Measured on the tree at `2e57402`: 4 remedy pointers, all resolving — the gate
is green on the real historical corpus without one exclusion.

## S — Structure

Two scripts, because the two assertions have different triggers: assertion 1
needs a merge base and is meaningful only on a pull request; assertion 2 reads
the tree and should run on every event.

- `scripts/check-release-bump.sh` + `scripts/test-check-release-bump.sh`
- `scripts/check-version-citations.sh` + `scripts/test-check-version-citations.sh`
- `.github/workflows/validate-plugins.yml` — both wired, and its `paths:` filters
  reconciled with assertion 2's corpus.
- `CLAUDE.md` — the convention names its real enforcement.
- `.claude-plugin/plugin.json` → **0.63.0** · `upgrades/v0.63.0.md`

## O — Operations

- T1 test-first, assertion 1: a scripts-only diff with no bump red; with a bump
  but no note red; with both green; a docs-only diff green; the exception with a
  reason green and loud; the exception without a reason red.
- T2 implement `check-release-bump.sh`.
- T3 test-first, assertion 2: the v0.61.0 mistake reconstructed red; every
  mention form green; the tree as it stands green.
- T4 implement `check-version-citations.sh`.
- T5 wire both into CI; close the `paths:` hole.
- T6 release: CLAUDE.md, bump, upgrade note, every discovered gate.

## N — Norms

Test-first, each assertion watched red before its green. Terse code. Atomic
commits, pushed per task. This diff touches `scripts/`, so it is a release and
assertion 1 applies to it: the gate must not block its own PR by accident.

## S — Safeguards

- **"Ahead of", not "different from".** Written as "different", assertion 1
  passes PR #85 verbatim: that branch was cut before main moved and carries
  0.58.0 against a base of 0.61.0, so its version differs and the weaker rule
  reports OK. The test watched exactly that before the rule tightened.
- **Assertion 2 admits its ceiling.** It catches a dead destination, not a
  *wrong* one: a pointer naming an upgrade note that exists but is the wrong
  release reads as green. The renumber produced a dead one, which is the case
  with evidence behind it.
- **Bare versions stay out.** `v0.59.0` alone is not a destination — resolving it
  to a file assumes the reader meant the upgrade note. The corpus has **zero**
  occurrences of a directive followed by a bare version, so including the form
  would add false-positive surface against no evidence that it ever occurs.
- **The exception is a debt with a reason on it.** `SKIP_RELEASE_BUMP` takes the
  reason, not a `1`; a bare truthy value is rejected, so nobody can silence the
  gate without saying why in the diff.
- **No exclusion list in assertion 2.** The moment a path has to be excluded, the
  rule is wrong — say so rather than adding the line.
- **Fail-loud on unusable input, never fail-open.** A missing `plugin.json` at
  either end exits 2; it is not a pass.

## Success metric

```
export TMPDIR="$(mktemp -d)"
shopt -s nullglob
for t in scripts/test-*.sh; do bash "$t" || echo "RED $t"; done
for g in scripts/check-*.sh; do bash "$g" || echo "RED $g"; done
bash scripts/check-release-bump.sh origin/main
```

Decisive clauses, both on real history rather than a synthetic fixture:

1. `check-version-citations.sh` is **green on `main` at `2e57402`** and **red on
   that same tree with the shipped `::error::` pointing at the slice's
   pre-renumber note** — the mistake as it was, reconstructed.
2. `check-release-bump.sh` is **red on PR #85's diff** (`scripts/gate.sh` +
   `scripts/test-gate.sh`, no bump) and **green on this PR**, which bumps.
