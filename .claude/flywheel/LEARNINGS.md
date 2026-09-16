# flywheel learnings

## gotcha: a derived field has a boundary where it cannot exist, and the boundary repeats every run

<!-- fw: type=gotcha; date=2026-09-16; files=scripts/read-meter.sh,skills/work/references/work-detail.md; spec=p45-elapsed-has-a-start; branch=claude/flywheel-token-optimization-7ywqoz; evidence=p42 4/5, p43 3/4 and p44 3/4 all omit elapsed_s on line 1; after the meter supplied it, run-cost.sh reports full coverage with no PARTIAL marker -->

`elapsed_s` came from commit-time deltas, and a delta needs a previous commit.
The **first** transition of every cycle has none — so every run in the repo was
permanently PARTIAL by exactly one line, always the same line, and the pattern
read as three unrelated near-misses rather than one structural hole.

Three runs each missing one field looks like sloppiness. The same line missing it
in all three is a method that cannot reach there. When coverage is partial, check
*which* rows are missing before assuming the writer was careless — and note that
the same method also failed outright where its precondition was absent entirely
(no git repo at all, as in `work`'s own eval fixture).

## pattern: the strongest evidence for a clause is a fresh reader hitting the case it was written for

<!-- fw: type=pattern; date=2026-09-16; files=skills/work/references/work-detail.md,skills/work/evals/benchmarks/2026-09-16-v0.57.0/benchmark.json; spec=p45-elapsed-has-a-start; branch=claude/flywheel-token-optimization-7ywqoz; evidence=the release-gate executor reported that --since first would have cut at 18:11:16Z, predating its cycle and sweeping in 110 unrelated calls, and passed the explicit start the clause prescribes -->

A caveat was added to `work`'s cost rule minutes before the release gate ran: a
session that did other work before the cycle must not use `--since first`,
because that cut predates the cycle. The gate's fresh-context executor hit
exactly that situation, diagnosed it in its own words, and did what the clause
says — without being pointed at it.

A rule that reads well proves nothing. A rule that an independent reader applies
correctly at the moment it matters is verified, and the eval's numeric score was
the weaker half of that run's evidence.

## gotcha: an instrument with no source reads UNMEASURED forever, and looks fine doing it

<!-- fw: type=gotcha; date=2026-09-16; files=scripts/read-meter.sh,skills/work/references/work-detail.md; spec=p44-read-volume-is-observed; branch=claude/flywheel-token-optimization-7ywqoz; evidence=18 telemetry lines across 3 files carried zero instances of bytes_in and zero of tool_calls; after the meter shipped, run-cost.sh on this cycle reports bytes_in=50,786 and tool_calls=56 -->

P40a shipped `cost.bytes_in` with honest coverage accounting, and for a day the
accounting worked perfectly on nothing: every line reported the field UNMEASURED
because no line ever carried it. The rule asked a session to "sum what you
actually read" — a running total it was never given anywhere to keep — so every
honest session omitted it, and the omission looked like correct behavior rather
than a dead field.

A gate that reports absence is not the same as a gate that notices absence is
total. The count that mattered — *zero lines out of eighteen* — took a `grep -c`,
not an instrument. Ask of any proxy: what writes it, and has anything ever?

## decision: a premise borrowed from someone else's repo is a hypothesis, and the first measurement can kill it

<!-- fw: type=decision; date=2026-09-16; files=docs/research/improvement-proposals.md; spec=p44-read-volume-is-observed; branch=claude/flywheel-token-optimization-7ywqoz; evidence=70 metered calls: largest single read 5,446 B with nothing above 8 KB, median 545 B, and 85% of volume from Bash against 12.7% from Read -->

P40b was designed from an article reporting ~90% savings by diverting bulk reads
on a Java monorepo: an extractor agent behind a size threshold on `Read`. The
first metered cycle here shows no read above 8 KB — so the threshold has nothing
to fire on — and puts 85% of read volume in `Bash`, a tool the mechanism never
touches. Both halves miss, and building it would have optimized an eighth of a
distribution that has no peak.

The value was never in the mechanism; it was in the observation underneath it
(I/O inside a task is unrouted). Port the observation, measure locally, and let
the number decide the mechanism — including deciding against the one that
inspired the work.

## gotcha: an instruction nothing can observe failing is not enforced

<!-- fw: type=gotcha; date=2026-09-15; files=skills/work/SKILL.md,skills/plan/SKILL.md,scripts/check-telemetry.sh,scripts/check-agent-parity.sh; spec=p42-telemetry-has-an-owner; pr=74; branch=claude/flywheel-token-optimization-7ywqoz; evidence=two independent instances found by probing, not reading — `Agent type 'executor' not found` twice on a plan routing four tasks to `haiku/low+delegate` (unhonored since v0.39.0, nine versions), and zero conforming telemetry across the repo's entire history despite the rule sitting in work's body the whole time -->

Two rules in this repo were dead for months and neither left a trace. `+delegate` routes degraded to whatever tier the session was on because the `executor` agent was never registered; `work`'s telemetry line was never written because its clause read *"inside a `/flywheel:loop` cycle"* and CLAUDE.md tells every session to run `spec → work → verify`, which never names `loop`. Both were found by trying to execute them, never by reading them — a skipped fail-open rule produces exactly the same artifacts as a satisfied one.

The guard is not better wording: it is asking, for every rule that matters, *what would be different if this never ran?* If the answer is "nothing", the rule needs an artifact and a gate, or it is a suggestion. Prefer removing a precondition over documenting it — and when you must keep one, state its opposite out loud, because a silent condition is what caused both of these.

The mirror error is just as easy, and I made it the same day: concluding a hook had *not* fired because no permission prompt appeared. An `ask` can be resolved by the session's permission mode without ever surfacing, so the prompt was never the evidence. `delegation-record.sh` had written its state file for that exact call all along. **Verify a rule by the artifact it leaves, never by the interruption you expected to see** — in both directions, the observable trace is the only thing that counts.

## decision: a ratchet's baseline lists what is EXEMPT, never what is expected

<!-- fw: type=decision; date=2026-09-15; files=scripts/telemetry-baseline.txt,scripts/check-telemetry.sh,scripts/invocation-budget.txt; spec=p42-telemetry-has-an-owner; pr=74; branch=claude/flywheel-token-optimization-7ywqoz; evidence=on first contact with an unrelated cycle the gate failed immediately — merging main surfaced p14c-contract-defect-escalates with no telemetry, which an expected-list would have passed in silence -->

A list of what is *expected* to be covered has the same failure mode as the rule it replaces: it needs someone to remember to add the new entry. Inverting it — the file names what is **exempt**, with a reason — makes a new spec covered by default, so forgetting fails the gate and silencing one is a visible line in the diff. It proved itself the same day: merging `main` brought in a cycle from another branch with no telemetry and the gate caught it immediately.

Two rules keep the list honest. An exemption with no reason is unusable input, because an exemption is a debt and the reason is what makes it payable. And the exemption covers *shape* only — the `tokens` ban fails regardless of the baseline, since P18 governs what may enter the ledger at all rather than how a line is formed.

## gotcha: a missing field is not a zero, and the zero fabricates the win

<!-- fw: type=gotcha; date=2026-09-15; files=scripts/run-cost.sh,scripts/test-run-cost.sh; spec=p40a-read-volume-proxy; pr=65; branch=claude/flywheel-token-optimization-7ywqoz; evidence=run-cost.sh on this cycle's real telemetry prints bytes_in and tool_calls as UNMEASURED and elapsed_s as PARTIAL 4 of 5, rather than totalling absent fields as 0 -->

Adding `bytes_in` to the telemetry schema meant every run written earlier carried a `cost` object complete for three fields and absent for the fourth. Totalling that absence as 0 would have made every pre-existing baseline look as though it read nothing — handing the next optimization a fabricated improvement, for the very measurement the field was added to judge. The accounting had to move from per-line to **per-field**: an uncovered field reports UNMEASURED, partial coverage prints its count, and a two-run delta refuses a field either side never recorded instead of printing a meaningless percentage.

Generalizes past this schema: whenever a metric gains a dimension, the old data is not zero on it, it is silent on it. Any comparison that treats the two as the same is a lie with a number attached.

## pattern: a gate you have never seen fail is not a verified gate

<!-- fw: type=pattern; date=2026-09-15; files=scripts/check-telemetry.sh,scripts/test-check-telemetry.sh; spec=p42-telemetry-has-an-owner; pr=74; branch=claude/flywheel-token-optimization-7ywqoz; evidence=the gate shipped broken twice — once because its check was piped to `tail -1` with $? unread, once because a review bot reproduced `{"state":"completed","tokens":123}` slipping past a ban three documents already promised was unexemptable -->

A new gate was written, its unit tests passed, and it was still exiting 1 on the real tree: the baseline exempted coverage but not conformance, so one historical file failed it permanently. The verification had piped the gate to `tail -1` and never read `$?`, so the summary line looked fine while the exit code said otherwise.

Two habits fix this and both are cheap. Read the exit code, never the tail of the output. And before trusting a gate, make it fail on purpose against the real tree — introduce the exact condition it exists to catch, assert it exits non-zero *and names the thing*, then remove it and assert green again. Unit tests prove the logic; only the probe proves the wiring.

The sharper version came from the same gate a day later. Its upgrade note, its PR body and a ledger entry all stated that the baseline exempts a line's *shape* but never the `tokens` ban — and a malformed line on a baselined slug hit `continue` on the shape check and never reached the ban. **A guarantee is not a guarantee until a test fails without it.** Writing it down three times only made the gap harder to see: for every rule of the form "X never happens", the test that proves it is the one where X is attempted through the exemption, not the one where X is attempted head-on.

## decision: a task is tier 1 only if EVERY part of it is mechanical

<!-- fw: type=decision; date=2026-09-15; files=skills/plan/SKILL.md,skills/work/SKILL.md,scripts/route-tiers.txt; spec=p40a-read-volume-proxy; pr=65; branch=claude/flywheel-token-optimization-7ywqoz; evidence=T6 routed haiku/low+delegate delivered the version bump exactly as specified and returned a release summary with an ungrammatical central clause and a false claim about baselines; taken back a tier and rewritten -->

"Bump the version and write the upgrade note" reads mechanical and is not: the bump is, the note is judgment. The delegated run got the bump exactly right and the prose wrong in a way that would have shipped a false statement about baselines into a release note.

Route by the *hardest* part of a task, not its average, and when a task mixes a mechanical half with a written one, split it rather than routing the pair. The escalation itself was cheap and correct — `work`'s rule that an escalation is never argued with worked — but the plan should not have needed it.

## gotcha: a long-lived branch is behind main long before git says "conflict"

<!-- fw: type=gotcha; date=2026-09-15; files=.claude-plugin/plugin.json,upgrades; spec=p42-telemetry-has-an-owner; pr=74; branch=claude/flywheel-token-optimization-7ywqoz; evidence=`git diff --stat main..HEAD` showed 1,232 deletions of other people's work because local main was stale; and twice a release number this branch had taken (0.49.0/0.50.0, then 0.53.0) was claimed on main first, forcing a renumber of note, manifest, spec, plan and benchmark dir -->

Twice in one session this branch was silently behind: once with a stale *local* `main` that made the diff look like it deleted 1,232 lines of someone else's work, and twice with a release number already claimed on real `main`. Neither showed up as a conflict — git was happy, the branch was just wrong.

Before opening a PR: `git fetch origin main`, then diff against `origin/main` rather than the local ref, and re-check the version and `upgrades/` filename after any merge. In this repo a version number is a claim on a shared namespace, so it is only actually yours once it is on `main`.

## fixture: running a flywheel skill eval end to end

<!-- fw: type=fixture; date=2026-09-13; files=scripts/fixture-scratch.sh,skills/process/evals/check.sh,skills/work/evals/check.sh; spec=p35-invocation-context-budget; branch=claude/skill-context-optimization-l21ryh; evidence=three suites run this way — process 15/15, work 7/7, run 4/4, each matching its committed benchmark; ~70k subagent tokens per eval, not the 300-800k the backlog assumed -->

Three commands, no ritual. Instantiate: `bash scripts/fixture-scratch.sh <skill> <id> --into <dir>` (`--into` takes a dir you own, so it survives the run and can be graded afterwards; without it the scratch is a mktemp that gets torn down). Get the prompt with `--print-prompt`. Then dispatch a **fresh-context subagent**, giving it four things: the absolute path of the SKILL.md to follow, the workdir as "the repo you are operating on", the eval's prompt verbatim as `$ARGUMENTS`, and eval-mode rules (the sign-off GATE is pre-approved, ask no clarifying questions, stay inside the workdir). Grade with `bash skills/<skill>/evals/check.sh <id> <dir>`.

Two things that will bite. The subagent must be told explicitly not to write into the xmarks checkout — the skill file lives there and it will otherwise treat it as the project root. And a run costs ~70k subagent tokens, an order of magnitude under the figure the backlog uses to argue evals are too expensive to run; one eval per touched skill is affordable as a release gate.

## pattern: extraction behind a citation keeps the skill intact — when the rules stay in the body

<!-- fw: type=pattern; date=2026-09-13; files=skills/process/SKILL.md,skills/process/references/contract-template.md,skills/work/SKILL.md; spec=p35-invocation-context-budget; branch=claude/skill-context-optimization-l21ryh; evidence=process eval 1 at 15/15 with the 54-line contract template moved behind a citation; work 7/7 reproducing the committed benchmark's own fail-open note; run 4/4 maturing its contract with the maturation detail cited -->

Moving step-scoped detail out of a `SKILL.md` into `references/<topic>.md` did **not** degrade the skills: a fresh subagent following the shortened body reached the cited material and produced output the graders passed. The split that made it safe: the body keeps the rules that bite (what must never be got wrong, stated imperatively), the reference keeps shapes, procedures, catalogues and rationale, and the citation sits **at the step that needs it**, worded as an instruction to read it now rather than a "see also".

The check that proves a given extraction, cheaply: diff every line removed from the body against the body plus its references (`grep -qxF -- "$line"` per line — note the `--`, or a line starting with `-` is read as an option). A removed line that lands in no reference is a lost rule. Run it before the commit, not after.

## gotcha: a new branch in install-vendored.sh can land with zero coverage and the suite still says "all installer tests passed"

<!-- fw: type=gotcha; date=2026-09-13; files=scripts/install-vendored.sh,scripts/test-install-vendored.sh; spec=p35-invocation-context-budget; branch=claude/skill-context-optimization-l21ryh; evidence=review deleted the three new lines and the suite still exited 0; after the added assertions, the same deletion turns it red -->

`test-install-vendored.sh` installs into more than one target, and which uninstall branch a target exercises depends on whether its skill dir collided with a vendored name at setup time. A new branch added to the *collision* path is invisible to a test that only ever uninstalls from a *fresh* target — the suite passes, reports nothing, and the path could be deleted outright without a failure.

The guard is a mutation check, and it is two commands: delete the branch you just wrote, run the suite, confirm it goes red, restore. Cheap enough to do every time, and it is the only thing that distinguishes "the test passes" from "the test tests this".

## decision: a cost paid per invocation needs a per-skill ceiling, never a sum

<!-- fw: type=decision; date=2026-09-13; files=scripts/check-invocation-budget.sh,scripts/invocation-budget.txt,scripts/check-description-budget.sh; spec=p35-invocation-context-budget; branch=claude/skill-context-optimization-l21ryh; evidence=measured over v0.39.0-v0.43.0 — the summed, gated cost (descriptions) held at 3,301→3,326/3,600 while the ungated per-invocation cost (bodies) grew 14%, 60,527→69,065 B -->

P24 budgets the `description` fields as a **total** because every session pays all of them together. A `SKILL.md` body is paid alone, by whoever invokes that skill, so the same shape would measure a cost nobody pays and would let the largest skill grow as long as a small one shrank. The rule generalizes: match the invariant's shape to how the cost is actually incurred — sum what is always paid together, cap what is paid one at a time.

Rejected alongside it: trusting spec-and-review discipline without a gate. The 14% drift above happened entirely inside diffs that passed both. Measure in bytes (`wc -c`), not characters — `wc -m` silently equals `wc -c` under `LC_ALL=C`, and a gate whose verdict depends on the runner's locale is not a gate.

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

## gotcha: a gate can report green while the cost it measures gets worse

<!-- fw: type=gotcha; date=2026-09-13; files=scripts/check-invocation-budget.sh,scripts/invocation-budget.txt,skills/work/SKILL.md; spec=p36-invocation-worst-case; branch=claude/recent-changes-review-ic3hai; evidence=measured body+references for all six skills P35 extracted — every one grew in total; work 8,385 -> 11,245 B while the gate printed "OK — worst case work at 5,259/5,300" -->

P35 capped the **body** and left the **reference** free, so an extraction that moved a hot-path rule behind a citation scored as a saving while the invocation that follows the citation pays both. Every one of the six extracted skills grew in total; `work` grew 34% under a green verdict.

The general shape: **a gate measures a proxy, and the proxy can move opposite to the thing you care about.** The cheap defence is one sentence written at spec time — *what can this gate not see?* For P35 it would have been "it cannot see the cost of a reference that is read", which is the whole bug, found for free before any code. Write that sentence into the Safeguards of anything that introduces a `check-*.sh`.

Corollary, learned the hard way twice in one day: a ceiling set to its largest occupant plus a few bytes is not a budget, it is a description of the status quo. P35 shipped 41 B of headroom; the first P36 cut left `help` 121 B; both redden CI on the next ordinary edit. Set it from a rule (~300 B above the tightest occupant) and put the rule in the file.

## gotcha: the release gate is the suite that can SEE the change, not the one named after the skill

<!-- fw: type=gotcha; date=2026-09-13; files=skills/work/evals/evals.json,skills/loop/evals/evals.json,skills/work/SKILL.md; spec=p39-work-invocation-debt; branch=claude/recent-changes-review-ic3hai; evidence=work eval 1 passed 7/7 while its executor reported "commit skipped: the workdir is not a git repository"; loop eval 1 (11/11) is what actually asserted the transition line, the absent tokens key and every sha resolving -->

P22 phase 2 says run the skill's eval before bumping. Taken literally it would have gated a change to `work`'s commit discipline and telemetry on a suite that asserts **neither**: `work` eval 1's workdir is not a git repository, so its commit path is only ever exercised as "fail-open, reported once", and no commit, transition line or route is asserted at all.

Before trusting an eval as a gate, check that its assertions actually touch what the diff moved — read the `expectations` array, not the suite's name. Here that meant running `loop` eval 1 as well, which grades the telemetry and resolves every recorded sha against git. Both suites cost ~70k subagent tokens each, so "run the one that can see it too" is affordable.

## pattern: much of an "extraction" can be the body restated — measure before crediting it

<!-- fw: type=pattern; date=2026-09-13; files=skills/work/SKILL.md,skills/work/references/work-detail.md,docs/research/work-loop-rationale.md; spec=p39-work-invocation-debt; branch=claude/recent-changes-review-ic3hai; evidence=section-by-section measurement of work-detail.md — ~3,300 of 5,986 B restated body rules with their reasoning; re-partitioning gave 11,245 -> 6,241 B with work eval 1 at 7/7 and loop eval 1 at 11/11 -->

This qualifies the earlier *"extraction behind a citation keeps the skill intact"* entry. It does — but only if what moves is not already in the body. In `work-detail.md`, *why the git pair is force-free* (339 B) restated the body's two commands, *the reasoning behind each commit rule* (1,101 B) restated all four bullets, *why two reds and not three* (456 B) restated the rule plus a sentence, and *delegation thresholds* (1,416 B) restated the four the body already named. Roughly 3,300 B was the body said twice.

The test that sorts every line, and the third bucket is the one people forget: does a run executing this skill need it **to act**? Yes → the body, stated once. It is a shape the run must reproduce exactly → the reference. It explains **why** the rule is right → a doc no skill cites, so it is never loaded. Design argument is for the person deciding whether to change a rule, not for the model following it.

Two warnings. Apply the test to the **body** as well, or you move an argument while its twin stays. And a rule summarized into a pointer is the failure mode: `work`'s three routing cases were compressed to "all three: <reference>", which is the one place the P35 extraction genuinely weakened the skill — bringing them back grew the body 137 B and was the point of the exercise.

## decision: two hand-maintained lists need a parity assertion, and the behavioral check beats the parser

<!-- fw: type=decision; date=2026-09-13; files=scripts/check-hook-parity.sh,scripts/install-vendored.sh,hooks/hooks.json; spec=p38-hook-parity; branch=claude/recent-changes-review-ic3hai; evidence=gate built by running the installer into a throwaway target; caught a dropped registration, the reverse drift, a registered-but-never-copied script, and a matcher narrowed on one side only — each named, in both directions -->

v0.44.0 updated `hooks/hooks.json` and not `install-vendored.sh`'s hand-maintained list, shipping a guard a vendored repo would never have registered. v0.44.1 fixed the instance **by hand** and left the duplication. Fixing an instance of a duplication bug without asserting the invariant just schedules the next one.

The gate that works is **behavioral**: run the installer into a throwaway target, read the settings it actually produced, and diff normalized `(event, matcher, script)` triples against the source of truth, in both directions. A static parser for the installer's bash and its Python heredoc would be as fragile as the drift it guards and would assert what the script *says* rather than what it *does*. Same shape wherever two wirings must agree.

Its blind spot, stated because that is now the rule: it proves the two **agree**, never that either is correct. A hook registered on the wrong matcher in both places passes.

## gotcha: a guard that fires on its own project's hot path stops being read

<!-- fw: type=gotcha; date=2026-09-13; files=scripts/delegation-guard.sh,agents/executor.md,skills/work/SKILL.md; spec=p37-delegation-subagent-tier; branch=claude/recent-changes-review-ic3hai; evidence=every agents/*.md pins model:/effort: in frontmatter, so Agent(subagent_type:"executor") — the call skills/work/SKILL.md instructs — tripped a TIER ask; confirmed by running the pre-P37 script against the same payload -->

The delegation guard asked whenever `model` was absent, on the premise that the child inherits the caller's. True for `create_session`, **false** for a subagent whose `subagent_type` names an agent that pins its own tier — which is every agent in this repo, and the call `work` itself instructs for a `+delegate` task.

The cost is not the extra keystroke. An advisory that fires on a decision already made trains its reader to click through, and the warnings that matter — the pasted contract, the duplicate child, the fan that grew on its own — go with it. When adding an advisory check, enumerate the call sites your **own** project makes and confirm none of them trip it; a guard whose first firing is a false positive has already lost.

## gotcha: a negative fixture must break the mechanism the code actually reads

<!-- fw: type=gotcha; date=2026-09-14; files=skills/run/evals/fixtures/unreachable-store-repo/.claude/flywheel/processes/plate-audit.md,skills/run/SKILL.md; spec=p14a-store-probe-and-discovery; branch=claude/recent-changes-review-ic3hai; evidence=the fixture declared a dead Postgres in DATA.md, the run persisted a row anyway and was right to — step 1 says the contract's Persistence OVERRIDES DATA.md, and the contract named a reachable markdown store -->

A fixture built to prove "the run refuses when its store is unreachable" broke the wrong lever: it made `DATA.md` unreachable while the contract's own **Persistence** section — which the skill says *overrides* DATA.md — still named a perfectly reachable file. The executor followed the skill exactly, persisted, and reported the conflict. **The fixture tested nothing, and the test run is what exposed it.**

Before building a negative fixture, trace the **override chain** for the value you are breaking and break it at the level the code actually reads. Then confirm the red run fails for the reason you intended, not merely that it fails: a red arm passing for the wrong reason is indistinguishable from a working test until the day it matters.

And leave the tempting wrong answer in place. `data/plate-audits.md` stays in that fixture, writable and shaped exactly like the output schema, precisely because it is what a desperate run would write to — which is what gives the "no silent fallback" assertion something to catch.

## pattern: a grader of pure negatives is hollow — one positive has to prove the subject ran

<!-- fw: type=pattern; date=2026-09-14; files=skills/run/evals/check.sh,scripts/test-eval-graders.sh,skills/run/SKILL.md; spec=p14a-store-probe-and-discovery; branch=claude/recent-changes-review-ic3hai; evidence=all five negative assertions passed on a pristine workdir; adding the blocker-line assertion turned it red on untouched and green only on a deliberate refusal (7/7) -->

When the correct outcome of a test is that **nothing happened**, every assertion is a negative — nothing persisted, nothing staged, no step completed — and a workdir nobody ever touched satisfies all of them. That is P26's red-on-untouched invariant catching a hollow grader, and it catches it every time.

The fix is one **positive** assertion proving the subject ran and *chose* to stop: here, that the run recorded a `blocked` transition before halting. Which means the design has to leave that trace — so the invariant did not just improve the test, it added a rule to the skill. A blocked run that leaves no evidence is indistinguishable from a run that never started, for a grader and for a person reading the repo afterwards.

## gotcha: a metric clause must discriminate, not just read well

<!-- fw: type=gotcha; date=2026-09-14; files=.claude/flywheel/specs/p14a-store-probe-and-discovery.md,scripts/test-session-start.sh; spec=p14a-store-probe-and-discovery; branch=claude/recent-changes-review-ic3hai; evidence=two in one cycle — an assertion demanding the absence of "deterministic breakdown" when that phrase IS the first sentence under test, and `grep -q 'processes/'` which never matches because the script writes `.../flywheel/processes` with no trailing slash -->

Twice in one cycle a check failed while the code was correct, because the check was chosen for how it *reads* rather than for what it *discriminates*. One asserted the absence of a phrase that was part of the very sentence it was testing. One grepped a literal string that the working implementation never produces.

Before committing a clause, name the **wrong state it would catch**. If you cannot name one, it is decoration; if the state you name is not the one the feature can actually reach, it is worse than decoration, because it will fail on correct code and train you to edit the test.

The corollary is the one that saved this cycle: when a signed metric fails, find out **which** clause and why, before touching anything. One of the two failures here was a bad proxy — and the other was real, catching that a signed requirement had been deferred and not shipped. Editing the metric on the first sign of red would have buried the second.

## decision: a ratchet that fires on ordinary work is miscalibrated, not tight

<!-- fw: type=decision; date=2026-09-14; files=scripts/invocation-budget.txt,skills/run/SKILL.md,skills/process/references/data-strategy-and-extensions.md; spec=p14a-store-probe-and-discovery; branch=claude/recent-changes-review-ic3hai; evidence=three ceiling breaches in one slice — run body at 4,819/4,800 and again needing a catalogue moved, process worst at 11,025/10,500 — each AFTER every byte of argument had already been moved to uncited docs -->

The per-skill byte ceilings (P36) are the right instrument, and the headroom I gave them was a number I made up: ~300 B, chosen because it was round. One ordinary feature — three rules added to one step — breached a ceiling **three times in a single slice**, every time with the argument already moved out and only rules and catalogues left.

**~500 B is what a feature costs**, measured. Set headroom from that, and when a ceiling blocks work, try the moves in this order: move the *argument* to an uncited `docs/research/` note (it is never loaded, so it is free); move a *catalogue or procedure* to `references/` — but only when the ceiling is `body`, since `worst` charges the reference either way; and only then consider the number. Recalibrating after the first two are exhausted is engineering; reaching for it first is the drift the ratchet exists to stop.

## gotcha: a fixture must leave the path under test REACHABLE, not merely break the right lever

<!-- fw: type=gotcha; date=2026-09-14; files=skills/run/evals/check.sh,skills/run/SKILL.md; spec=p14b-maturation-survives; branch=claude/recent-changes-review-ic3hai; evidence=a fixture built to test "the maturation is committed" made the contract self-contradictory, which blocks the run — and step 4 matures only after a SUCCESSFUL run, so no assertion could reach the behaviour; the eval was deleted and its assertions moved to the happy-path suite, where red→green then proved on real runs -->

The earlier entry says break the lever the code actually reads. This is the other half: **breaking it must not close the door you came through.** A fixture built to grade "the improvement is committed" made the contract contradict itself — which *blocks* the run, while the step that improves the contract runs only after a **successful** one. The fixture was well-aimed and still ungradeable, because the path under test was unreachable in it.

Two questions before building one, and the second is the one that gets skipped: *what wrong state does this catch?* and *does the subject still reach the code I am grading?* Trace the route from the fixture's condition to the behaviour, and if a guard sits between them, the fixture is testing the guard.

The corollary is cheap: the behaviour was already reachable in the **happy-path** suite, which is where the assertions ended up. Before building a fixture for a behaviour, check whether an existing suite already reaches it — a new fixture is surface, and surface that grades nothing is worse than none.

## gotcha: "a commit touches this file" is true before the run starts — the fixture's own seed made it

<!-- fw: type=gotcha; date=2026-09-14; files=skills/run/evals/check.sh; spec=p14b-maturation-survives; branch=claude/recent-changes-review-ic3hai; evidence=`git log --format=%H -- <contract>` returned the fixture's seed commit, so the assertion PASSED on the workdir where the maturation had been staged and lost — the exact defect it was written to catch -->

A grader asserting "the change was committed" reached for `git log -- <path>`. Every eval fixture is seeded with `git add -A && git commit -qm seed`, so that path has a commit **before the subject does anything**. The assertion passed on the red run.

Assert on **content in HEAD**, not on the existence of history: `git show HEAD:<path>` must carry the thing the change was supposed to add, and `git diff HEAD -- <path>` plus `git diff --cached -- <path>` must both be empty. Those three cannot be satisfied by a seed, and between them they separate "committed" from "staged", from "left dirty", from "never touched".

Same family as *a metric clause must discriminate*, and worth its own entry because the trap is mechanical rather than a matter of care: the fixture's setup is what makes the naive assertion true, so reading the grader alone will never reveal it.

## decision: when two competent runs disagree about what a skill requires, the skill is silent

<!-- fw: type=decision; date=2026-09-14; files=skills/run/SKILL.md; spec=p14b-maturation-survives; branch=claude/recent-changes-review-ic3hai; evidence=given a contract whose Output schema contradicted its own Rules, one executor proceeded with the true value and matured the contract; another refused to emit a non-conforming output AND refused to mature, holding that a schema change with a version bump is not a blocked run's call — both reasoned explicitly and neither broke a stated rule -->

Two fresh-context executors, same skill, same fixture, opposite behaviour — and reading both transcripts, neither violated anything the skill says. That is not one of them being wrong. **It is the skill being silent on a case it never anticipated**, and the disagreement is the cheapest detector of that silence anyone will ever get.

So when eval runs diverge, resist grading one correct. Ask what rule would have made both act the same, and check whether the skill contains it. Here it did not: nothing covers a run blocked by a defect in **its own contract**, as opposed to bad input or an unreachable store. The gap went to the backlog as a requirement, not to the grader as a tiebreak.

## pattern: when a skill writes into someone else's repo, split artifacts by who owns them

<!-- fw: type=pattern; date=2026-09-14; files=skills/run/SKILL.md,skills/run/evals/check.sh; spec=p14b-maturation-survives; branch=claude/recent-changes-review-ic3hai; evidence=the maturation commit is pathspec-scoped to the contract and the eval asserts it carries exactly one file; the datastore row is left to DATA.md, whose git-native strategy declares "staged" to BE the proof of a landed write -->

A run produces two kinds of output, and they are not the same kind of thing. The **contract** is the plugin's artifact: the plugin defines its shape, so the plugin decides it must be committed rather than left staged, where staged dies with the session. The **datastore row** is the repo's: DATA.md decides how results persist, and for a git-native store "staged" may *be* the declared proof that a write landed.

So the commit is pathspec-scoped to the contract alone. A `git add -A` would sweep the row into a commit labelled "mature the contract" and, worse, override the repo's own persistence strategy with the plugin's habit. Assert the scope — the eval requires the commit to carry exactly one file — because the sweep is invisible in the happy case and only shows up as a confusing diff weeks later.

The general rule for any tool that writes inside a repo it does not own: decide per artifact **who owns it**, act only on your own, and leave the host's conventions to the host.

## pattern: when you split a rule, the gate must run the half you did NOT change

<!-- fw: type=pattern; date=2026-09-15; files=skills/run/SKILL.md,skills/run/evals/check.sh; spec=p14c-contract-defect-escalates; branch=claude/recent-changes-review-ic3hai; evidence=step 2's single sentence routed both invalid inputs and unsatisfiable contracts; the release added the second branch, and eval 3 — the ordinary-rejection case, which the release is not about — was put in the gate and stayed 3/3, so rejections did not leak into the new branch -->

Splitting one sentence into two paths is the cheapest place to break the path that already worked. The new branch gets the attention and the eval; the old half silently starts catching cases it should not, and nothing notices until an ordinary input turns into a blocked run.

So the gate for a split includes the **old** case, not just the new one — even when the release has nothing to do with it and running it costs an extra execution. Here that was eval 3, the invalid-input rejection: it stayed green, and its executor described the distinction in the release's own words without being shown them (*"the contract is coherent; this input just cannot satisfy it"*), which is the strongest signal available that the split reads the way it was meant to.

## pattern: a separation is only proven by running every path it separates

<!-- fw: type=pattern; date=2026-09-15; files=skills/run/evals/evals.json,skills/run/evals/check.sh; spec=p14c-contract-defect-escalates; branch=claude/recent-changes-review-ic3hai; evidence=four paths run for one release — happy 7/7, invalid input 3/3, unreachable store 7/7, contradictory contract 6/6 — and the new artifact (a spec stub) appeared in exactly one of the four -->

The claim was not "the new branch works". It was "**four outcomes are distinguishable**": a run that succeeds, one whose input is rejected, one whose store is unreachable, and one whose contract contradicts itself. No single eval can show that, because each one alone proves only that its own path does something — never that the others do something *different*.

The shape that proves it is a table with one column per path and a mark in exactly one cell. Build the gate to fill that table, and read the empty cells as assertions: three runs producing **no** stub is what makes the fourth one's stub mean anything.

## gotcha: a fail-open that fires every single time means the primary path is fiction

<!-- fw: type=gotcha; date=2026-09-15; files=skills/run/SKILL.md; spec=p14c-contract-defect-escalates; branch=claude/recent-changes-review-ic3hai; evidence=EIGHT of eight fresh-context runs this session reported no host task system, so step 0's "materialize each contract Rule as a visible task" degraded to the JSONL ledger every time — never once did the written primary path execute -->

`run` step 0 tells a run to materialize each contract Rule as a visible task in the host task system, and to fall open to the ledger if that is unavailable. Across eight independent executions, the fallback fired **eight times**. The documented primary path has never once run.

Fail-open is the right behaviour and it worked perfectly — which is exactly why this hid. A degradation that always happens produces no failures, no alerts and no complaints; it simply means the rule everyone reads is not the rule anyone executes, and the fallback quietly became the real specification.

The check is cheap and nobody runs it: **count how often the fallback fires**. Always is a defect — either the primary path should be removed and the fallback promoted to the rule, or the capability it assumes should be made real. Writing it as the primary path is the one option the evidence rules out.
