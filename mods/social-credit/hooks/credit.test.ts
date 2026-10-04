import { test, expect } from 'claude-code/testing'

function world(on: any, score?: number) {
  const w = { status: [] as string[], store: new Map<string, unknown>() }
  if (score !== undefined) w.store.set('score', score)
  on('ui.status', (_$: any, e: any) => { w.status.push(String(e.text ?? e)); return { value: undefined } })
  on('ui.toast', () => ({ value: undefined }))
  on('store.get', (_$: any, e: any) => ({ value: w.store.get(e.key) }))
  on('store.set', (_$: any, e: any) => { w.store.set(e.key, e.value); return { value: undefined } })
  on('tool.call', () => ({ result: 'ok', text: 'ok' }))
  on('prompt.compose', () => ({ sections: [{ id: 'intro', text: 'base', scope: 'shared' }] }))
  return w
}
const call = ($: any, tool: string, extra: object) => $.tool.call({ tool, ...extra })
const score = (w: any) => w.store.get('score')
const compose = ($: any) => $.prompt.compose({ model: 'm', promptModel: 'm', surfaces: ['terminal'], tools: [], outputStyle: null, traits: [] })
const cmd = ($: any, args = '') =>
  $.command.run({ command: 'social-credit', args, origin: { kind: 'composer' }, presentation: { layout: 'main', columns: 80 } })

test('an Edit earns a point, a rewrite of a read file costs five', async ($, on) => {
  const w = world(on)
  await call($, 'Edit', { file_path: 'a.ts', old_string: 'a', new_string: 'b' })
  expect(score(w)).toBe(101)
  await call($, 'Read', { file_path: 'b.ts' })
  await call($, 'Write', { file_path: 'b.ts', content: 'x' })
  expect(score(w)).toBe(96)
  await call($, 'Write', { file_path: 'new.ts', content: 'x' })
  expect(score(w)).toBe(96)
  expect(w.status.at(-1)).toContain('96')
})

test('test-first earns three, script-first costs three', async ($, on) => {
  const w = world(on)
  await call($, 'Write', { file_path: 'scripts/test-foo.sh', content: 'x' })
  await call($, 'Write', { file_path: 'scripts/foo.sh', content: 'x' })
  expect(score(w)).toBe(103)
  await call($, 'Edit', { file_path: 'scripts/bar.sh', old_string: 'a', new_string: 'b' })
  expect(score(w)).toBe(101)
})

test('a commit earns one; a skipped gate costs ten', async ($, on) => {
  const w = world(on)
  await call($, 'Bash', { command: 'git commit -m x' })
  expect(score(w)).toBe(101)
  await call($, 'Bash', { command: 'SKIP_TEST_PAIRING=1 git push' })
  await call($, 'Bash', { command: 'git commit --no-verify -m y' })
  expect(score(w)).toBe(82)
})

test('the score persists across sessions', async ($, on) => {
  const w = world(on, 90)
  await call($, 'Edit', { file_path: 'a.ts', old_string: 'a', new_string: 'b' })
  expect(score(w)).toBe(91)
})

test('above 80 the prompt is untouched', async ($, on) => {
  world(on, 85)
  const r: any = await compose($)
  expect(r.sections.length).toBe(1)
})

test('below 80 a re-education section names the broken rules, stable across points', async ($, on) => {
  const w = world(on, 85)
  await call($, 'Bash', { command: 'git push --no-verify' })
  const a: any = await compose($)
  expect(a.sections.at(-1).id).toBe('social-credit:re-education')
  expect(a.sections.at(-1).scope).toBe('session')
  expect(a.sections.at(-1).text).toContain('no silent skips')
  await call($, 'Edit', { file_path: 'a.ts', old_string: 'a', new_string: 'b' })
  const b: any = await compose($)
  expect(b.sections.at(-1).text).toBe(a.sections.at(-1).text)
  expect(score(w)).toBe(76)
})

test('/social-credit lists acts; amnesty resets', async ($, on) => {
  const w = world(on, 50)
  await call($, 'Edit', { file_path: 'a.ts', old_string: 'a', new_string: 'b' })
  const r: any = await cmd($)
  expect(r.text).toContain('51')
  expect(r.text).toContain('edit over rewrite')
  await cmd($, 'amnesty')
  expect(score(w)).toBe(100)
  const c: any = await compose($)
  expect(c.sections.length).toBe(1)
})
