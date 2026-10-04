import type { Register } from 'claude-code'

const PANE = 'expediente'
const RUNS = '.claude/flywheel/runs'

type Line = { task?: string; phase?: string; state?: string; route?: string; route_escalated_from?: string; cost?: { bytes_in?: number } }
type Entry = { name: string; kind: string; mtimeMs: number }
type File = { slug: string; lines: Line[] }

let chosen: string | undefined

const kb = (n: number) => `${(n / 1024).toFixed(1)} KB`

async function cycles($: any): Promise<string[]> {
  const all = ((await $.fs.list(RUNS).catch(() => [])) as Entry[]).filter(e => e.kind === 'dir')
  return all.sort((a, b) => b.mtimeMs - a.mtimeMs).map(e => e.name)
}

async function load($: any, slug?: string): Promise<File | undefined> {
  const s = slug ?? chosen ?? (await cycles($))[0]
  if (!s) return undefined
  const files = ((await $.fs.list(`${RUNS}/${s}`).catch(() => [])) as Entry[])
    .filter(e => e.kind === 'file' && e.name.endsWith('.jsonl'))
    .map(e => e.name)
    .sort()
  const lines: Line[] = []
  for (const f of files) {
    for (const raw of String(await $.fs.read(`${RUNS}/${s}/${f}`).catch(() => '')).split('\n')) {
      try {
        if (raw.trim()) lines.push(JSON.parse(raw) as Line)
      } catch {}
    }
  }
  return { slug: s, lines }
}

function row(l: Line): string {
  const up = l.route_escalated_from ? `  ↑ from ${l.route_escalated_from}` : ''
  return `${(l.task ?? '?').padEnd(6)} ${(l.phase ?? '').padEnd(8)} ${(l.state ?? '').padEnd(10)} ${l.route ?? ''}${up}`
}

function totals(f: File): string {
  const bytes = f.lines.reduce((n, l) => n + (l.cost?.bytes_in ?? 0), 0)
  const esc = f.lines.filter(l => l.route_escalated_from).length
  return `${f.lines.length} transitions · ${kb(bytes)} in · ${esc} escalation${esc === 1 ? '' : 's'}`
}

function text(f: File | undefined): string {
  if (!f) return `No run record under ${RUNS}.`
  return [`Expediente: ${f.slug}`, ...f.lines.map(row), totals(f)].join('\n')
}

export const register: Register = on => {
  chosen = undefined

  on('session.start', ($, e, next) => {
    $.command.register({ name: 'expediente', description: 'Open a flywheel cycle’s run record: [slug] | list | status' })
    return next(e)
  })

  on('command.run', { command: 'expediente' }, async ($, e) => {
    const arg = e.args.trim()
    if (arg === 'list') return { text: (await cycles($)).join('\n') || `No run record under ${RUNS}.` }
    if (arg === 'status') return { text: text(await load($)) }
    if (arg) {
      if (!(await cycles($)).includes(arg)) return { text: `No run record for '${arg}'. /expediente list names them.` }
      chosen = arg
    }
    void $.ui.open({ id: PANE, title: 'Expediente' })
    return { text: `File opened: ${chosen ?? 'newest cycle'}.` }
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text } = $.ui.resolve(e)
    const f = await load($)
    if (!f) return <Text dimColor>No run record under {RUNS}.</Text>
    const room = Math.max(1, (e.viewport?.rows ?? 24) - 4)
    return (
      <Box flexDirection="column">
        <Text bold>{f.slug}</Text>
        {f.lines.slice(-room).map(l => (
          <Text color={l.route_escalated_from ? 'yellow' : undefined}>{row(l)}</Text>
        ))}
        <Text dimColor>{totals(f)}</Text>
      </Box>
    )
  })
}
