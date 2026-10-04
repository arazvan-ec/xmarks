import type { Register } from 'claude-code'

const CHECK = /\b(test|tests|check|sweep|pytest|jest|vitest)\b|\bgo test\b|\bcargo test\b|\b(npm|pnpm|yarn)( run)? test\b|\bmake test\b/
const HELD = new Set(['Edit', 'Write', 'NotebookEdit'])
const LIMIT = 3
const NOTE =
  'General Strike: the same check has failed three times with edits in between and no green. Stop guessing. ' +
  'Run /flywheel:debug — reproduce, isolate, form one hypothesis and test it — before editing again.'

type Track = { fails: number; edited: boolean }
let tracks = new Map<string, Track>()
let strike: string | undefined

function end($: any, why: string) {
  if (!strike) return
  strike = undefined
  $.ui.status(undefined)
  $.ui.toast(`General Strike ended: ${why}.`)
}

export const register: Register = on => {
  tracks = new Map()
  strike = undefined

  on('session.start', ($, e, next) => {
    $.command.register({ name: 'strike', description: 'General Strike status; `end` lifts it (logged)' })
    return next(e)
  })

  on('command.run', { command: 'strike' }, $ => {
    if (!strike) return { text: 'No strike. Work continues.' }
    end($, 'called off by hand')
    return { text: 'Strike ended.' }
  })

  on('prompt.submit', ($, e, next) => (strike && !e.turnId ? next({ ...e, context: [...(e.context ?? []), NOTE] }) : next(e)))

  on('tool.call', async ($, e, next) => {
    if (strike && HELD.has(e.tool)) {
      return { deny: `${$.plugin.name}: on strike after three reds of \`${strike}\`. Diagnose with Read/Grep/Bash or /flywheel:debug; edits resume when it passes or /strike end.` }
    }
    const r = await next(e)
    if (r.deny !== undefined) return r
    const a: any = e
    if (HELD.has(e.tool)) for (const t of tracks.values()) t.edited = true
    if (e.tool === 'Skill' && /debug/.test(String(a.skill ?? ''))) end($, 'systematic debugging opened')
    const cmd = e.tool === 'Bash' ? String(a.command ?? '').trim().replace(/\s+/g, ' ') : ''
    if (!cmd || !CHECK.test(cmd)) return r
    const t = tracks.get(cmd) ?? { fails: 0, edited: true }
    if (r.isError) {
      if (t.fails === 0 || t.edited) t.fails += 1
      t.edited = false
      tracks.set(cmd, t)
      if (t.fails >= LIMIT && !strike) {
        strike = cmd
        $.ui.status('✊ on strike — debug before editing')
        $.ui.toast(`General Strike: \`${cmd}\` failed ${t.fails} times with edits between and no green. The workers are on strike: edits stop until it is debugged.`)
      }
    } else {
      tracks.delete(cmd)
      if (strike === cmd) end($, `${cmd} passed`)
    }
    return r
  })
}
