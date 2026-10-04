import type { Register } from 'claude-code'

const NOTE =
  'Supervisor check: in this reply, name each item closed since the last check with its evidence — ' +
  'a file:line, a command that passes, or a commit — or say plainly that nothing closed. Prose alone is reported unverified.'
const EVIDENCE = /[\w./-]+\.[a-z]+:\d+|`[^`]+`|\b[0-9a-f]{7,40}\b/

let every = 5
let prompts = 0
let supervised = false
let checks = 0
let evidenced = 0

export const register: Register = on => {
  every = 5
  prompts = 0
  supervised = false
  checks = 0
  evidenced = 0

  on('session.start', ($, e, next) => {
    $.command.register({ name: 'supervisor', description: 'Evidence checks: report, or `every <n>` prompts' })
    return next(e)
  })

  on('command.run', { command: 'supervisor' }, ($, e) => {
    const m = /^every\s+(\d+)$/.exec(e.args.trim())
    if (m) {
      every = Math.max(1, Number(m[1]))
      prompts = 0
      return { text: `The Supervisor checks every ${every} prompt${every === 1 ? '' : 's'}.` }
    }
    return { text: `${checks} checks asked; ${evidenced} named evidence. Cadence: every ${every} prompts.` }
  })

  on('prompt.submit', ($, e, next) => {
    if (e.turnId) return next(e)
    prompts += 1
    supervised = prompts % every === 0
    if (!supervised) return next(e)
    checks += 1
    return next({ ...e, context: [...(e.context ?? []), NOTE] })
  })

  on('classic.Stop', async ($, e, next) => {
    const r = await next(e)
    if (!supervised || e.stop_hook_active) return r
    supervised = false
    if (EVIDENCE.test(e.last_assistant_message ?? '')) evidenced += 1
    else $.ui.toast('Supervisor: the check-in named no evidence — no file:line, command or commit. Reported unverified.')
    return r
  })
}
