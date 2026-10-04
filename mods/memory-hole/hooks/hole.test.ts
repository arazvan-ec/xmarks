import { test, expect } from 'claude-code/testing'

function world(on: any) {
  const w = { toasts: [] as string[], contexts: [] as string[][], ran: [] as string[] }
  on('ui.toast', (_$: any, e: any) => { w.toasts.push(e.text ?? e); return { value: undefined } })
  on('ui.status', () => ({ value: undefined }))
  on('prompt.submit', (_$: any, e: any) => { w.contexts.push([...(e.context ?? [])]); return { text: e.text } })
  on('tool.call', (_$: any, e: any) => { w.ran.push(`${e.tool} ${e.file_path ?? e.notebook_path}`); return { result: 'ok', text: 'ok' } })
  return w
}
const submit = ($: any, text: string) => $.prompt.submit({ text, wait: false, origin: { kind: 'composer' } })
const edit = ($: any, file_path: string, tool = 'Edit') => $.tool.call({ tool, file_path, old_string: 'a', new_string: 'b', content: 'c' })
const cmd = ($: any, args: string) =>
  $.command.run({ command: 'memory-hole', args, origin: { kind: 'composer' }, presentation: { layout: 'main', columns: 80 } })

test('a numbered list opens the hole and edits are denied', async ($, on) => {
  const w = world(on)
  await submit($, 'Please do:\n1. fix the login\n2. add the test')
  expect(String(w.contexts[0])).toContain('file')
  const r: any = await edit($, 'src/login.ts')
  expect(r.isError ?? r.deny).toBeTruthy()
  expect(w.ran).toEqual([])
})

test('three bullets open it; a plan file closes it', async ($, on) => {
  const w = world(on)
  await submit($, '- a\n- b\n- c')
  await edit($, 'src/early.ts')
  await edit($, '.claude/flywheel/specs/x.plan.md', 'Write')
  await edit($, 'src/a.ts')
  expect(w.ran).toEqual(['Write .claude/flywheel/specs/x.plan.md', 'Edit src/a.ts'])
})

test('a scratchpad list closes it', async ($, on) => {
  const w = world(on)
  await submit($, '1. one\n2. two')
  await edit($, 'src/early.ts')
  await edit($, '/tmp/claude-0/x/scratchpad/list.md', 'Write')
  await edit($, 'src/a.ts')
  expect(w.ran).toEqual(['Write /tmp/claude-0/x/scratchpad/list.md', 'Edit src/a.ts'])
})

test('a list inside a code fence is not a list', async ($, on) => {
  const w = world(on)
  await submit($, 'what does this print?\n```\n1. a\n2. b\n```')
  await edit($, 'src/a.ts')
  expect(w.ran).toEqual(['Edit src/a.ts'])
  expect(w.contexts[0]).toEqual([])
})

test('one item, or two bullets, is not a list', async ($, on) => {
  const w = world(on)
  await submit($, '1. just this')
  await submit($, '- a\n- b')
  await edit($, 'src/a.ts')
  expect(w.ran.length).toBe(1)
})

test('NotebookEdit is held too', async ($, on) => {
  const w = world(on)
  await submit($, '1. a\n2. b')
  await $.tool.call({ tool: 'NotebookEdit', notebook_path: 'n.ipynb', new_source: 'x' })
  expect(w.ran).toEqual([])
})

test('/memory-hole release closes it and says so', async ($, on) => {
  const w = world(on)
  await submit($, '1. a\n2. b')
  await cmd($, 'release')
  await edit($, 'src/a.ts')
  expect(w.ran.length).toBe(1)
  expect(w.toasts.join()).toContain('released')
})

test('an Edit that adds the list to an existing plan closes it too', async ($, on) => {
  const w = world(on)
  await submit($, '1. a\n2. b')
  await edit($, '.claude/flywheel/specs/old.plan.md')
  await edit($, 'src/a.ts')
  expect(w.ran).toEqual(['Edit .claude/flywheel/specs/old.plan.md', 'Edit src/a.ts'])
})
