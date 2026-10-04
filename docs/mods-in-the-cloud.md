# Turning on flywheel's mods in Claude Code web

Cloud sessions do not install marketplace plugins, so a mod is loaded by folder
through `CLAUDE_CODE_PLUGIN_DIRS`. This was verified in a cloud container on CLI
2.1.289 (P72). Set it once per environment, and every new session loads the mods.

## 1. Environment settings (cloud environment menu → Edit)

**Setup script**: add one line. Until PR #111 merges, clone the branch that has
`mods/`:

```bash
git clone --depth 1 -b ccr-ad2de139-xfsj6z https://github.com/arazvan-ec/xmarks /opt/xmarks
```

After it merges, drop `-b ccr-ad2de139-xfsj6z`.

**Environment variable** (absolute paths, `:`-separated):

```
CLAUDE_CODE_PLUGIN_DIRS=/opt/xmarks/mods/resource-committee:/opt/xmarks/mods/big-brother-token:/opt/xmarks/mods/newspeak
```

A project's own `.claude/settings.json` cannot set this variable. Only the
process environment or `~/.claude/settings.json` can.

## 2. Check it loaded (in a new session)

- `/committee` answers with the current route (e.g. `sonnet/medium — auto (routine)`).
- `/ministry` answers with the bytes read so far.
- The status line shows 🏛 and 👁 entries.
- If a mod fails to load, a dim transcript line names it and the reason.

## 3. What these three collect, and what it decides

| Mod | Command | Collects | Decides |
| --- | --- | --- | --- |
| resource-committee | `/committee stats` | per-session tally of tiers chosen and switches | P78: whether to hold plan-task routes |
| big-brother-token | `/ministry` | bytes by tool, Bash bytes by command, cost per session | P78 (does routing save?), P80 (which Bash commands to ration) |
| newspeak | `/newspeak` | list items without a criterion; prose multi-item asks by kind, last 20 kept locally | P77: whether a prose nudge is worth its false positives |

After about a week of normal use, run the three commands and paste their output
into a session in this repo. That is the data P77, P78 and P80 are waiting on.

The other mods are opt-in the same way. The ones that hold tools (`memory-hole`,
`ration-book`, `general-strike`) and the one that blocks a reply
(`thought-police`) are best added after these three have run for a while.
