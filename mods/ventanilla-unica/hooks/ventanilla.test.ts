import { test, expect } from 'claude-code/testing'

const OUT = 'PASS claude plugin validate . --strict\nPASS scripts/check-mods.sh\nSKIPPED x (no CLI)\nFAIL scripts/test-y.sh\n    detail line\n3/4 passed\nfailed: scripts/test-y.sh\n'

function world(on: any, out = OUT, code = 1) {
  const w = { toasts: [] as string[], spawned: [] as string[][] }
  on('ui.toast', (_$: any, e: any) => { w.toasts.push(e.text ?? e); return { value: undefined } })
  on('ui.status', () => ({ value: undefined }))
  on('ui.open', () => ({ value: undefined }))
  on('process.spawn', async function* (_$: any, e: any) {
    w.spawned.push([...e.argv])
    for (const line of out.split(/(?<=\n)/)) yield { stream: 'stdout', text: line }
    return { value: { code, signal: null } }
  })
  on('tool.call', (_$: any, e: any) => ({ result: 'ok', text: e.out ?? '' }))
  return w
}
const cmd = ($: any, args = '') =>
  $.command.run({ command: 'ventanilla', args, origin: { kind: 'composer' }, presentation: { layout: 'main', columns: 160 } })
declare const setTimeout: (f: (v?: unknown) => void, ms: number) => void
const settle = () => new Promise(r => setTimeout(r, 30))

test('/ventanilla runs the sweep and stamps each gate', async ($, on) => {
  const w = world(on)
  await cmd($, 'origin/main')
  await settle()
  expect(w.spawned[0]).toEqual(['bash', 'scripts/sweep.sh', 'origin/main'])
  const s: any = await cmd($, 'status')
  expect(s.text).toContain('✔ scripts/check-mods.sh')
  expect(s.text).toContain('✘ scripts/test-y.sh')
  expect(s.text).toContain('3/4 passed')
  expect(w.toasts.join()).toContain('scripts/test-y.sh')
})

test('a clean sweep is sealed', async ($, on) => {
  const w = world(on, 'PASS a\nPASS b\n2/2 passed\n', 0)
  await cmd($)
  await settle()
  expect(w.spawned[0]).toEqual(['bash', 'scripts/sweep.sh'])
  expect(w.toasts.join()).toContain('2/2')
})

test('a sweep run through Bash is read too', async ($, on) => {
  world(on)
  await $.tool.call({ tool: 'Bash', command: 'bash scripts/sweep.sh origin/main', out: 'PASS a\nFAIL b\n1/2 passed\n' } as any)
  const s: any = await cmd($, 'status')
  expect(s.text).toContain('✔ a')
  expect(s.text).toContain('✘ b')
})

test('other Bash commands are not stamps', async ($, on) => {
  world(on)
  await $.tool.call({ tool: 'Bash', command: 'ls', out: 'PASS fake\n' } as any)
  const s: any = await cmd($, 'status')
  expect(s.text).not.toContain('fake')
})

for (const surface of ['terminal', 'desktop'] as const) {
  test(`the pane draws the stamps on ${surface}`, async ($, on) => {
    world(on)
    await $.tool.call({ tool: 'Bash', command: 'bash scripts/sweep.sh', out: 'PASS a\nFAIL b\n1/2 passed\n' } as any)
    const ui: any = await $.ui.mount({ plugin: 'ventanilla-unica', surface, component: 'Pane', props: {} as any, requestId: 'ventanilla' } as any)
    expect(await ui.find({ text: /b/ })).toBeTruthy()
    expect(await ui.find({ text: /1\/2 passed/ })).toBeTruthy()
  })
}
