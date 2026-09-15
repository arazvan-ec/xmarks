# Spec: P43 — flywheel's hooks run on flywheel

**Slug:** `p43-hooks-run-on-flywheel` · **Created:** 2026-09-15 · **Backlog:** P43
**Status:** shipped as v0.55.0 — metric PASS. **Acceptance observation RECORDED
2026-09-15T01:10:36Z**, by artifact rather than by prompt: `delegation-record.sh`
wrote `/tmp/flywheel-delegation-<hash>.jsonl` for the T4 `Agent` call, and this
session's SessionStart injected the ledger. Both hooks fire.
**Correction:** an earlier note in this file claimed the guard "did not fire"
because no prompt appeared. That inference was invalid — an `ask` can be resolved
by the session's permission mode without ever surfacing. Run directly on that
call's payload, `delegation-guard.sh` does return `ask` (a CONTEXT finding).

**Prime:** P41, which declared this debt in its own "known-remaining" and shipped
`--agents-only`; P38 (`check-hook-parity.sh`), whose comparison this reuses; and
this session's ledger entry *"an instruction nothing can observe failing is not
enforced"* — which is why the flag ships with a gate rather than alone.

## R — Requirements

flywheel ships eight hook registrations and none of them fire in its own repo.
`.claude/settings.json` here has `extraKnownMarketplaces`, `enabledPlugins` and
`permissions` — and no `hooks` key at all. So `delegation-guard.sh` never asked
about a single delegation this session, `session-start.sh` never injected the
ledger, and `read-prime.sh` never primed a read. P41 named this debt and left it.

Checked before designing, because activating hooks changes every future session
in this repo, not just one:

| hook | effect here |
| --- | --- |
| `gate.sh` (Stop) | **inert** — opt-in on a project `.claude/flywheel/gate.sh`, which does not exist |
| `delegation-record.sh` | writes to the system temp dir, never the project — no `git status` noise |
| `session-start.sh`, `git-tracking-refs.sh` | read-only / refspec only, always exit 0 |
| `read-prime.sh` | advisory, never blocks |
| `write-allow.sh`, `bash-allow.sh` | allow-only; they *remove* prompts for `.claude/flywheel/**` writes and loop git commands |
| `delegation-guard.sh` | returns `ask`, never denies — new friction on `Agent`/`Task`, which is its purpose |

In scope:

1. `install-vendored.sh --hooks-only`, **self-target only**: writes the eight
   registrations into this repo's `.claude/settings.json` and nothing else.
2. The commands point at **`$CLAUDE_PROJECT_DIR/scripts/<name>.sh`**, not at
   `.claude/flywheel/bin/`. The scripts are already in this repo; copying them
   would recreate P41's duplication and need a parity gate of its own.
3. `check-hook-parity.sh` gains a third assertion: this repo's own
   `settings.json` carries every `(event, matcher, script)` triple that
   `hooks/hooks.json` declares. Without it the wiring drifts silently, which is
   the failure this repo has now shipped twice.

Out of scope:

- `--hooks-only` against another repo. The full install already wires a
  consuming repo; a narrowed mode there would only offer a way to half-wire one.
- Vendoring flywheel's **skills** into its own repo. Still refused, still for the
  same reason.
- Creating a project `.claude/flywheel/gate.sh`. Whether this repo wants a Stop
  gate is a separate decision, not a side effect of wiring hooks.

## E — Entities

| Entity | What | Where |
| --- | --- | --- |
| the mode | `--hooks-only`, self-target only | `scripts/install-vendored.sh` |
| the wiring | eight registrations pointing at `scripts/` | `.claude/settings.json` |
| the gate | settings.json ⟷ hooks.json, both directions | `scripts/check-hook-parity.sh` |

## A — Approach

Point the hooks at the scripts where they already live. The installer builds its
eight command strings from one path prefix; the self-target mode swaps that
prefix for `scripts/` and reuses the existing settings.json merge untouched.

Rejected: vendoring `bin/` copies into this repo (P41's duplication again, plus a
second parity gate to keep them honest); and a `--hooks-only` that also works on
foreign repos (the full install covers those, and a narrowed one there is a way
to leave a repo half-wired).

Trade-off accepted: this repo's sessions get one new `ask` on every `Agent`/`Task`
call. That is the guard doing its job — the same guard that would have asked
about every delegation in the P40a–P42 cycles and never did.

## S — Structure

`install-vendored.sh`: one flag, one path variable, one early exit after the
settings merge. `check-hook-parity.sh`: one more assertion against the repo's own
settings.json. `.claude/settings.json`: gains a `hooks` key. No new script, no new
data file.

## O — Operations

1. Red: cases in `scripts/test-install-vendored.sh` (self-target writes only
   settings.json; foreign target refused; idempotent) and in
   `scripts/test-check-hook-parity.sh` (a missing self-registration fails).
2. Green: the flag, then the third parity assertion.
3. Run it on this repo; commit the resulting `settings.json`.
4. CI is already wired for `check-hook-parity.sh` — nothing to add.
5. README + bump to `0.55.0` + `upgrades/v0.55.0.md`.

## N — Norms

Test-first for both scripts. Terse code. Atomic commits, pushed per task. A
`scripts/` change is a release with an upgrade note.

## S — Safeguards

- **No behavior change to the full install.** `test-install-vendored.sh`'s
  existing cases stay green, unedited, and a foreign target still gets bin/ copies.
- **The narrowed mode writes one file.** It must not create `.claude/skills`,
  `.claude/agents` or `.claude/flywheel/bin` — asserted, not intended.
- **`permissions` and the marketplace keys survive.** The settings merge is the
  installer's existing one, which preserves unrelated keys; the test asserts the
  pre-existing `permissions.allow` entries are still there afterwards.
- **The Stop gate stays inert.** No project `gate.sh` is created; if a future
  cycle wants one, that is its own decision to make in the open.

## Success metric

```
bash scripts/test-install-vendored.sh \
  && bash scripts/test-check-hook-parity.sh \
  && bash scripts/check-hook-parity.sh \
  && bash scripts/check-test-pairing.sh \
  && bash scripts/install-vendored.sh --hooks-only . >/dev/null \
  && git diff --quiet .claude/settings.json \
  && python3 -c "import json;d=json.load(open('.claude/settings.json'));assert len(d['hooks'])>=3 and d['permissions']['allow']"
```

Re-running the self-wiring produces **no diff**, and the decisive clause: with a
registration removed from `.claude/settings.json`, `check-hook-parity.sh` exits
non-zero and names the missing hook.
