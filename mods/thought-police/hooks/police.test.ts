import { test, expect } from 'claude-code/testing'

const BODY = Array.from({ length: 12 }, (_, i) => `export const value${i} = compute(${i}) + offset`).join('\n')

function world(on: any) {
  on('tool.call', () => ({ result: 'ok', text: 'ok' }))
  on('prompt.submit', (_$: any, e: any) => ({ text: e.text }))
  on('classic.Stop', () => ({}))
  on('ui.toast', () => ({ value: undefined }))
}
const submit = ($: any) => $.prompt.submit({ text: 'go', wait: false, origin: { kind: 'composer' } })
const stop = ($: any, msg: string, active = false) => $.classic.Stop({ stop_hook_active: active, last_assistant_message: msg })
const fence = (s: string) => '```ts\n' + s + '\n```'

test('a reply that pastes back a written file is stopped', async ($, on) => {
  world(on)
  await submit($)
  await $.tool.call({ tool: 'Write', file_path: 'a.ts', content: BODY })
  const r: any = await stop($, 'Done. Here is a.ts:\n' + fence(BODY))
  expect(r.block).toContain('what and where')
})

test('pasting back an Edit is stopped too', async ($, on) => {
  world(on)
  await submit($)
  await $.tool.call({ tool: 'Edit', file_path: 'a.ts', old_string: 'x', new_string: BODY })
  const r: any = await stop($, fence(BODY))
  expect(r.block).toBeTruthy()
})

test('a short snippet is fine', async ($, on) => {
  world(on)
  await submit($)
  await $.tool.call({ tool: 'Write', file_path: 'a.ts', content: BODY })
  const r: any = await stop($, fence(BODY.split('\n').slice(0, 3).join('\n')))
  expect(r.block).toBeUndefined()
})

test('code that was not written this turn is fine', async ($, on) => {
  world(on)
  await submit($)
  const r: any = await stop($, fence(BODY))
  expect(r.block).toBeUndefined()
})

test('prose that repeats the code outside a fence is not graded', async ($, on) => {
  world(on)
  await submit($)
  await $.tool.call({ tool: 'Write', file_path: 'a.ts', content: BODY })
  const r: any = await stop($, BODY)
  expect(r.block).toBeUndefined()
})

test('never blocks twice in a row', async ($, on) => {
  world(on)
  await submit($)
  await $.tool.call({ tool: 'Write', file_path: 'a.ts', content: BODY })
  const r: any = await stop($, fence(BODY), true)
  expect(r.block).toBeUndefined()
})

test('a new prompt forgets the last turn’s writes', async ($, on) => {
  world(on)
  await submit($)
  await $.tool.call({ tool: 'Write', file_path: 'a.ts', content: BODY })
  await submit($)
  const r: any = await stop($, fence(BODY))
  expect(r.block).toBeUndefined()
})
