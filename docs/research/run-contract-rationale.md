# Why `/flywheel:run`'s rules are what they are

The argument behind the rules in `skills/run/SKILL.md`. Moved here by P14 slice 1
to buy body room for the write-path probe, under the rule P39 established: a run
executing a contract needs the rule, not the case for it, and everything a skill
body carries is paid at every invocation (P36). **Cited by no skill**, so it is
neither charged by the budget gate nor loaded at execution.

Text below is moved verbatim from `skills/run/SKILL.md` as of v0.48.0.

## Why a persist must be observed, not assumed

A persist you did not observe landing does not count as done — **the same
standard `/flywheel:work` holds for tests**. Reasoning that a write succeeded is
a hypothesis; the affected-row count or the read-back is the evidence.

## Why the metric goes to the evaluator and not to you

If the process declares a `metric`, the `evaluator` agent checks the persisted
result independently — **as `/flywheel:autoloop` does** — **rather than trusting
your own read**. The agent that produced a result is the worst judge of whether
it satisfies the metric, which is the whole reason autoloop dispatches one too.

## Why most runs mature nothing

**Most runs add nothing; that is correct.** A contract that gains a refinement
every run is not learning, it is drifting: the Improvement log fills with
restatements and the fixed rules stop being fixed. One refinement, on this run's
evidence, or none.

## Why judgment is fenced rather than trusted

Judgment latitude exists so the result is **better than a rote script would
produce** — but only inside the fence. Rules, Output schema and Guardrails are
where the contract is a contract; if judgment could override them, the process
would be a suggestion with extra steps.

## Why a missing data strategy stops the run instead of improvising

A run never improvises where results go: that is what DATA.md exists to decide,
once, with a person. A store chosen mid-run by the thing doing the writing is a
store nobody can find afterwards.

## Why the probe is read-only, and why a failure stops rather than falls back

A probe that writes is a mutation the Guardrails did not approve, and one that
would have to be undone. And a run that quietly switches store because the first
was unreachable scatters a process's records across two places with nobody told
— half the rows here, half there, and no way to know which half is where.

## Why the maturation is committed rather than staged, and why it is not pushed

A staged change dies with the session, and the datastore row the run learned
from does not — so a run that stages its maturation keeps the result and forgets
the lesson, which is the inversion of what a maturing runtime is for.

It is not pushed, though, and that is deliberate: pushing needs a branch
decision, and a run has no business making one alone. The honest consequence is
stated rather than hidden — a committed-but-unpushed improvement is still lost
when an ephemeral clone is reclaimed. This narrows the loss; it does not close
it.

## Why the commit carries the contract alone

The run also wrote a datastore row and telemetry. Those belong to the repo's own
conventions — for a git-native store, "staged" may *be* the declared proof of a
landed write — so a skill that swept them into a commit labelled "mature the
contract" would be overriding DATA.md with a habit. The contract is the plugin's
artifact; the row is the repo's.

## Why there is no static backend

There is no static backend — **Claude is the execution**. It follows the
contract's fixed rules the way a service would, applies judgment only where the
contract permits, and lands the result in the repo's real datastore. The body
says this in one line ("You are the execution: follow the contract the way a
service would"); the reference was repeating it with reasons attached.
