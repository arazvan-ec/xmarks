import { test, expect } from 'claude-code/testing'

const FILES: Record<string, string> = {
  'scripts/telemetry-baseline.txt': '# header\n\np1 exempt: predates\np2 exempt: predates\n',
  'scripts/fixture-leak-allow.txt': '# c\nx.md: ok\n',
  'scripts/invocation-budget.txt': '# c\ndefault body 4800\ndefault worst 9200\nwork body=5700\nrun worst=11000\n',
  'scripts/sweep.sh': 'not a permit file\n',
}

function world(on: any, log = 'msg\n\nRelease-Exception: docs only\n---\nother\n') {
  const w = { status: [] as string[], toasts: [] as string[], store: new Map<string, unknown>() }
  on('ui.status', (_$: any, e: any) => { w.status.push(String(e.text ?? e)); return { value: undefined } })
  on('ui.toast', (_$: any, e: any) => { w.toasts.push(String(e.text ?? e)); return { value: undefined } })
  on('store.get', (_$: any, e: any) => ({ value: w.store.get(e.key) }))
  on('store.set', (_$: any, e: any) => { w.store.set(e.key, e.value); return { value: undefined } })
  on('tool.call', () => ({ result: 'ok', text: 'ok' }))
  on('fs.list', () => ({ value: Object.keys(FILES).map(p => ({ name: p.split('/')[1], kind: 'file', size: 1, mtimeMs: 0 })) }))
  on('fs.read', (_$: any, e: any) => ({ value: Object.entries(FILES).find(([k]) => String(e.path).endsWith(k))?.[1] ?? '' }))
  on('process.run', () => ({ value: { exitCode: 0, stdout: log, stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }))
  return w
}
const bash = ($: any, command: string) => $.tool.call({ tool: 'Bash', command })
const cmd = ($: any, args = '') =>
  $.command.run({ command: 'black-market', args, origin: { kind: 'composer' }, presentation: { layout: 'main', columns: 80 } } as any)
const ledger = (w: any) => w.store.get('contraband') as any[]

test('a SKIP with a reason is ledgered, quietly', async ($, on) => {
  const w = world(on)
  await bash($, 'SKIP_TEST_PAIRING="docs-only rename" git push')
  expect(ledger(w)[0]).toMatchObject({ hatch: 'SKIP_TEST_PAIRING', reason: 'docs-only rename' })
  expect(w.toasts.length).toBe(0)
  expect(w.status.at(-1)).toContain('1')
})

test('a SKIP with 1 has no papers', async ($, on) => {
  const w = world(on)
  await bash($, 'SKIP_RELEASE_BUMP=1 bash scripts/check-release-bump.sh')
  expect(ledger(w)[0].reason).toBe('1')
  expect(w.toasts.join()).toContain('papers')
})

test('--no-verify has no papers by construction', async ($, on) => {
  const w = world(on)
  await bash($, 'git commit --no-verify -m x')
  expect(ledger(w)[0].hatch).toBe('--no-verify')
  expect(w.toasts.length).toBe(1)
})

test('a Release-Exception trailer in a commit is ledgered with its reason', async ($, on) => {
  const w = world(on)
  await bash($, 'git commit -m "x\n\nRelease-Exception: prose-only skill edit"')
  expect(ledger(w)[0]).toMatchObject({ hatch: 'Release-Exception', reason: 'prose-only skill edit' })
})

test('ordinary commands are not contraband', async ($, on) => {
  const w = world(on)
  await bash($, 'git status')
  expect(ledger(w)).toBeUndefined()
})

test('the audit totals standing permits and trailers', async ($, on) => {
  world(on)
  const r: any = await cmd($, 'audit')
  expect(r.text).toContain('telemetry-baseline.txt: 2')
  expect(r.text).toContain('fixture-leak-allow.txt: 1')
  expect(r.text).toContain('invocation-budget.txt: 2')
  expect(r.text).not.toContain('sweep.sh')
  expect(r.text).toContain('Release-Exception trailers: 1')
  expect(r.text).toContain('Total permits: 6')
})

test('the ledger persists and /black-market shows it', async ($, on) => {
  const w = world(on)
  w.store.set('contraband', [{ hatch: 'SKIP_X', reason: 'old', at: 0 }])
  await bash($, 'SKIP_Y=why git push')
  expect(ledger(w).length).toBe(2)
  const r: any = await cmd($)
  expect(r.text).toContain('SKIP_Y')
  expect(r.text).toContain('old')
})
