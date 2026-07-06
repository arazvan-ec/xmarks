# Add flywheel to a repo

There are two ways to get flywheel into a repo, and which one you need depends on
**where you run Claude Code**:

| Surface | What works |
| --- | --- |
| Claude Code **CLI / IDE** (local) | Marketplace install via `.claude/settings.json` (§1) or `/plugin install` (§3) |
| Claude Code **web** (claude.ai/code, remote sessions) | **Vendoring only** (§2) — marketplace plugins do not auto-install in web sessions |

> **Claude Code only.** The claude.ai chat app uses a different "Skills" system and does not run
> Claude Code plugins.

## 1. Local CLI / IDE — `.claude/settings.json`

Create (or **merge into**) `.claude/settings.json` at the repo root, then commit and push:

```json
{
  "extraKnownMarketplaces": {
    "xmarks": { "source": { "source": "github", "repo": "arazvan-ec/xmarks" } }
  },
  "enabledPlugins": { "flywheel@xmarks": true }
}
```

If the file already exists, merge just these two keys (`extraKnownMarketplaces`,
`enabledPlugins`) — keep any existing settings.

Next time you open the repo in Claude Code locally and **trust the folder**, flywheel registers
and activates automatically: you'll see `🎡 flywheel loaded` at session start and the
`/flywheel:*` commands become available.

**Known limitation — this does NOT work on Claude Code web.** Web sessions don't run the
marketplace clone/install step at container start, so the plugin never registers and
`/flywheel:*` never appears there. For web, use §2.

## 2. Claude Code web — vendor the plugin into the repo

Web sessions always load what's committed in the repo itself: `.claude/skills/`,
`.claude/agents/` and the hooks in `.claude/settings.json` are part of the clone. So the
reliable way is to **vendor** flywheel into the target repo once, with
[`scripts/install-vendored.sh`](../scripts/install-vendored.sh). It copies:

- every skill → `.claude/skills/flywheel-<name>/` (commands become `/flywheel-spec`,
  `/flywheel-loop`, … — the `-` instead of `:` avoids colliding with built-ins),
- the agents → `.claude/agents/`,
- the SessionStart/Stop hook scripts → `.claude/flywheel/bin/`, wired into
  `.claude/settings.json` (existing settings are preserved; re-running is safe).

### Option A — run it locally

```bash
git clone https://github.com/arazvan-ec/xmarks /tmp/xmarks
cd /path/to/your-repo
bash /tmp/xmarks/scripts/install-vendored.sh
git add .claude && git commit -m "Vendor flywheel for Claude Code web" && git push
```

### Option B — let a web session do it (copy-paste prompt)

Open a Claude Code web session **on the target repo** and paste:

```
Add the repo arazvan-ec/xmarks to this session, then run its
scripts/install-vendored.sh against this repo's root. If adding the repo isn't
possible, clone https://github.com/arazvan-ec/xmarks into the scratchpad and run
the script from there. Review the resulting .claude/ changes, commit, and push.
```

(Add `--auto-update` to the script command if you also want weekly update PRs —
see "Keeping it up to date" below; updating on demand with `/flywheel-update`
needs nothing extra.)

From the **next** session on that repo — web, CLI, or IDE — you'll see `🎡 flywheel loaded`
and can run `/flywheel-help`, `/flywheel-loop <feature>`, etc.

The vendored version is recorded in `.claude/flywheel/VERSION` (plugin version + source
commit), so you can always check what a repo carries. Every file the install writes is listed
in `.claude/flywheel/.manifest`; anything that existed before flywheel (say, your own
`.claude/agents/verifier.md`) is backed up as `<file>.pre-flywheel` before being overwritten,
with a warning.

### Keeping it up to date

The default path is manual and needs no extra setup:

- **On demand** — `/flywheel-update` in a session on the repo (autodetects the vendored
  install, refreshes from latest `main`, shows the VERSION diff and commits), or re-run the
  script by hand.
- **Session-start notice** — vendored repos check (2s, fail-silent) for a newer version when
  a session starts and print `⬆️ flywheel X.Y.Z is available — run /flywheel-update`, so you
  know when running it is worth it. Disable with the env var `FLYWHEEL_NO_UPDATE_CHECK=1`.

Optionally, for repos you'd rather not think about:

- **Auto-update PRs** (opt-in) — install with `--auto-update` and the repo gets
  `.github/workflows/flywheel-update.yml`: a weekly job (also runnable on demand from the
  Actions tab) that opens a PR whenever a new flywheel version lands on `main` — no new
  version, no noise. Requires a one-time repo setting the installer prints the exact URL
  for: *Settings → Actions → General → "Allow GitHub Actions to create and approve pull
  requests"*.

Updates are more than a file refresh: every release ships an AI-authored note in
[`upgrades/`](../upgrades/) describing whether the version **requires action** in installed
repos. `/flywheel-update` reads the notes in the update range, executes their strategies
(idempotent, logged to `.claude/flywheel/UPGRADES.md`), and the auto-update PR includes the
same notes in its body so you see them at review time.

Released versions are tagged `vX.Y.Z` in this repo, so the version in a repo's `VERSION`
file always maps to a browsable tag.

**Uninstall:** `bash /tmp/xmarks/scripts/install-vendored.sh --uninstall /path/to/your-repo`
removes everything the install added (skills, agents, hook scripts, hook entries in
`.claude/settings.json`, `VERSION`, manifest, the auto-update workflow), restores any
`.pre-flywheel` backups, and keeps flywheel's project state
(`.claude/flywheel/LEARNINGS.md`, `specs/`, `gate.sh`).

## 3. Manual alternative (local, per session, no repo change)

```
/plugin marketplace add arazvan-ec/xmarks
/plugin install flywheel@xmarks
```

Note: this never persists in ephemeral web sessions — prefer §2 for web, §1 for local.

## Using it

- `/flywheel:help` (local plugin) or `/flywheel-help` (vendored) — onboarding + command map
- `/flywheel:loop <task>` / `/flywheel-loop <task>` — the full
  spec → plan → work → verify → review → compound cycle
- Same pattern for `spec`, `plan`, `work`, `debug`, `review`, `ship`, `autoloop`, `sync`

## Requirements

- **Claude Code** — CLI/IDE for the marketplace install (§1/§3); any surface including web
  for the vendored install (§2).
- The `arazvan-ec/xmarks` repo must be reachable at install time (it's public).
- To pick up a newer plugin version later: `/flywheel:update` (local) or `/flywheel-update`
  (vendored) — it autodetects the install mode, or takes it as an argument
  (`vendored`/`marketplace`).
