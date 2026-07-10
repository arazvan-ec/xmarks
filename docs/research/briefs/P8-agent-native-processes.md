# Brief: P8 — agent-native runtime pillar (`process` + `run`)

**One-liner:** give flywheel a second pillar where Claude *operates* the repo as
the runtime — define a recurring domain operation as a **process contract**, run
it as the backend, persist to the repo's own datastore, and mature the contract
each run. Makes the target repo [agent-native](https://every.to/go-agent-native).

**Prereqs:** none. **Blocks:** nothing. **Branch:**
`claude/plugin-agent-native-repo`. **Version:** next unreleased (0.15.0 at time of
writing). **Status:** ✅ shipped v0.15.0.

**Read first (bounded context):** this brief + [`../agent-native-processes.md`](../agent-native-processes.md)
(the vision + design, incl. the owner's original ask). You do NOT need the chat
history.

## Goal & locked decisions

Extend flywheel from "build the software" to also "operate the software", with
Claude as the execution engine (not static backend code). Locked decisions:
- **Two verbs** — `/flywheel:process` (define + mature) and `/flywheel:run`
  (execute + persist + mature), mirroring how pillar 1 splits `spec` from `work`.
- **Persistence follows the repo** — declared once in `.claude/flywheel/DATA.md`
  (Store / Access / Schema / Conventions); flywheel writes through it and never
  imposes a datastore. Runs must *prove* the write (read-back / affected rows) and
  be idempotent on a declared key.
- **Maturation is evidence-gated** — ≤1 refinement per run, only from that run;
  fixed-rule changes are versioned in the contract. Cross-process lessons go to
  `LEARNINGS.md` via `/flywheel:compound`.
- **Reuse the `evaluator` agent** for the optional metric cross-check; add no new
  agent.

## Files to change

- **New** `skills/process/SKILL.md` — scaffold/mature a process contract at
  `.claude/flywheel/processes/<slug>.md`; bootstrap `.claude/flywheel/DATA.md`.
- **New** `skills/run/SKILL.md` — execute a contract, persist per `DATA.md`,
  optionally cross-check with `evaluator`, append a matured refinement.
- `README.md` command table + a "second pillar" section + the two new state files.
- `skills/help/SKILL.md` map + "what flywheel is" + "how to pick" (docs-consistency
  requires the command in both README and help).
- `scripts/session-start.sh` — add a "Runtime:" banner line.
- Root `CLAUDE.md` (north-star) + `docs/research/agent-native-processes.md`
  (vision/design) + `docs/research/improvement-proposals.md` (P8 + decision log) +
  `docs/research/journal.md`.
- `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` +
  `upgrades/v0.15.0.md`.

## Implementation notes

- The vendoring installer auto-discovers `skills/*` and `agents/*`, so no
  installer edit is needed; re-vendoring picks up `/flywheel-process` +
  `/flywheel-run`.
- `requires-action`: **false** — additive, no migration in installed repos.
- Keep the contracts concrete (fixed Rules + Output schema + Persistence mapping);
  a vague contract yields a vague run.

## Acceptance criteria

- `/flywheel:process <desc>` writes a contract in the documented shape and a
  `DATA.md` reflecting the repo's real persistence strategy.
- `/flywheel:run <slug> <input>` follows the fixed rules, persists with verified
  evidence, and appends at most one evidence-based improvement.
- docs-consistency + install-vendored + read-prime + `plugin validate` green.

## Starter prompt (paste into a fresh session)

> Implement flywheel proposal **P8 (agent-native runtime pillar)** on branch
> `claude/plugin-agent-native-repo`. Read only
> `docs/research/briefs/P8-agent-native-processes.md` and
> `docs/research/agent-native-processes.md`, then add the `/flywheel:process` and
> `/flywheel:run` skills, the `.claude/flywheel/DATA.md` convention, and sync
> README / `/flywheel:help` / the SessionStart banner. Follow the release
> checklist in `docs/research/briefs/README.md`. Commit and push. No PR unless
> asked.
