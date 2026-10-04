import { test, expect } from 'claude-code/testing'

function world(on: any) {
  const w = { status: [] as string[], toasts: [] as string[], store: new Map<string, unknown>() }
  on('ui.status', (_$: any, e: any) => { w.status.push(e.text ?? e); return { value: undefined } })
  on('ui.toast', (_$: any, e: any) => { w.toasts.push(e.text ?? e); return { value: undefined } })
  on('session.usage', () => ({ value: { startedAt: 0, context: { tokens: 50_000, window: 200_000, percent: 25 }, rateLimits: [], cost: { usd: 1.25 } } }))
  on('store.get', (_$: any, e: any) => ({ value: w.store.get(e.key) }))
  on('store.set', (_$: any, e: any) => { w.store.set(e.key, e.value); return { value: undefined } })
  on('tool.call', (_$: any, e: any) => ({ result: 'ok', text: 'x'.repeat(e.size ?? 100) }))
  on('session.end', () => ({ sessionId: 's' }))
  return w
}
const run = ($: any, tool: string, size: number, extra: object = {}) => $.tool.call({ tool, size, ...extra })
const cmd = ($: any, command: string) =>
  $.command.run({ command, args: '', origin: { kind: 'composer' }, presentation: { layout: 'main', columns: 80 } })

test('the status line carries bytes read, cost and context', async ($, on) => {
  const w = world(on)
  await run($, 'Read', 2048, { file_path: 'a.ts' })
  await run($, 'Bash', 1024, { command: 'ls' })
  const last = String(w.status.at(-1))
  expect(last).toContain('3.0 KB')
  expect(last).toContain('$1.25')
  expect(last).toContain('25%')
})

test('one result over 8 KB is reported', async ($, on) => {
  const w = world(on)
  await run($, 'Read', 9000, { file_path: 'big.ts' })
  expect(w.toasts.join()).toContain('8.8 KB')
  await run($, 'Read', 500, { file_path: 'small.ts' })
  expect(w.toasts.length).toBe(1)
})

test('a Write over a file already read is a rewrite', async ($, on) => {
  const w = world(on)
  await run($, 'Read', 100, { file_path: 'a.ts' })
  await run($, 'Write', 10, { file_path: 'b.ts', content: 'new' })
  expect(w.toasts.length).toBe(0)
  await run($, 'Write', 10, { file_path: 'a.ts', content: 'all of it again' })
  expect(w.toasts.join()).toContain('a.ts')
})

test('/ministry reports by tool and the largest read', async ($, on) => {
  world(on)
  await run($, 'Read', 3000, { file_path: 'a.ts' })
  await run($, 'Read', 1000, { file_path: 'b.ts' })
  await run($, 'Grep', 500, { pattern: 'x' })
  const r: any = await cmd($, 'ministry')
  expect(r.text).toContain('Read')
  expect(r.text).toContain('2 calls')
  expect(r.text).toContain('Grep')
  expect(r.text).toContain('a.ts')
})

test('session end appends a summary, capped at 50', async ($, on) => {
  const w = world(on)
  w.store.set('sessions', Array.from({ length: 50 }, (_, i) => ({ i })))
  await run($, 'Read', 4096, { file_path: 'a.ts' })
  await $.session.end({ reason: 'exit' } as any)
  const s = w.store.get('sessions') as any[]
  expect(s.length).toBe(50)
  expect(s.at(-1).bytesIn).toBe(4096)
  expect(s.at(-1).byTool.Read.calls).toBe(1)
})
