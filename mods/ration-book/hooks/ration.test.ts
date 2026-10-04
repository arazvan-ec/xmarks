import { test, expect } from 'claude-code/testing'

const KB = 1024
function world(on: any, history?: number[]) {
  const w = { status: [] as string[], toasts: [] as string[], ran: [] as string[], store: new Map<string, unknown>() }
  if (history) w.store.set('totals', history)
  on('ui.status', (_$: any, e: any) => { w.status.push(String(e.text ?? e)); return { value: undefined } })
  on('ui.toast', (_$: any, e: any) => { w.toasts.push(String(e.text ?? e)); return { value: undefined } })
  on('store.get', (_$: any, e: any) => ({ value: w.store.get(e.key) }))
  on('store.set', (_$: any, e: any) => { w.store.set(e.key, e.value); return { value: undefined } })
  on('tool.call', (_$: any, e: any) => { w.ran.push(e.tool); return { result: 'ok', text: 'x'.repeat(e.size ?? 10) } })
  on('session.end', () => ({ sessionId: 's' }))
  return w
}
const read = ($: any, size: number, tool = 'Read') => $.tool.call({ tool, file_path: 'a', pattern: 'p', command: 'git status', size })
const cmd = ($: any, args = '') =>
  $.command.run({ command: 'ration', args, origin: { kind: 'composer' }, presentation: { layout: 'main', columns: 80 } } as any)

test('with no history the ration is 400 KB', async ($, on) => {
  world(on)
  const r: any = await cmd($)
  expect(r.text).toContain('400 KB')
})

test('with 5+ sessions the ration is their p75, floored at 100 KB', async ($, on) => {
  world(on, [100, 200, 300, 400, 500, 600, 700, 800].map(k => k * KB))
  expect(((await cmd($)) as any).text).toContain('600 KB')
})

test('a thin history never sets a ration under 100 KB', async ($, on) => {
  world(on, [1, 2, 3, 4, 5].map(k => k * KB))
  expect(((await cmd($)) as any).text).toContain('100 KB')
})

test('80% raises a toast once', async ($, on) => {
  const w = world(on, Array(5).fill(100 * KB))
  await read($, 79 * KB)
  expect(w.toasts.length).toBe(0)
  await read($, 2 * KB)
  await read($, 1 * KB)
  expect(w.toasts.length).toBe(1)
  expect(w.status.at(-1)).toMatch(/1[78]%/)
})

test('at 100% reads are held, Bash still runs', async ($, on) => {
  const w = world(on, Array(5).fill(100 * KB))
  await read($, 101 * KB)
  w.ran.length = 0
  const r: any = await read($, 10)
  expect(r.isError ?? r.deny).toBeTruthy()
  await read($, 10, 'Grep')
  await read($, 10, 'Bash')
  expect(w.ran).toEqual(['Bash'])
})

test('a grant lifts the hold and is announced', async ($, on) => {
  const w = world(on, Array(5).fill(100 * KB))
  await read($, 101 * KB)
  await cmd($, 'grant 50')
  w.ran.length = 0
  await read($, 10)
  expect(w.ran).toEqual(['Read'])
  expect(w.toasts.join()).toContain('50 KB')
})

test('the session total is stored for the next calibration', async ($, on) => {
  const w = world(on, [1 * KB])
  await read($, 3 * KB)
  await $.session.end({ reason: 'exit' } as any)
  expect(w.store.get('totals')).toEqual([1 * KB, 3 * KB])
})
