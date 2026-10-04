import { test, expect } from 'claude-code/testing'

function world(on: any) {
  const w = { contexts: [] as string[][], store: new Map<string, unknown>() }
  on('prompt.submit', (_$: any, e: any) => { w.contexts.push([...(e.context ?? [])]); return { text: e.text } })
  on('ui.status', () => ({ value: undefined }))
  on('store.get', (_$: any, e: any) => ({ value: w.store.get(e.key) }))
  on('store.set', (_$: any, e: any) => { w.store.set(e.key, e.value); return { value: undefined } })
  return w
}
const submit = ($: any, text: string) => $.prompt.submit({ text, wait: false, origin: { kind: 'composer' } })
const note = (w: any) => String(w.contexts.at(-1))

test('bare items are named by number', async ($, on) => {
  const w = world(on)
  await submit($, '1. fix the login\n2. add a retry so that a 503 is retried 3 times\n3. clean up utils')
  expect(note(w)).toContain('1')
  expect(note(w)).toContain('3')
  expect(note(w)).toContain('fix the login')
  expect(note(w)).not.toContain('retry')
})

test('Spanish criteria count', async ($, on) => {
  const w = world(on)
  await submit($, '1. arregla el login para que el test pase en verde\n2. haz el informe hasta que cubra los 12 mods\n3. revisa')
  expect(note(w)).toContain('revisa')
  expect(note(w)).not.toContain('login')
  expect(note(w)).not.toContain('informe')
})

test('every item with a criterion: no note', async ($, on) => {
  const w = world(on)
  await submit($, '- parser returns [] on empty input\n- `bash scripts/test-x.sh` passes\n- latency < 200 ms')
  expect(w.contexts.at(-1)).toEqual([])
})

test('a fenced list or a single item is not graded', async ($, on) => {
  const w = world(on)
  await submit($, 'look:\n```\n1. a\n2. b\n```')
  await submit($, '1. fix the login')
  expect(w.contexts).toEqual([[], []])
})

test('counts accumulate in the store', async ($, on) => {
  const w = world(on)
  await submit($, '1. fix a\n2. b must return 0')
  await submit($, '1. do x\n2. do y')
  expect(w.store.get('counts')).toEqual({ lists: 2, items: 4, bare: 3 })
})

test('/newspeak shows the share', async ($, on) => {
  world(on)
  await submit($, '1. fix a\n2. b must return 0')
  const r: any = await $.command.run({ command: 'newspeak', args: '', origin: { kind: 'composer' }, presentation: { layout: 'main', columns: 80 } } as any)
  expect(r.text).toContain('1 of 2')
})

test('P77: prose multi-item asks are counted by kind, with no note', async ($, on) => {
  const w = world(on)
  await submit($, 'arregla esos 2 fallos antes de seguir')
  await submit($, 'dale de forma autónoma con todas hasta terminarlas')
  await submit($, 'update the docs and then bump the version')
  await submit($, 'fix the login')
  expect(w.contexts).toEqual([[], [], [], []])
  const p: any = w.store.get('prose')
  expect(p.asks).toBe(3)
  expect(p.kinds).toEqual({ count: 1, quantifier: 1, sequence: 1 })
  expect(p.recent.length).toBe(3)
})

test('P77: a list is a list, not a prose ask', async ($, on) => {
  const w = world(on)
  await submit($, '1. do all of them\n2. and then the rest')
  expect((w.store.get('prose') as any)?.asks ?? 0).toBe(0)
})

test('P77: /newspeak reports prose asks too', async ($, on) => {
  world(on)
  await submit($, 'haz los 3 cambios')
  const r: any = await $.command.run({ command: 'newspeak', args: '', origin: { kind: 'composer' }, presentation: { layout: 'main', columns: 80 } } as any)
  expect(r.text).toContain('1 prose multi-item ask')
})
