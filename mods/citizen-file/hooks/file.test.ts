import { test, expect } from 'claude-code/testing'

const RUNS = '.claude/flywheel/runs'
const DIRS = [
  { name: 'p1-old', mtimeMs: 100 },
  { name: 'p2-new', mtimeMs: 300 },
  { name: 'p3-mid', mtimeMs: 200 },
]
const L = (o: object) => JSON.stringify(o)
const FILES: Record<string, Record<string, string>> = {
  'p2-new': {
    '2026-10-04.jsonl': [
      L({ task: 'spec', phase: 'spec', state: 'completed', route: 'opus/high', cost: { bytes_in: 1000 } }),
      L({ task: 'T1', phase: 'work', state: 'completed', route: 'opus/high', route_escalated_from: 'sonnet/medium', cost: { bytes_in: 3000 } }),
      'not json',
    ].join('\n') + '\n',
  },
  'p1-old': { '2026-09-01.jsonl': L({ task: 'T1', phase: 'work', state: 'completed', route: 'haiku/low', cost: { bytes_in: 10 } }) + '\n' },
  'p3-mid': {},
}

function world(on: any) {
  on('ui.open', () => ({ value: undefined }))
  on('fs.list', (_$: any, e: any) => {
    const p = String(e.path)
    if (p.endsWith(RUNS)) return { value: DIRS.map(d => ({ ...d, kind: 'dir', size: 0 })) }
    const slug = p.split('/').pop() ?? ''
    return { value: Object.keys(FILES[slug] ?? {}).map(name => ({ name, kind: 'file', size: 1, mtimeMs: 0 })) }
  })
  on('fs.read', (_$: any, e: any) => {
    const [slug, file] = String(e.path).split('/').slice(-2)
    return { value: FILES[slug ?? '']?.[file ?? ''] ?? '' }
  })
}
const cmd = ($: any, args = '') =>
  $.command.run({ command: 'expediente', args, origin: { kind: 'composer' }, presentation: { layout: 'main', columns: 160 } } as any)

test('status opens the newest cycle with rows and totals', async ($, on) => {
  world(on)
  const r: any = await cmd($, 'status')
  expect(r.text).toContain('p2-new')
  expect(r.text).toContain('T1')
  expect(r.text).toContain('↑ from sonnet/medium')
  expect(r.text).toContain('2 transitions')
  expect(r.text).toContain('3.9 KB')
  expect(r.text).toContain('1 escalation')
})

test('a named cycle is opened', async ($, on) => {
  world(on)
  await cmd($, 'p1-old')
  const r: any = await cmd($, 'status')
  expect(r.text).toContain('p1-old')
  expect(r.text).toContain('haiku/low')
})

test('list names cycles newest first', async ($, on) => {
  world(on)
  const r: any = await cmd($, 'list')
  const t = String(r.text)
  expect(t.indexOf('p2-new')).toBeLessThan(t.indexOf('p3-mid'))
  expect(t.indexOf('p3-mid')).toBeLessThan(t.indexOf('p1-old'))
})

test('an unknown cycle is refused', async ($, on) => {
  world(on)
  const r: any = await cmd($, 'nope')
  expect(r.text).toContain('No run record')
})

for (const surface of ['terminal', 'desktop'] as const) {
  test(`the pane draws the file on ${surface}`, async ($, on) => {
    world(on)
    const ui: any = await $.ui.mount({ plugin: 'citizen-file', surface, component: 'Pane', props: {} as any, requestId: 'expediente' } as any)
    expect(await ui.find({ text: /p2-new/ })).toBeTruthy()
    expect(await ui.find({ text: /sonnet\/medium/ })).toBeTruthy()
  })
}
