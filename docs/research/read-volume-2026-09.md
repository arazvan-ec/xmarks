# Read volume across six metered cycles — and what it says about P40b

**Date:** 2026-09-17 · **Scope:** analysis only. No extractor, no threshold, no
agent was built, and none is proposed as a plan below.

P40b (an `extractor` agent behind a size threshold on `Read`) was rejected on
2026-09-16 from one cycle, one session, 70 calls. The rejection said it was
re-decidable once several metered cycles accumulated
(`docs/research/improvement-proposals.md:2680-2685`). Six now exist. This is the
re-decision.

## Verdict first

**P40b stays rejected, and the evidence it was rejected on no longer exists.**

The number that decides it is **0**: the count of per-call byte figures in the
committed record, across all six cycles and all 619 calls.

P40b's mechanism is a threshold on the size of an *individual* read. The two
figures the original verdict turned on — largest single read 5,446 bytes, and
85% of volume in `Bash` rather than `Read` (`docs/research/improvement-proposals.md:2668-2671`) — are both per-call statistics. The
counter that produced them is keyed by session under the system temp dir and
never committed, by design
(`scripts/read-meter.sh:23-24`, `.claude/flywheel/specs/p44-read-volume-is-observed.md:50`).
It is gone. What the six cycles committed is a per-*transition* aggregate —
`bytes_in` and `tool_calls` — and no tool name at all:

```sh
grep -rln '"tool"' .claude/flywheel/runs/   # → no output, exit 1
```

So neither figure can be recomputed. Both are **untestable on this sample**, not
confirmed and not refuted. A recommendation to build a per-call router cannot be
drawn from data that holds no per-call number, and that is the whole of the
verdict.

Two things did change, and neither rescues the proposal — see
[what the numbers do say](#2-the-distribution-as-far-as-it-goes) and
[the candidate](#5-what-the-numbers-suggest-instead-a-candidate-not-a-plan).

## 1. What the six cycles actually are

```sh
for f in .claude/flywheel/runs/{p13-pillar2-security,p13-supply-chain-slice1,\
p31-subjective-gate-eval,p32-review-suite,p44-read-volume-is-observed,\
p45-elapsed-has-a-start}/*.jsonl; do echo "== $f"; cat -n "$f"; done
```

| cycle | metered / lines | `bytes_in` | `tool_calls` | bytes per call |
| --- | ---: | ---: | ---: | ---: |
| p13-pillar2-security | 3 / 3 | 155,431 | 46 | 3,379 |
| p13-supply-chain-slice1 | 7 / 7 | 167,079 | 142 | 1,177 |
| p31-subjective-gate-eval | 8 / 8 | 325,008 | 181 | 1,796 |
| p32-review-suite | 5 / 5 | 398,150 | 150 | 2,654 |
| p44-read-volume-is-observed | 2 / 4 | 50,786 | 56 | 907 |
| p45-elapsed-has-a-start | 4 / 4 | 43,520 | 44 | 989 |
| **pooled** | **29 / 31** | **1,139,974** | **619** | **1,842** |
| *(original verdict's session)* | — | *60,363* | *70* | *862* |

Coverage is 29 of 31 transitions. The two uncovered lines are
`p44-read-volume-is-observed/2026-09-16.jsonl:1-2` — the meter did not exist yet
when they were written, and they carry no `bytes_in` field. They are omitted, not
counted as zero (the P40a per-field rule).

**The brief's "six cycles" is really five.** The original verdict came from the
p44 cycle itself — the first metered one. Its 56 committed calls are a subset of
that verdict's 70-call session. Independent of the rejection, the sample is:

| | |
| --- | --- |
| cycles | 5 |
| `bytes_in` | 1,089,188 |
| `tool_calls` | 563 |
| bytes per call | 1,934 |

## 2. The distribution, as far as it goes

**Pooled bytes per call is 1,842 — 2.1× the 862 the original verdict saw**
(1,139,974 / 619 vs 60,363 / 70). On the independent five cycles it is 1,934,
2.2×. Per-call is the comparable unit here: cycle *totals* run from **0.72× to
6.60×** the original session's 60,363 bytes — p45 (43,520) and p44 (50,786) are
both below it — and that spread tracks how long a cycle ran at least as much as
how heavily it read. Read volume per call is not negligible here, and it rose as
the work moved off scripts.

That is the strongest statement the data supports about magnitude. It says
nothing about *shape*, and shape is what P40b needs.

### What a per-transition mean is, and is not

Each transition gives one number: `bytes_in / tool_calls`. Sorted, the 29 are:

```
382  440  556  575  902  907 1025 1132 1218 1265 1273 1301 1311 1458 1478
1497 1570 1570 1894 1913 1944 2481 2523 2698 2956 3424 3503 4304 4898
```

min 382 · median 1,478 · max 4,898.

This is **not the read distribution**. It is an average over each transition's
calls, so it flattens exactly the tail P40b would fire on: a transition of one
14 KB read and nineteen 200-byte reads reports 890 bytes per call and looks
identical to twenty uniform 890-byte reads. The spread here is a floor on the
real spread, by construction.

### Largest single read: bounded, not measured

Only two transitions have `tool_calls: 1`, and those are the sample's only exact
per-call observations:

- `p45-elapsed-has-a-start/2026-09-16.jsonl:1` — **382 bytes**
- `p13-pillar2-security/2026-09-16.jsonl:3` — **1,025 bytes**

Everything else is bounded. The largest single read in the pooled sample is:

- **at least 4,898 bytes** — a transition's max is at least its mean, and the
  largest mean is `p32-review-suite/2026-09-16.jsonl:1` (146,942 bytes / 30 calls);
- **at most 152,232 bytes** — one call could in principle be a whole transition,
  and the largest is `p31-subjective-gate-eval/2026-09-16.jsonl:5`
  (152,232 bytes / 117 calls).

`[4,898 ; 152,232]` straddles P40b's 8 KB threshold by a factor of 18. No
transition forces a >8 KB call either: the largest mean, 4,898, is below 8,192,
so "nothing above 8 KB" is consistent with this data — and so is a 152 KB read.
That is the definition of untestable.

For scale only, and explicitly an extrapolation the data cannot check: the
original cycle's max was 6.3× its mean (5,446 / 862). Carry that ratio to the
pooled mean and the largest read would be ~11.6 KB; carry it to p32's spec
transition and ~31 KB. Nothing in the committed telemetry constrains that ratio.
It is stated so a reader does not mistake the silence for a small number.

### Split by tool: unrecoverable

The run JSONL has no tool field. The 85% / 12.7% Bash-vs-Read split cannot be
recomputed, checked, or updated from the six cycles. There is no partial answer
here — the dimension is simply absent from the record.

### One live per-call record, which is not one of the six

The only per-call counter that survives is this analysis session's own, live
while this document was written:

```sh
python3 - "$(ls /tmp/flywheel-reads-*.jsonl)" <<'EOF'
import json, sys, statistics as st
from collections import defaultdict
rows = [json.loads(l) for l in open(sys.argv[1]) if l.strip()]
b = [r["bytes"] for r in rows]; t = defaultdict(int)
for r in rows: t[r["tool"]] += r["bytes"]
print("calls", len(rows), "bytes", sum(b), "median", st.median(b), "max", max(b))
for k, v in sorted(t.items(), key=lambda x: -x[1]): print(f"  {k} {v} {v/sum(b)*100:.1f}%")
EOF
```

Snapshot at the 21-call mark — the file is live, so a later re-run reports more:

| | |
| --- | --- |
| calls · bytes | 21 · 58,996 |
| median · max | 1,181 · **14,850** (25.2% of the session's volume in one call) |
| split by tool | **Bash 88.7%**, Read 11.3% |

Read this for what it is. It is one session, it is analysis rather than a dev
cycle, and its 14,850-byte call is this document's own `cat` of the six telemetry
files — self-inflicted by the measurement. It is evidence of nothing about the six
cycles. It is worth a line only because it is the sole per-call observation
available anywhere, and it points the same way twice: the volume sits in `Bash`
(88.7%, against the original verdict's 85%), and the one call above 8 KB was a
`Bash` call, which P40b's hook on `Read` would not have seen.

## 3. Do the cycles differ from each other?

Yes, beyond what shuffling explains. A permutation test on the 29 per-transition
bytes-per-call figures, grouped by cycle (20,000 shuffles, seed 40, between-group
sum of squares as the statistic):

```
observed between-group SS = 16,831,343    p = 0.0135
```

| cycle | n | mean | median |
| --- | ---: | ---: | ---: |
| p32-review-suite | 5 | 2,907 | 2,698 |
| p13-pillar2-security | 3 | 2,651 | 3,424 |
| p31-subjective-gate-eval | 8 | 2,073 | 1,742 |
| p13-supply-chain-slice1 | 7 | 1,125 | 1,265 |
| p45-elapsed-has-a-start | 4 | 913 | 896 |
| p44-read-volume-is-observed | 2 | 905 | 905 |

So the pooled figure is not one cycle with more lines. The spread is 3.2× between
the heaviest and lightest cycle, and it sorts sensibly: the eval-and-review
cycles (p32, p31) and the audit cycle (p13-pillar2, whose first transition cited
10 boundaries across the codebase) read heavily per call; the two
meter-building cycles (p44, p45) — small scripts, tight test loops — read
lightly.

**The verdict's own cycle is the lightest of the six — but it is not an outlier.**
p44 sits at 907 bytes per call, the lowest of the six, and p45 is 989; on the
section-3 means the two are within 1% of each other (905 and 913). They are a
cluster, not a lone point: the two meter-building cycles, each about half the
pooled 1,842. So the original rejection was drawn from the thinnest-reading end
of the sample — the limitation it named about itself — but calling that cycle
exceptional would overstate it. What separates the groups is the four heavier
cycles above them, not one outlier below.

Caveats on the p-value: n = 29 transitions in groups of 2 to 8; the unit is a
ratio of two aggregates, not a read; and one operator on one repo means the
groups are not independent draws from anything. It establishes that the six
cycles are not interchangeable. It does not license a per-cycle prediction.

## 4. The verdict on P40b as designed

Rejected, restated on the current evidence:

| P40b needs | the six cycles give |
| --- | --- |
| a tail of large individual reads to divert | no per-call size at all; largest read bounded to `[4,898 ; 152,232]` |
| that tail to arrive via `Read` | no tool field in any committed line |
| a threshold that fires often enough to pay for the hop | nothing to fit a threshold against |

The 2026-09-16 conclusion — "a size threshold has nothing to fire on, and it is
hooked on the wrong eighth of the distribution" — is **not reaffirmed**. It is
downgraded from *measured* to *unmeasured*. The honest position is weaker than
the one in the backlog today, and the backlog row should say so: P40b is
unjustified rather than disproven.

The one thing that has moved *toward* the proposal is magnitude, and only on a
per-call basis: 2.1× the read volume per call, with the four heavier cycles
running 1.3× to 3.7× the rate of the cycle that was judged. Cycle totals say
less than that — two of the six read fewer bytes in total than the original
session did. That makes the question worth keeping open. It does not answer it —
volume is not shape, and P40b is a bet on shape.

What would overturn this, stated so it can be: a per-call record over several
cycles showing a tail that carries a material share of volume, on a tool a hook
can intercept. That record does not exist and cannot be reconstructed after the
fact.

## 5. What the numbers suggest instead (a candidate, not a plan)

**Make the tail observable before deciding whether to route it.** The gap this
analysis hit is not a shortage of cycles — it is that the per-call record is
thrown away at session end while the aggregate is kept.

*What* to keep is constrained by the question, and the obvious answer is not
enough. P40b asks a **joint** question — how much volume arrives in individual
calls above a threshold, **and through which tool** — so a transition's overall
max, its p90 and its bytes-by-tool would not settle it: many different per-call
distributions produce those same three summaries, and none of them says whether
the calls above 8 KB were `Read` or `Bash`. That is this document's own thesis
applied to its own suggestion. The smallest thing that would answer it is
**per-tool tail statistics** — for each tool, the call count and byte total above
each of a few fixed size buckets, plus that tool's largest single call — or
simply retaining the per-call record.

Stated as a candidate: it is measurement rather than optimization, and it makes
P40b decidable on the next several cycles instead of unanswerable on these. Its
cost is real and unmeasured — a per-tool bucket table is many times the bytes of
the four-field cost object, on every transition line. It has not been specced, approved, or built here, and the existing
`bytes_in` field must keep working unchanged if it ever is — a summary that
replaces the floor with a sample would trade one blind spot for another.

Secondary, and weaker: if read volume is ever routed here, the original note
already points at command output rather than file reads. This analysis adds one
call's worth of support (the 14,850-byte `Bash` call above) and one cycle's
worth of doubt (that observation is from an analysis session, not a cycle). Not
enough to earn a proposal.

## 6. What this sample cannot answer

- **`bytes_in` is a floor, and this document does not treat it as total read
  volume.** It counts tool responses only — never the conversation itself, never
  content re-entering context, and **zero bytes for write tools**: an `Edit`
  response carries the whole pre-edit file, which never reaches context, so the
  call is counted and the bytes are not (`scripts/read-meter.sh:13-17`,
  `:121-122`). Real context intake is larger than every number here, by an
  unknown factor. A threshold tuned on a floor is tuned on the wrong curve.
- **Six cycles by one operator on one repo, all on 2026-09-16, is a sample, not
  a law.** One person's reading habits, one day, one codebase.
- **This codebase is atypical**: shell scripts, Markdown and JSON, no application
  source, no compile step, no large generated files. The Spotify Portal result
  P40 came from was a Java monorepo (source linked at
  `docs/research/improvement-proposals.md`, P40). A repo with 3,000-line source files could
  have a tail this one structurally cannot.
- **29 transitions, in groups of 2 to 8.** Every per-cycle figure rests on a
  handful of lines; p44's on two.
- **Nothing here measures cost.** `bytes_in` is a proxy chosen because it is
  observable from inside a session (`scripts/run-cost.sh:6-13`). Whether diverting
  reads would save money depends on token accounting this repo cannot see.
- **Subagent reads are counted where their transition line was written**, not
  where the work happened; a delegated task's volume lands wherever the executor
  reported it.
