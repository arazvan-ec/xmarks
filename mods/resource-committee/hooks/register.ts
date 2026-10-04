import type { Register } from 'claude-code'

type Route = { model: string; effort?: 'low' | 'medium' | 'high'; why: string }

const SONNET = 'claude-sonnet-5-5'
const OPUS = 'claude-opus-5-5'
const ROUTINE: Route = { model: SONNET, effort: 'medium', why: 'routine' }
const TIERS: Record<string, Route> = {
  mechanical: { model: SONNET, effort: 'low', why: 'mechanical' },
  routine: ROUTINE,
  judgment: { model: OPUS, effort: 'high', why: 'judgment' },
}
const PINS: Record<string, Route> = {
  haiku: { model: 'claude-haiku-4-5', why: 'pinned' },
  sonnet: { model: SONNET, effort: 'medium', why: 'pinned' },
  opus: { model: OPUS, effort: 'high', why: 'pinned' },
}
const LABELS = Object.keys(TIERS)
const SYSTEM =
  'Classify the coding request. Answer with one word: mechanical, routine or judgment. ' +
  'mechanical: rename, move, format, run a command and report. routine: everyday coding with a clear goal. ' +
  'judgment: design, specs, architecture, hard debugging, security, or an ambiguous goal.'

const label = (r: Route) => `${r.model.replace(/^claude-|-\d.*$/g, '')}/${r.effort ?? '—'}`

let route: Route = ROUTINE
let pin: Route | undefined
let tally: Record<string, number> = {}
let switches = 0

type Session = { at?: number; tally: Record<string, number>; switches: number }

async function stats($: any): Promise<string> {
  const all = ((await $.store.get('sessions').catch(() => undefined)) as Session[] | undefined) ?? []
  const sum: Record<string, number> = {}
  let sw = 0
  for (const x of all) {
    for (const [k, v] of Object.entries(x.tally)) sum[k] = (sum[k] ?? 0) + v
    sw += x.switches
  }
  const rows = Object.entries(sum).sort((a, b) => b[1] - a[1]).map(([k, v]) => `${k} ${v}`).join(' · ')
  return `${all.length} sessions: ${rows || 'no decisions yet'} · ${sw} switches`
}

function show($: any, changed: boolean) {
  const r = pin ?? route
  $.ui.status(`🏛 ${label(r)} · ${r.why}`)
  if (changed) $.ui.toast(`The Committee reassigns resources: ${label(r)} (${r.why})`)
}

export const register: Register = on => {
  route = ROUTINE
  pin = undefined
  tally = {}
  switches = 0

  on('session.start', ($, e, next) => {
    $.command.register({ name: 'committee', description: 'Show the Committee’s model/effort decision; pin: haiku | sonnet | opus | auto; stats' })
    show($, false)
    return next(e)
  })

  on('command.run', { command: 'committee' }, async ($, e) => {
    const arg = e.args.trim().toLowerCase()
    if (arg === 'stats') return { text: await stats($) }
    if (arg === 'auto') pin = undefined
    else if (PINS[arg]) pin = PINS[arg]
    else if (arg) return { text: `Unknown tier '${arg}'. Use haiku | sonnet | opus | auto.` }
    show($, Boolean(arg))
    const r = pin ?? route
    return { text: `${label(r)} — ${pin ? 'pinned' : `auto (${r.why})`}` }
  })

  on('prompt.submit', async ($, e, next) => {
    if (!e.turnId && !pin && !e.text.trimStart().startsWith('/')) {
      const r = await $.model.complete({ model: 'haiku', system: SYSTEM, prompt: e.text.slice(0, 4000), maxTokens: 5 }).catch(() => undefined)
      const word = r?.isAnswered ? r.text.trim().toLowerCase().replace(/[^a-z]/g, '') : ''
      const next_ = LABELS.includes(word) ? TIERS[word] : undefined
      if (next_) tally[word] = (tally[word] ?? 0) + 1
      if (next_ && next_ !== route) {
        route = next_
        switches += 1
        show($, true)
      }
    }
    return next(e)
  })

  on('session.end', async ($, e, next) => {
    const prev = ((await $.store.get('sessions').catch(() => undefined)) as Session[] | undefined) ?? []
    await $.store.set('sessions', [...prev, { at: Date.now(), tally, switches }].slice(-50)).catch(() => undefined)
    return next(e)
  })

  on('turn.step', async function* ($, e, next) {
    if (e.agentId) return yield* next(e)
    const r = pin ?? route
    return yield* next({ ...e, model: r.model, effort: r.effort })
  })
}
