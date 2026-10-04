import { test, expect } from 'claude-code/testing'

function world(on: any) {
  const w = { ran: [] as string[], toasts: [] as string[], contexts: [] as string[][], red: new Set<string>() }
  on('tool.call', (_$: any, e: any) => {
    w.ran.push(e.tool)
    if (e.tool === 'Bash' && w.red.has(e.command)) return { result: 'exit 1', text: 'FAIL', isError: true }
    return { result: 'ok', text: 'ok' }
  })
  on('ui.toast', (_$: any, e: any) => { w.toasts.push(String(e.text ?? e)); return { value: undefined } })
  on('ui.status', () => ({ value: undefined }))
  on('prompt.submit', (_$: any, e: any) => { w.contexts.push([...(e.context ?? [])]); return { text: e.text } })
  return w
}
const T = 'bash scripts/test-foo.sh'
const bash = ($: any, command: string) => $.tool.call({ tool: 'Bash', command })
const edit = ($: any) => $.tool.call({ tool: 'Edit', file_path: 'scripts/foo.sh', old_string: 'a', new_string: 'b' })
const held = async ($: any, w: any) => { w.ran.length = 0; await edit($); return w.ran.length === 0 }
async function reds($: any, n: number) { for (let i = 0; i < n; i++) { await bash($, T); await edit($) } }

test('two reds are still TDD', async ($, on) => {
  const w = world(on); w.red.add(T)
  await reds($, 2)
  expect(await held($, w)).toBe(false)
})

test('the third red with edits between declares a strike', async ($, on) => {
  const w = world(on); w.red.add(T)
  await reds($, 2)
  await bash($, T)
  expect(w.toasts.join()).toContain('strike')
  expect(await held($, w)).toBe(true)
})

test('re-runs without an edit are not new attempts', async ($, on) => {
  const w = world(on); w.red.add(T)
  for (let i = 0; i < 5; i++) await bash($, T)
  expect(await held($, w)).toBe(false)
})

test('a pass resets the count', async ($, on) => {
  const w = world(on); w.red.add(T)
  await reds($, 2)
  w.red.delete(T); await bash($, T); w.red.add(T)
  await reds($, 2)
  expect(await held($, w)).toBe(false)
})

test('a different check is counted separately', async ($, on) => {
  const w = world(on); w.red.add(T); w.red.add('npm test')
  await bash($, T); await edit($)
  await bash($, 'npm test'); await edit($)
  await bash($, T); await edit($)
  expect(await held($, w)).toBe(false)
})

test('during a strike reads and Bash run, the next prompt is told to debug', async ($, on) => {
  const w = world(on); w.red.add(T)
  await reds($, 2); await bash($, T)
  w.ran.length = 0
  await $.tool.call({ tool: 'Read', file_path: 'scripts/foo.sh' })
  await bash($, 'git diff')
  expect(w.ran).toEqual(['Read', 'Bash'])
  await $.prompt.submit({ text: 'try again', wait: false, origin: { kind: 'composer' } })
  expect(String(w.contexts.at(-1))).toContain('/flywheel:debug')
})

test('a pass of the striking check ends it', async ($, on) => {
  const w = world(on); w.red.add(T)
  await reds($, 2); await bash($, T)
  w.red.delete(T); await bash($, T)
  expect(await held($, w)).toBe(false)
})

test('opening flywheel:debug ends it', async ($, on) => {
  const w = world(on); w.red.add(T)
  await reds($, 2); await bash($, T)
  await $.tool.call({ tool: 'Skill', skill: 'flywheel:debug' })
  expect(await held($, w)).toBe(false)
})

test('/strike end ends it, announced', async ($, on) => {
  const w = world(on); w.red.add(T)
  await reds($, 2); await bash($, T)
  await $.command.run({ command: 'strike', args: 'end', origin: { kind: 'composer' }, presentation: { layout: 'main', columns: 80 } } as any)
  expect(await held($, w)).toBe(false)
  expect(w.toasts.join()).toContain('ended')
})

test('a failing non-check command is ignored', async ($, on) => {
  const w = world(on); w.red.add('ls nope')
  for (let i = 0; i < 4; i++) { await bash($, 'ls nope'); await edit($) }
  expect(await held($, w)).toBe(false)
})
