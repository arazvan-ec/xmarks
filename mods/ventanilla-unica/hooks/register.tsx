import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import type { Stamp, Window } from '../types'

const PANE = 'ventanilla'
const EMPTY: Window = { stamps: [], running: false }
const win = atom({ plugin: 'ventanilla-unica', key: 'window' } as const, EMPTY)
const LINE = /^(PASS|FAIL|SKIPPED) (.+)$/
const TOTAL = /^(\d+\/\d+ passed)$/
const SWEEP = /(^|\s|\/)scripts\/sweep\.sh(\s|$)/

function parse(text: string, w: Window): Window {
  let { stamps, total } = w
  for (const raw of text.split('\n')) {
    const line = raw.trim()
    const m = LINE.exec(line)
    if (m) stamps = [...stamps, { verdict: m[1] as Stamp['verdict'], gate: m[2] ?? '' }]
    const t = TOTAL.exec(line)
    if (t) total = t[1]
  }
  return { ...w, stamps, total }
}

function glyph(s: Stamp): string {
  return s.verdict === 'PASS' ? '✔' : s.verdict === 'FAIL' ? '✘' : '·'
}

function report(w: Window): string {
  if (!w.stamps.length) return w.running ? 'The window is open; no stamps yet.' : 'No sweep has come through the window.'
  const rows = w.stamps.map(s => `${glyph(s)} ${s.gate}`)
  return [...rows, w.total ?? (w.running ? '…' : '')].join('\n')
}

async function verdict($: any) {
  const w = await read($, win)
  const missing = w.stamps.filter(s => s.verdict === 'FAIL').map(s => s.gate)
  $.ui.toast(
    missing.length
      ? `Missing stamp: ${missing.join(', ')}. Vuelva usted mañana.`
      : `Sellado: ${w.total ?? `${w.stamps.length} stamps`}.`,
  )
}

async function sweep($: any, base: string) {
  await update($, win, () => ({ ...EMPTY, running: true }))
  let rest = ''
  try {
    for await (const { text } of $.process.spawn({ argv: base ? ['bash', 'scripts/sweep.sh', base] : ['bash', 'scripts/sweep.sh'] })) {
      const lines = (rest + text).split('\n')
      rest = lines.pop() ?? ''
      if (lines.length) await update($, win, w => parse(lines.join('\n'), w))
    }
    if (rest) await update($, win, w => parse(rest, w))
  } finally {
    await update($, win, w => ({ ...w, running: false }))
  }
  await verdict($)
}

export const register: Register = on => {
  on('session.start', ($, e, next) => {
    $.command.register({ name: 'ventanilla', description: 'Run the sweep at the single window and stamp each gate: [base] | status' })
    return next(e)
  })

  on('command.run', { command: 'ventanilla' }, async ($, e) => {
    const arg = e.args.trim()
    if (arg === 'status') return { text: report(await read($, win)) }
    if ((await read($, win)).running) return { text: 'A sweep is already at the window.' }
    void $.ui.open({ id: PANE, title: 'Ventanilla Única' })
    void sweep($, arg).catch(err => $.ui.toast(`The window closed: ${String(err)}`))
    return { text: 'Sweep submitted to the single window.' }
  })

  on('tool.call', { tool: 'Bash' }, async ($, e, next) => {
    const r = await next(e)
    if (r.deny === undefined && SWEEP.test(e.command)) {
      await update($, win, () => parse(r.text ?? '', EMPTY))
      await verdict($)
    }
    return r
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text } = $.ui.resolve(e)
    const w = await read($, win)
    const room = Math.max(1, (e.viewport?.rows ?? 24) - 3)
    return (
      <Box flexDirection="column">
        {w.stamps.length === 0 && <Text dimColor>{w.running ? 'Waiting for the first stamp…' : 'No sweep yet. /ventanilla'}</Text>}
        {w.stamps.slice(-room).map(s => (
          <Text color={s.verdict === 'FAIL' ? 'red' : undefined} dimColor={s.verdict === 'SKIPPED'}>
            {glyph(s)} {s.gate}
          </Text>
        ))}
        {w.total && <Text bold>{w.total}</Text>}
      </Box>
    )
  })
}
