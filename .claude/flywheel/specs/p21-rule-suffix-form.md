# Spec: P21 examples teach the `:*` rule form, not the over-broad bare `*`

**Slug:** `p21-rule-suffix-form` · **Created:** 2026-09-07 · **Backlog:** review finding (dead-impact PR #2)
**Status:** shipped as v0.38.0 — metric PASS
**Prime:** dead-impact round-4 review: a P21-materialized rule copied the skill's
example form `Bash(bash run-tests.sh*)`; the official permissions doc marks the
bare trailing `*` as the over-broad form (`Bash(ls*)` also matches `lsof`),
while `:*` is the exact-prefix equivalent of ` *` and guaranteed to match the
bare command.

## R — Requirements

Every P21 example rule the plugin teaches (`skills/spec`, `skills/process`,
README) uses the `:*` suffix form, and spec/process say never to emit a bare
trailing `*`. Prose-only; no script or grader changes.

## Success metric

`grep -rn 'Bash([^)]*[^: )]\*)' skills/*/SKILL.md README.md` returns no
P21 example (frontmatter `allowed-tools` space-form entries like `Bash(git *)`
are the documented ` *` form and stay), and
`bash scripts/test-docs-consistency.sh` + `bash scripts/test-install-vendored.sh`
exit 0.
