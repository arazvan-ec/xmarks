import type { Register } from 'claude-code'

const BIG = 8 * 1024
const KEEP = 50

type Tally = { bytes: number; calls: number }
let byTool: Record<string, Tally> = {}
let bytesIn = 0
let largest = { bytes: 0, what: '' }
let rewrites: string[] = []
let read = new Set<string>()

const kb = (n: number) => `${(n / 1024).toFixed(1)} KB`

function target(e: any): string {
  return e.file_path ?? e.path ?? e.pattern ?? (typeof e.command === 'string' ? e.command.slice(0, 40) : '')
}

async function show($: any) {
  const u = await $.session.usage({}).catch(() => undefined)
  const cost = u?.cost ? ` · $${u.cost.usd.toFixed(2)}` : ''
  const ctx = u?.context?.percent !== undefined ? ` · ctx ${Math.round(u.context.percent)}%` : ''
  $.ui.status(`👁 ${kb(bytesIn)} read${cost}${ctx}`)
}

function dossier(): string {
  const rows = Object.entries(byTool)
    .sort((a, b) => b[1].bytes - a[1].bytes)
    .map(([t, v]) => `  ${t.padEnd(10)} ${kb(v.bytes).padStart(9)}  ${v.calls} call${v.calls === 1 ? '' : 's'}`)
  return [
    `The Ministry has recorded ${kb(bytesIn)} read this session.`,
    ...rows,
    largest.bytes ? `Largest single read: ${kb(largest.bytes)} — ${largest.what}` : 'No reads yet.',
    rewrites.length ? `Full rewrites of files already read: ${rewrites.join(', ')}` : 'No full rewrites.',
  ].join('\n')
}

export const register: Register = on => {
  byTool = {}
  bytesIn = 0
  largest = { bytes: 0, what: '' }
  rewrites = []
  read = new Set()

  on('session.start', ($, e, next) => {
    $.command.register({ name: 'ministry', description: 'The Ministry’s dossier: bytes read by tool, largest read, rewrites' })
    return next(e)
  })

  on('command.run', { command: 'ministry' }, () => ({ text: dossier() }))

  on('tool.call', async ($, e, next) => {
    const r = await next(e)
    if (r.deny !== undefined) return r
    const a: any = e
    const path = target(a)
    if (e.tool === 'Write' && read.has(path)) {
      rewrites.push(path)
      $.ui.toast(`The Ministry notes a full rewrite of ${path}. Edit, citizen — change the lines that change.`)
    }
    if (e.tool === 'Read') read.add(path)
    const n = (r.text ?? '').length
    const t = (byTool[e.tool] ??= { bytes: 0, calls: 0 })
    t.bytes += n
    t.calls += 1
    bytesIn += n
    if (n > largest.bytes) largest = { bytes: n, what: `${e.tool} ${path}` }
    if (n > BIG) $.ui.toast(`The Ministry has recorded a ${kb(n)} read (${e.tool} ${path}). A targeted read would do.`)
    await show($)
    return r
  })

  on('session.end', async ($, e, next) => {
    const prev = ((await $.store.get('sessions').catch(() => undefined)) as unknown[] | undefined) ?? []
    const summary = { at: Date.now(), bytesIn, byTool, largest, rewrites: rewrites.length }
    await $.store.set('sessions', [...prev, summary].slice(-KEEP)).catch(() => undefined)
    return next(e)
  })
}
