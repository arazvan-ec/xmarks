import type { Register } from 'claude-code'

const KB = 1024
const DEFAULT = 400 * KB
const FLOOR = 100 * KB
const WINDOW = 10
const MIN_HISTORY = 5
const HELD = new Set(['Read', 'Grep', 'Glob', 'WebFetch', 'WebSearch'])

let used = 0
let ration: number | undefined
let warned = false

const kb = (n: number) => `${Math.round(n / KB)} KB`

async function history($: any): Promise<number[]> {
  return ((await $.store.get('totals').catch(() => undefined)) as number[] | undefined) ?? []
}

async function book($: any): Promise<number> {
  if (ration !== undefined) return ration
  const h = (await history($)).slice(-WINDOW)
  if (h.length < MIN_HISTORY) return (ration = DEFAULT)
  const s = [...h].sort((a, b) => a - b)
  return (ration = Math.max(FLOOR, s[Math.ceil(0.75 * s.length) - 1] ?? DEFAULT))
}

async function show($: any) {
  const r = await book($)
  const left = Math.max(0, Math.round(100 - (used / r) * 100))
  $.ui.status(`🎫 ${left}% coupons left (${kb(used)} of ${kb(r)})`)
  if (!warned && used >= 0.8 * r) {
    warned = true
    $.ui.toast(`Ration Book: 80% of this session's read coupons are spent (${kb(used)} of ${kb(r)}).`)
  }
}

export const register: Register = on => {
  used = 0
  ration = undefined
  warned = false

  on('session.start', ($, e, next) => {
    $.command.register({ name: 'ration', description: 'This session’s read ration; `grant <KB>` adds coupons' })
    return next(e)
  })

  on('command.run', { command: 'ration' }, async ($, e) => {
    const r = await book($)
    const m = /^grant\s+(\d+)$/.exec(e.args.trim())
    if (m) {
      ration = r + Number(m[1]) * KB
      $.ui.toast(`Ration Book: ${m[1]} KB of extra coupons granted by hand.`)
      await show($)
      return { text: `Ration now ${kb(ration)}.` }
    }
    return { text: `Ration ${kb(r)}; spent ${kb(used)}. Reads are held at 100% until /ration grant <KB>.` }
  })

  on('tool.call', async ($, e, next) => {
    if (HELD.has(e.tool) && used >= (await book($))) {
      return { deny: `${$.plugin.name}: this session's read ration (${kb(await book($))}) is spent. Ask the owner for /ration grant <KB>, or work from what is already in context.` }
    }
    const r = await next(e)
    if (r.deny === undefined) {
      used += (r.text ?? '').length
      await show($)
    }
    return r
  })

  on('session.end', async ($, e, next) => {
    await $.store.set('totals', [...(await history($)), used].slice(-50)).catch(() => undefined)
    return next(e)
  })
}
