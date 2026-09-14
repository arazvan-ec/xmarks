# Why `/flywheel:process`'s data rules are what they are

The argument behind `skills/process/` and its references. Cited by no skill, so
it is neither charged by the budget gate nor loaded at execution — the rule P39
established and P14 slice 1 follows.

## Why DATA.md must exist before a contract does

A process that cannot say where its results go is not done. The contract
describes what to compute; DATA.md is the only place that says where the answer
lives, and a run that has to infer it produces records nobody can find.

## Why the Access is probed before it is declared

A declared path nobody proved is how a run discovers its store is unusable
*after* doing the work — the failure P14 slice 1 exists to remove. Proving it at
define time costs one read-only check, once, with a person present to choose a
different store if it fails.

## Why extensions are repo-owned

Extension docs are versioned and matured with the repo, never hardcoded in this
plugin: the convention belongs to the people who live with it, and a plugin that
shipped their branch policy would be wrong in every repo but one.

## Why a revision's log entry shares the run's shape

The Improvement log entry is the same one `/flywheel:run` appends, so a
contract's log reads the same whether a revision or a run matured it — a reader
should not have to learn which of the two wrote a line in order to read it.
