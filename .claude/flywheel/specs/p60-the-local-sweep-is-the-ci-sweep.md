# Spec: P60 — the local sweep is the CI sweep

**Slug:** `p60-the-local-sweep-is-the-ci-sweep` · **Created:** 2026-09-23 · **Backlog:** P60
**Status:** spec + plan committed, not built.

**Prime:** `docs/research/template-opportunities-2026-09.md` § P60, and the owner's
decision (2026-09-23) that a step with no judgment in it is a script, not a prompt template.

## R — Requirements

The pre-push sweep is run by hand, and the details it drops are what differ between
runs, never the intent. p31/#80 had nine gates green and CI red on the tenth.
`test-run-cost.sh` went unrun for four releases. A red was hidden behind `| tail`
(e6b6efd). A sweep run next to three reviewers gave a false red (review retro). The
same `for t in scripts/test-*.sh` loop is pasted into 8 specs, and it calls the
base-ref gates without the `origin/<base>` that CI passes (`validate-plugins.yml:57,61`).

1. **`scripts/sweep.sh [<base-ref>]`** runs what `validate-plugins.yml` runs. It
   discovers every `scripts/test-*.sh`, and reads the `check-*.sh` list with its
   arguments from the workflow itself, so the two cannot drift. `${{ github.base_ref }}`
   resolves to the argument, which defaults to `origin/main`.
2. **The runs are sequential and use a private `TMPDIR`**, so no two suites share a
   clock or a scratch dir.
3. **The verdict is read from `$?`**, never from the output. Each script prints one
   line: `PASS`/`FAIL <name>`. A failure prints the last 20 lines of that script's
   output. The run ends with `N/N passed`, and the sweep exits 1 if any script failed.
4. **`claude plugin validate . --strict` runs when the CLI is present.** When it is
   absent, the sweep says `SKIPPED` rather than passing silently.
5. **`bash scripts/sweep.sh` joins `task-closure-allow.txt`**, so a plan task can cite
   it as its check.
6. **The pasted loop leaves `CLAUDE.md`.** CLAUDE.md's "Run before pushing" list becomes
   `bash scripts/sweep.sh`. The specs are history and stay as they are.

## Success metric

`bash scripts/test-sweep.sh` passes with these arms:
- the gate list equals the workflow's list, and a `check-*` added to the workflow
  appears in it;
- one failing fixture script makes the sweep exit 1 and name that script, even when
  its output ends in a success line;
- the base ref reaches `check-release-bump.sh` and `check-test-pairing.sh`;
- a missing `claude` CLI reports `SKIPPED`.

`bash scripts/sweep.sh origin/main` on the real tree prints `N/N passed`, where N is
the count CI runs.

## Safeguards

- Keep it cheap: no new dependencies, just bash plus the workflow YAML read with grep/sed.
- What it cannot see: CI's runner differences (the mawk vs gawk case from p12). This is
  a local mirror, not a replacement for CI.
