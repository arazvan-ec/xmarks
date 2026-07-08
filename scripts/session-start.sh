#!/usr/bin/env bash
# flywheel — SessionStart hook.
# Contract: READ-ONLY and idempotent. It never mutates the working tree.
# Everything printed to stdout is injected into Claude's session context.
# It always exits 0 so a missing/malformed ledger can never block a session.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LEDGER="${PROJECT_DIR}/.claude/flywheel/LEARNINGS.md"
INJECT_N="${FLYWHEEL_LEARNINGS_INJECT:-12}"

echo "🎡 flywheel loaded — a nested loop for disciplined AI development."
echo "   Full cycle:  /flywheel:loop <feature>"
echo "   Phases:      brainstorm → spec → plan → work → verify → review → compound → ship"
echo "   Anytime:     /flywheel:debug (systematic) · /flywheel:autoloop (autonomous) · /flywheel:sync (spec↔code)"
echo ""

# Soft new-version notice for VENDORED installs only (the VERSION file exists
# only in repos vendored by install-vendored.sh; marketplace installs update
# via /plugin update). Fail-silent and bounded to 2s so it can never slow down
# or break session start. Opt out with FLYWHEEL_NO_UPDATE_CHECK=1.
VERSION_FILE="${PROJECT_DIR}/.claude/flywheel/VERSION"
if [ -f "${VERSION_FILE}" ] && [ -z "${FLYWHEEL_NO_UPDATE_CHECK:-}" ] && command -v curl >/dev/null 2>&1; then
  LOCAL_V="$(sed -n 's/^flywheel //p' "${VERSION_FILE}" 2>/dev/null | head -1)"
  REMOTE_V="$(curl -m 2 -fsSL https://raw.githubusercontent.com/arazvan-ec/xmarks/main/.claude-plugin/plugin.json 2>/dev/null \
    | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
  if [ -n "${LOCAL_V}" ] && [ -n "${REMOTE_V}" ] && [ "${LOCAL_V}" != "${REMOTE_V}" ]; then
    echo "⬆️  flywheel ${REMOTE_V} is available (this repo carries ${LOCAL_V}) — run /flywheel:update to refresh."
    echo ""
  fi
fi

if [ ! -f "${LEDGER}" ]; then
  echo "📓 No flywheel learnings yet. /flywheel:compound will create"
  echo "   .claude/flywheel/LEARNINGS.md at the end of your first cycle."
  exit 0
fi

# --- Relevance pass -----------------------------------------------------
# Score each ledger entry against the current git context (branch / changed
# files / active spec / recency) and inject only the top-N full entries, plus
# a one-line pointer to the rest. Never fails the hook: any error here falls
# back to a plain dump of the ledger head.

relevance_injection() {
  BRANCH="$(git -C "${PROJECT_DIR}" branch --show-current 2>/dev/null || true)"
  CHANGED_FILES="$( {
      git -C "${PROJECT_DIR}" diff --name-only 2>/dev/null
      git -C "${PROJECT_DIR}" diff --name-only --cached 2>/dev/null
      git -C "${PROJECT_DIR}" diff --name-only origin/HEAD...HEAD 2>/dev/null
    } | sort -u | tr '\n' '\x1f')"
  SPEC_SLUG="$(ls -t "${PROJECT_DIR}/.claude/flywheel/specs/"*.md 2>/dev/null \
    | head -1 | xargs -n1 basename 2>/dev/null | sed 's/\.md$//')"
  RECENT_SINCE="$(date -d '-30 days' +%F 2>/dev/null || date -v-30d +%F 2>/dev/null || true)"

  WORKDIR="$(mktemp -d 2>/dev/null)" || return 1
  trap 'rm -rf "${WORKDIR}"' RETURN
  BLOCKS="${WORKDIR}/blocks"
  SEP=$'\x02\x02FW\x02\x02'

  SCORES="$(awk -v changed="${CHANGED_FILES}" -v branch="${BRANCH}" -v spec="${SPEC_SLUG}" \
      -v recent_since="${RECENT_SINCE}" -v SEP="${SEP}" -v blockfile="${BLOCKS}" '
    function flush(   n, i, j, nf, nc, fs, cs, matched) {
      if (title == "") return
      idx++
      score = 0
      if (meta_files != "" && changed != "") {
        nf = split(meta_files, fs, ",")
        nc = split(changed, cs, "\x1f")
        matched = 0
        for (i = 1; i <= nf && !matched; i++) {
          gsub(/^[ \t]+|[ \t]+$/, "", fs[i])
          for (j = 1; j <= nc; j++) {
            if (fs[i] != "" && fs[i] == cs[j]) { matched = 1; break }
          }
        }
        if (matched) score += 3
      }
      if (meta_branch != "" && branch != "" && meta_branch == branch) score += 2
      if (meta_spec != "" && spec != "" && meta_spec == spec) score += 2
      if (meta_date != "" && recent_since != "" && meta_date >= recent_since) score += 1
      print score "\t" (meta_date == "" ? "0000-00-00" : meta_date) "\t" idx
      printf "%s", block >> blockfile
      printf "%s", SEP >> blockfile
      title = ""; meta_files = ""; meta_branch = ""; meta_spec = ""; meta_date = ""; block = ""
    }
    BEGIN { idx = 0 }
    /^## / {
      flush()
      title = $0
      block = $0 "\n"
      next
    }
    title != "" && /^<!-- fw:/ {
      block = block $0 "\n"
      line = $0
      gsub(/^<!--[ \t]*fw:[ \t]*/, "", line)
      gsub(/[ \t]*-->[ \t]*$/, "", line)
      n = split(line, kvs, ";")
      for (i = 1; i <= n; i++) {
        kv = kvs[i]
        gsub(/^[ \t]+|[ \t]+$/, "", kv)
        eq = index(kv, "=")
        if (eq == 0) continue
        key = substr(kv, 1, eq - 1)
        val = substr(kv, eq + 1)
        if (key == "date") meta_date = val
        else if (key == "files") meta_files = val
        else if (key == "spec") meta_spec = val
        else if (key == "branch") meta_branch = val
      }
      next
    }
    title != "" { block = block $0 "\n"; next }
    END { flush() }
  ' "${LEDGER}")"

  TOTAL="$(printf '%s\n' "${SCORES}" | grep -c . || true)"
  [ "${TOTAL}" -gt 0 ] || return 1

  WANTED="$(printf '%s\n' "${SCORES}" \
    | sort -t "$(printf '\t')" -k1,1nr -k3,3n \
    | head -n "${INJECT_N}" \
    | cut -f3 | sort -n | tr '\n' ' ')"

  echo "📓 Relevant flywheel learnings (branch/files/recency-scored, from .claude/flywheel/LEARNINGS.md):"
  echo "------------------------------------------------------------------------------"
  awk -v RS="${SEP}" -v want="${WANTED}" '
    BEGIN { n = split(want, w, " "); for (i = 1; i <= n; i++) sel[w[i]] = 1 }
    (NR in sel) && NF { print }
  ' "${BLOCKS}"
  echo "------------------------------------------------------------------------------"
  REMAINING=$((TOTAL - INJECT_N))
  if [ "${REMAINING}" -gt 0 ]; then
    echo "… ${REMAINING} more learnings — run /flywheel:recall <query> to pull specifics."
  fi
  echo "(Use these to avoid repeating past gotchas. /flywheel:compound appends new ones.)"
  return 0
}

if ! relevance_injection 2>/dev/null; then
  echo "📓 Recent flywheel learnings (newest first, from .claude/flywheel/LEARNINGS.md):"
  echo "------------------------------------------------------------------------------"
  head -n 50 "${LEDGER}" 2>/dev/null
  echo "------------------------------------------------------------------------------"
  echo "(Use these to avoid repeating past gotchas. /flywheel:compound appends new ones.)"
fi

exit 0
