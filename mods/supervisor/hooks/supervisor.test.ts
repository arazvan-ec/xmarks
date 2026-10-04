import { test, expect } from 'claude-code/testing'

function world(on: any) {
  const w = { contexts: [] as string[][], toasts: [] as string[] }
  on('prompt.submit', (_$: any, e: any) => { w.contexts.push([...(e.context ?? [])]); return { text: e.text } })
  on('classic.Stop', () => ({}))
  on('ui.toast', (_$: any, e: any) => { w.toasts.push(String(e.text ?? e)); return { value: undefined } })
  return w
}
const submit = ($: any) => $.prompt.submit({ text: 'go on', wait: false, origin: { kind: 'composer' } })
const stop = ($: any, msg: string) => $.classic.Stop({ stop_hook_active: false, last_assistant_message: msg })
const cmd = ($: any, args = '') =>
  $.command.run({ command: 'supervisor', args, origin: { kind: 'composer' }, presentation: { layout: 'main', columns: 80 } } as any)
const asked = (w: any) => w.contexts.map((c: string[]) => c.length > 0)

test('the note rides every 5th prompt', async ($, on) => {
  const w = world(on)
  for (let i = 0; i < 10; i++) await submit($)
  expect(asked(w)).toEqual([false, false, false, false, true, false, false, false, false, true])
  expect(String(w.contexts[4])).toContain('evidence')
})

test('the cadence is configurable', async ($, on) => {
  const w = world(on)
  await cmd($, 'every 2')
  for (let i = 0; i < 4; i++) await submit($)
  expect(asked(w)).toEqual([false, true, false, true])
})

test('a supervised reply with no evidence is noted', async ($, on) => {
  const w = world(on)
  await cmd($, 'every 1')
  await submit($)
  await stop($, 'All done, everything works now.')
  expect(w.toasts.join()).toContain('evidence')
})

for (const [name, reply] of [
  ['file:line', 'Closed T3 — mods/a/hooks/register.ts:42 now guards it.'],
  ['a command', 'Closed: `bash scripts/check-mods.sh origin/main a` passes.'],
  ['a commit', 'Closed in commit 85a0291.'],
] as const) {
  test(`evidence as ${name} is accepted`, async ($, on) => {
    const w = world(on)
    await cmd($, 'every 1')
    await submit($)
    await stop($, reply)
    expect(w.toasts.length).toBe(0)
  })
}

test('an unsupervised turn is not graded', async ($, on) => {
  const w = world(on)
  await submit($)
  await stop($, 'done')
  expect(w.toasts.length).toBe(0)
})

test('/supervisor counts checks and evidenced replies', async ($, on) => {
  world(on)
  await cmd($, 'every 1')
  await submit($)
  await stop($, 'done')
  await submit($)
  await stop($, 'see commit abc1234f')
  const r: any = await cmd($)
  expect(r.text).toContain('2 checks')
  expect(r.text).toContain('1 named evidence')
})
