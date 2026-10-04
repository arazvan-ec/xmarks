import type { Register } from 'claude-code'

const SKIP = /\b(SKIP_[A-Z_]+)=(?:"([^"]*)"|'([^']*)'|(\S*))/g
const TRAILER = /Release-Exception:\s*([^"'\n]+)/
const PERMIT = /(allow|baseline)[a-z0-9._-]*\.txt$|^invocation-budget\.txt$/
const NO_PAPERS = new Set(['', '1', 'true', 'yes'])
const KEEP = 200

type Entry = { hatch: string; reason: string; at: number }

async function ledger($: any): Promise<Entry[]> {
  return ((await $.store.get('contraband').catch(() => undefined)) as Entry[] | undefined) ?? []
}

function found(command: string): Entry[] {
  const at = Date.now()
  const out: Entry[] = []
  for (const m of command.matchAll(SKIP)) out.push({ hatch: m[1] ?? 'SKIP_', reason: (m[2] ?? m[3] ?? m[4] ?? '').trim(), at })
  if (/--no-verify\b/.test(command)) out.push({ hatch: '--no-verify', reason: '', at })
  const t = /\bgit\s+commit\b/.test(command) ? TRAILER.exec(command) : null
  if (t) out.push({ hatch: 'Release-Exception', reason: (t[1] ?? '').trim(), at })
  return out
}

function entries(text: string, file: string): number {
  return text.split('\n').filter(l => {
    const s = l.trim()
    return s && !s.startsWith('#') && !(file === 'invocation-budget.txt' && s.startsWith('default'))
  }).length
}

async function audit($: any): Promise<string> {
  const files = ((await $.fs.list('scripts').catch(() => [])) as { name: string; kind: string }[])
    .filter(f => f.kind === 'file' && PERMIT.test(f.name))
    .map(f => f.name)
    .sort()
  const rows: string[] = []
  let total = 0
  for (const f of files) {
    const n = entries(String(await $.fs.read(`scripts/${f}`).catch(() => '')), f)
    total += n
    rows.push(`  ${f}: ${n}`)
  }
  const log = await $.process.run(['git', 'log', '--format=%B']).catch(() => undefined)
  const trailers = log ? log.stdout.split('\n').filter((l: string) => l.startsWith('Release-Exception:')).length : 0
  total += trailers
  return ['Standing permits:', ...(rows.length ? rows : ['  no permit files under scripts/']), `  Release-Exception trailers: ${trailers}`, `Total permits: ${total}`].join('\n')
}

export const register: Register = on => {
  on('session.start', ($, e, next) => {
    $.command.register({ name: 'black-market', description: 'The exception ledger; `audit` totals the standing permits' })
    return next(e)
  })

  on('command.run', { command: 'black-market' }, async ($, e) => {
    if (e.args.trim() === 'audit') return { text: await audit($) }
    const l = await ledger($)
    const rows = l.slice(-20).map(x => `  ${x.hatch.padEnd(20)} ${x.reason || '(no papers)'}`)
    return { text: [`Contraband ledgered: ${l.length}`, ...rows, 'Run /black-market audit for the standing permits.'].join('\n') }
  })

  on('tool.call', { tool: 'Bash' }, async ($, e, next) => {
    const r = await next(e)
    const hits = found(String(e.command ?? ''))
    if (!hits.length || r.deny !== undefined) return r
    const l = [...(await ledger($)), ...hits].slice(-KEEP)
    await $.store.set('contraband', l).catch(() => undefined)
    $.ui.status(`🕶 ${l.length} exception${l.length === 1 ? '' : 's'} on the ledger`)
    const bare = hits.filter(h => NO_PAPERS.has(h.reason.toLowerCase()))
    if (bare.length) $.ui.toast(`Black Market: ${bare.map(h => h.hatch).join(', ')} used without papers — an exception needs its reason.`)
    return r
  })
}
