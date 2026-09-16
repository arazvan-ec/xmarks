# docs-full-fanout

A committed cheat: correct report, wrong routing. The docs-only diff is fanned
out to all three reviewers, so both negative routing assertions fire. This is the
half of the security rule ("only when the diff touches input handling, auth,
secrets or dependencies") that has a fixture where it is unambiguous.
