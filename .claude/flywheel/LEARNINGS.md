# flywheel learnings

## gotcha: a self-writing hook must exclude its own state from any tree signature
<!-- fw: type=gotcha; date=2026-07-15; files=scripts/gate.sh,scripts/test-gate.sh; spec=p11-gate-hardening; branch=claude/every-agent-native-config-be56a6 -->

gate.sh's cost cache hashed the whole working tree including untracked files —
but the hook writes its own `.claude/flywheel/.gate-state` there, so the
signature changed every run and the cache never hit (the test caught it). Any
hook that both reads a tree signature and writes into that tree must exclude
its own state dir (`git … -- . ':(exclude).claude/flywheel'`). Corollary from
the same review: a cost cache over `git diff` (unstaged only) silently skips
staged-only and untracked-content changes — use `git diff HEAD` plus untracked
file content, or a red gate reads as green.

## gotcha: a bounded-retry counter must be keyed to what it is counting
<!-- fw: type=gotcha; date=2026-07-15; files=scripts/gate.sh,scripts/test-gate.sh; spec=p11-gate-hardening; branch=claude/every-agent-native-config-be56a6 -->

gate.sh's MAX-consecutive-block counter was global: after one failing tree
exhausted its budget and tripped the bypass, the count stayed at MAX, so the
NEXT different regression bypassed immediately with zero blocks — the gate
silently stopped enforcing. Key the counter to the failing signature (reset
when the current failure differs from the one being counted) so each distinct
failure gets its own budget. General rule: a "N attempts" limit that isn't
scoped to the specific thing being attempted leaks across unrelated cases.

## gotcha: a consent store must reject repo-influenced locations
<!-- fw: type=gotcha; date=2026-07-15; files=scripts/gate.sh; spec=p11-gate-hardening; branch=claude/every-agent-native-config-be56a6 -->

The "trust lives outside the repo so a PR can't self-authorize" guarantee is
void if the store PATH is itself repo-influenced: a PR-added project config
could point FLYWHEEL_STATE_DIR/XDG_STATE_HOME inside the repo and commit a
matching trusted-gates. gate.sh now refuses a store path that resolves under
PROJECT_DIR. When a security boundary depends on a location being external,
validate the location, not just its contents.

## gotcha: local verify green is not CI green — awk/mawk portability bites
<!-- fw: type=gotcha; date=2026-07-15; files=scripts/session-start.sh,scripts/test-session-start.sh; spec=p12-token-discipline; branch=claude/every-agent-native-config-be56a6 -->

v0.19.0's metric passed locally but the PR's test-installer job failed at the
first session-start scoring assertion. Cause: the UTF-8 truncation guard used
an octal byte-class regex (`/[\200-\277]$/`) that compiled in the local mawk
build but aborted CI's mawk, emptying the whole injection. Two guards: (1) cut
injected entries at the last newline <=500 (ASCII, portable, no octal) instead
of byte-stripping; parse metadata by scanning the whole entry for the fw: line
(matches read-prime, drops the fragile blank-line state machine). (2) A comment
containing an apostrophe INSIDE an `awk '...'` single-quoted program closes the
quote and breaks the shell — keep awk-embedded comments apostrophe-free. Run
`bash -n` and the real CI job, not just the happy-path metric, before calling a
shell change done.

## gotcha: run the signed metric verbatim — a paraphrase can pass while the contract fails
<!-- fw: type=gotcha; date=2026-07-15; files=.claude/flywheel/specs/p12-token-discipline.md,skills/review/SKILL.md; spec=p12-token-discipline; branch=claude/every-agent-native-config-be56a6 -->

The v0.19.0 verify ran a widened version of the spec's metric
(`grep -qi 'routing\|Route before'`) and passed, while the signed metric's
literal `grep -qi 'routing'` failed — the reviewer caught the verifier. The
success metric is a contract: execute it copy-paste, character for character;
if it needs adjusting, that is a spec revision, not an inline improvisation.

## gotcha: mawk substr is byte-based — truncation can emit invalid UTF-8
<!-- fw: type=gotcha; date=2026-07-15; files=scripts/session-start.sh,scripts/test-session-start.sh; spec=p12-token-discipline; branch=claude/every-agent-native-config-be56a6 -->

Plain `awk` on Ubuntu is mawk, whose `length`/`substr` count bytes: cutting an
injected entry at byte 500 can split an em-dash mid-sequence and feed invalid
UTF-8 into the session context. Guard after any awk truncation: strip trailing
continuation bytes (`/[\200-\277]$/`), then a dangling lead byte
(`/[\300-\367]$/`); assert with `iconv -f UTF-8 -t UTF-8` over dash-dense
fixtures at all three byte offsets.

## gotcha: a fast pre-filter must fall through on uncertainty, never guess
<!-- fw: type=gotcha; date=2026-07-13; files=scripts/read-prime.sh; spec=p9-read-priming-real; branch=claude/every-agent-native-config-be56a6 -->

The v0.18.0 review found two paths where read-prime's naive bash extraction
produced garbage (escaped quotes in the JSON; a basename starting with `-`
that grep parsed as an option) and the pre-filter then wrongly skipped the
python parser that WOULD have matched. The invariant: an optimization layer
may only skip work when it is certain there is nothing to find — on any
ambiguity it falls through to the slow, correct path. Guards: `grep -qF --`
and a backslash check that empties the extraction.

## gotcha: predictable names in /tmp are symlink-attack targets
<!-- fw: type=gotcha; date=2026-07-13; files=scripts/session-start.sh,scripts/test-session-start.sh; spec=p9-read-priming-real; branch=claude/every-agent-native-config-be56a6 -->

The session-start curl cache used a fixed `/tmp/flywheel-remote-version`
name: on a multi-user host a pre-planted symlink makes the hook truncate an
arbitrary victim-writable file (CWE-377), and poisoned content feeds the
update notice. Guard: per-uid suffix + `[ -f ] && [ ! -L ]` before trusting
or writing, with a symlink-rejection test.

## pattern: `python3 - <<heredoc` consumes stdin — pass data via environment
<!-- fw: type=pattern; date=2026-07-13; files=scripts/test-read-prime.sh,scripts/read-prime.sh; spec=p9-read-priming-real; branch=claude/every-agent-native-config-be56a6 -->

With `python3 -` the heredoc IS stdin (the program), so `sys.stdin.read()`
inside it returns empty — piping data in front does nothing. House pattern:
hand inputs to heredoc python via environment variables (`FW_*`) and
`os.environ`, as read-prime and the installer already do.

## gotcha: an uninstaller must trust its manifest, never its glob
<!-- fw: type=gotcha; date=2026-07-13; files=scripts/install-vendored.sh,scripts/test-install-vendored.sh; spec=p10-portability-installer; branch=claude/every-agent-native-config-be56a6 -->

The v0.17.0 review (HOLD) caught a High in freshly rewritten code: the
uninstall loop deleted `.claude/skills/flywheel-*` dirs by glob, so it
destroyed user-owned dirs it never vendored — including one the new prune
logic had just restored from backup (prune consumes the `.pre-flywheel`
marker, leaving uninstall no evidence). Guard: only delete what the manifest
says you wrote (`in_manifest`), keep everything else, and encode both
adversarial scenarios (prune-then-uninstall; never-collided user dir) as
permanent test assertions.

## decision: progress obligations live in skill prompts, not hooks
<!-- fw: type=decision; date=2026-07-13; files=skills/run/SKILL.md,skills/loop/SKILL.md,skills/work/SKILL.md,skills/process/SKILL.md; spec=p16-live-progress; branch=claude/every-agent-native-config-be56a6 -->

P16 (v0.16.0) encodes the live task-ledger + telemetry-report duty as fixed
skill text instead of a PostToolUse tracker hook. The hook was rejected because
the flow-audit had just flagged per-call hook latency as a real cost (P9/P11)
and the host task system already renders live state — prompts keep it
agent-native and zero-latency. Trade-off: advisory strength, mitigated by
writing the duty as contract-law sections (like GATEs), not tips.

## gotcha: a live report you don't regenerate is a lie
<!-- fw: type=gotcha; date=2026-07-13; files=.claude/flywheel/runs/p16-live-progress/2026-07-13.html,skills/run/SKILL.md; spec=p16-live-progress; branch=claude/every-agent-native-config-be56a6 -->

The v0.16.0 review caught the feature's own pilot report committed stale —
"SIN VEREDICTO" while the spec metric had already passed — violating the
honesty rule the report itself demonstrates. Guard: the report is state, not
prose. Regenerate at every phase transition and always immediately before
committing it; a stale flagship example undercuts the whole feature.

## pattern: route the review by diff type before fanning out
<!-- fw: type=pattern; date=2026-07-13; files=skills/review/SKILL.md; spec=p16-live-progress; branch=claude/every-agent-native-config-be56a6 -->

A prompt/docs-only diff got one combined correctness+coherence reviewer
(~64k subagent tokens) instead of the unconditional 3-reviewer fan-out (the
4-way audit cost ~380k) — same confidence at a fraction of the cost. This is
P12's routing applied manually until it ships: docs diff → single reviewer;
security only when input/auth/secrets/deps are touched; performance only for
loops/queries/IO.
