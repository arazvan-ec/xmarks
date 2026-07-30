# flywheel learnings

## fixture: planted-bug mini-repo for grading a verifier (tally family)
<!-- fw: type=fixture; date=2026-07-29; files=skills/verify/evals/fixtures/tally-fail/app.py,skills/verify/evals/fixtures/tally-sneaky/app.py,skills/verify/evals/fixtures/tally-pass/app.py,skills/verify/evals/evals.json; spec=p22-evals-pillar1; branch=claude/p22-evals-pillar1-23u4h7; evidence=sanity runs 2026-07-29: tally-fail unittest FAILED + CLI total=14.75, tally-sneaky unittest OK + CLI rows=2, tally-pass OK + rows=3 total=20.00 -->

Recipe for a mini-repo whose ground truth is known, so a verifier's verdict is
gradeable without judgment calls: python3 stdlib only (`csv` + `unittest`, no
installs), a CLI entrypoint, and the repo's own spec at
`.claude/flywheel/specs/<slug>.md` whose Success metric names BOTH gates
(tests exit 0 AND exact CLI output). Plant three states from one clean base:
(1) bug in the library → tests fail; (2) bug only in the `__main__` path —
e.g. a bogus "exclude the header row" `n -= 1` after `csv.DictReader` already
dropped it — so tests stay green and only actually running the CLI exposes the
miss (the rationalization trap); (3) the untouched clean control, which keeps
an always-FAIL verifier from scoring. Fixtures are templates: every run works
on a copy.

## fixture: auditable red→green kata — log RESULT + impl hash per test run
<!-- fw: type=fixture; date=2026-07-29; files=skills/work/evals/fixtures/cart-feature/run-tests.sh,skills/work/evals/fixtures/cart-bugfix/run-tests.sh,skills/work/evals/evals.json; spec=p22-evals-pillar1; branch=claude/p22-evals-pillar1-23u4h7; evidence=sanity run 2026-07-29: pristine kata logs RESULT=PASS IMPL_SHA=8b44f02e…, simulated red-first regression test logs RESULT=FAIL with the same pristine hash -->

To grade "the test ran red BEFORE the implementation" mechanically instead of
trusting a transcript: make the fixture's `run-tests.sh` the sole test
entrypoint and have it append `<utc> RESULT=<PASS|FAIL>
IMPL_SHA=<sha256 cart.py | first 16>` to `.check-log`, with the pristine hash
committed as `baseline-sha`. Test-first then reduces to two greps: first log
entry is `RESULT=FAIL` with `IMPL_SHA == baseline-sha` (red seen while the
impl was untouched — defeats impl-first-then-test), last entry is
`RESULT=PASS`. Script preserves the suite's exit code and prints its output,
so it doesn't distort the loop it audits.
<!-- fw: type=pattern; date=2026-07-29; files=scripts/install-vendored.sh,scripts/session-start.sh,skills/update/SKILL.md; spec=p19-update-postprocess; branch=claude/token-usage-writing-rkfoby; evidence=test-install-vendored.sh "pending strategies recorded" + test-session-start.sh "pending-upgrade nag" green -->

The auto-update PR's "requires action" note was ephemeral: merge the PR without
acting and the pending upgrade strategies vanished — files current, VERSION
current, debt invisible. Fix shape (P19, v0.26.0): the component that *creates*
the obligation (the installer — the only one holding both the old version and
the notes) persists it as repo state (`PENDING-UPGRADES`, never in the manifest
so pruning can't erase it); a session-start nag re-raises it every session,
offline; the acting skill clears it per item applied. General rule: when a
workflow step emits a "you must still do X" warning in a transient channel
(PR body, chat, log), have the step also write X to durable state that
something re-reads until X is done. Corollary shipped with it: refresh steps
that vendor executable code get a parse gate (`bash -n`) *before* recording
the install, so a broken copy can never be marked installed.

## decision: writing-token discipline — terse code, never echo files into chat, edit over rewrite
<!-- fw: type=decision; date=2026-07-29; files=CLAUDE.md; branch=claude/token-usage-writing-rkfoby; evidence=owner directive adopted in-session 2026-07-29 -->

The owner asked how to optimize the token cost of writing work. Adopted rules
(now in CLAUDE.md as repo convention): (1) generated code is terse by default —
no redundant comments, ceremonial docstrings, or speculative blocks; verbosity
in output compounds on every future write. (2) Never paste written/edited file
contents back into the chat response — report what changed and where; echoing
pays the same output twice when git already holds the diff. (3) Prefer `Edit`
(pay the changed lines) over regenerating whole files with `Write`. Rationale:
output tokens are the priciest, and the cost of a written class is its content
— the only lever is eliminating waste around it (re-writes, echoes, verbosity).

## pattern: surface trust at consumption without touching relevance rank
<!-- fw: type=pattern; date=2026-07-20; files=scripts/session-start.sh,skills/recall/SKILL.md; spec=p18-evidence-gated-compounding; pr=32; branch=claude/every-agent-native-config-be56a6; evidence=test-session-start.sh "only explicit unverified is flagged" green + reviewer rank-invariance check -->

When adding a trust signal to compounded entries, keep it **orthogonal to
ranking**: read `evidence=` and *prepend a marker* to explicitly-`unverified`
entries, but never let it change the relevance score — a wrong-but-relevant
entry must still surface (flagged), not be hidden. Distinguish *absent*
`evidence=` (legacy, unflagged) from an *explicit* `evidence=unverified`
(flagged) via `arr==...` on the empty-initialized field, reset per `## ` header.
Verified two ways: a test asserting legacy/verified stay clean, and a reviewer
toggling one entry unverified↔verified and confirming identical ordering.

## decision: gate knowledge the way flywheel gates code — compound only what's proven
<!-- fw: type=decision; date=2026-07-20; files=skills/compound/SKILL.md,skills/work/SKILL.md; spec=p17-fixture-knowledge; branch=claude/every-agent-native-config-be56a6 -->

The owner caught a structural inconsistency while we added P17's fixture-capture
trigger: flywheel refuses to call *code* done on reasoning (verify/review,
"unrun tests don't count") but `compound` wrote *knowledge* on belief, and that
knowledge is injected as trusted context into every later session — so a false
learning is worse than none, misleading silently. Rule adopted: a learning is
recorded only from **observed evidence this cycle** (a green check, a run/PR,
output seen), never a hypothesis or a plausible-but-unrun recipe. Shipped as
prose in v0.21.0 (fixture capture is evidence-gated); generalized to all types
as P18 (`evidence=` metadata + trust surfaced at consumption).

## fixture: how to build a hook-test fixture (the recipe we kept rediscovering)
<!-- fw: type=fixture; date=2026-07-15; files=scripts/test-gate.sh,scripts/test-session-start.sh,scripts/test-read-prime.sh; branch=claude/every-agent-native-config-be56a6 -->

Every hook test this session rebuilt the same scaffold from scratch — capture it
so the next one starts from the recipe, not from zero:
- **Isolated repo fixture:** `mktemp -d`; `git init -q "$T"`; `git -C "$T" -c
  user.email=t@t -c user.name=t checkout -qb main`; commit a base file; make an
  unstaged edit so `git diff` reports a change. `trap 'rm -rf "$WORK"' EXIT`.
- **Feed data to a `python3 -` heredoc via environment, never stdin** — the
  heredoc *is* stdin, so piped input is lost. Pass `FW_*` env vars + `os.environ`.
- **Prove a thing did NOT run** with a sentinel file the code-under-test appends
  to; assert the line count (used to prove an untrusted gate never executes).
- **Make order work against you:** put a decoy first so a broken parse/scorer
  loses to it and the test fails loudly, instead of passing by insertion order.
- **Consent/state stores:** override the location with an env var
  (`FLYWHEEL_STATE_DIR`) pointed at a temp dir so tests never touch real state.

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

## fixture: pillar-2 eval fixture — demo-repo + the plate-audit contract
<!-- fw: type=fixture; date=2026-07-29; files=skills/run/evals/fixtures/demo-repo/.claude/flywheel/processes/plate-audit.md,skills/run/evals/check.sh,skills/process/evals/check.sh; spec=p22-evals-pillar2; branch=claude/p22-evals-pillar2-ubuaty; evidence=benchmarks 2026-07-29: 6/6 evals green, 41/41 assertions (skills/{process,run}/evals/benchmarks/) -->

The behavioral evals for `process`/`run` need a target repo whose correct
output is knowable in advance. Recipe (versioned at
`skills/{run,process}/evals/fixtures/`):
- **A deliberately trivial, fully deterministic contract** (`plate-audit` v1:
  regex-validate a Spanish plate, digit_sum, upsert one markdown row) so every
  assertion is a grep on exact values — never a judgment call.
- **Seed the datastore with one row** (`1234 BCD`): it powers three cases at
  once — idempotent-upsert target, collateral-damage sentinel ("seeded row
  untouched"), and prior art the skill should read.
- **Stand up per eval**: `W=$(mktemp -d)`; copy the fixture; `git init` +
  commit as seed, so "staged" (DATA.md's landed-proof) is distinguishable
  from "committed at seed".
- **Executor brief must declare eval mode**: gates pre-approved, task system +
  artifact publishing unavailable → the skills' own fail-open paths make runs
  terminate without a human while still exercising contract law.
- **Grader over-specification is the trap**: assert only what the skill text
  fixes (run's §4 pins `### <date>` log entries; process §5 pins no format —
  accept any dated entry). Caught live in iteration 1, eval proc-3.
- **Never grade a dated artifact against the grading clock**: pin the run's
  date (`FW_EVAL_DATE`) — a correct run regraded after midnight failed on an
  `audited == today` assertion.

## pattern: a grader is only evidence once you have proven it can fail — and pass
<!-- fw: type=pattern; date=2026-07-30; files=scripts/test-eval-graders.sh,scripts/check-fixture-leaks.sh,skills/verify/evals/check.sh,skills/work/evals/check.sh; spec=p26-pillar1-graders; branch=claude/recent-changes-analysis-5p3jst; evidence=test-eval-graders.sh green: 11 red-on-untouched cases across 4 graders, 5 green-on-ideal cases; check-fixture-leaks.sh: 35 fixture files, 6 allowlisted hits -->

Two eval defects in one week — a hollow `run` assertion and answer keys inside
`verify` fixtures — were both found by accident. What made the first findable at
all was a *committed* grader someone could run against an untouched fixture. So:

- **Red-on-untouched is the primary property of a grader**, not a nicety. Make it
  a build check over every grader, for every eval id: a fixture copy with nothing
  done to it must produce a non-zero exit *and* a `FAIL:` line saying which
  expectation failed.
- **Check the mirror too.** A grader that can never pass (a typo'd regex) is just
  as useless and fails silently as "the skill regressed". Synthesize the ideal
  outcome and require green.
- **Where synthesizing the ideal would reimplement the graded thing, don't** —
  and print the gap. Pillar 2's green side is evidenced by benchmarks; a test
  that quietly covers 3 of 4 cases reads as covering 4.
- **Absence must fail loudly.** A missing `report.md` graded as a pass is worse
  than no grader: it looks like evidence.
- **Never let grading mutate what it grades.** The `work` suite re-run goes
  through `python3 -m unittest`, not `run-tests.sh`, so it cannot append to the
  `.check-log` it is reading; a test asserts the log is byte-identical after.
- **A recurring manual grep is a gate that has not been written yet.** Both eval
  READMEs carried the leak grep as mandatory; six leaks got through anyway.
  Promoting it needed an allowlist keyed on **path + pattern + a written reason**,
  because the one loose-enough-to-pass-`run-tests.sh` regex would also have passed
  the leak. Prove the allowlist is load-bearing by emptying it in a test and
  requiring the real fixtures to fail.
