import { test, expect } from 'claude-code/testing'

declare const h: (type: unknown, props: object, ...children: unknown[]) => unknown

const LEDGER = [
  '# ledger', '',
  '## gotcha: an old lesson about the gate', '', '<!-- fw: type=gotcha; date=2026-09-01; files=scripts/gate.sh,scripts/x.sh; spec=a -->', '', 'body', '',
  '## pattern: the newer lesson about the gate', '', '<!-- fw: type=pattern; date=2026-09-20; files=scripts/gate.sh; spec=b -->', '', 'body', '',
  '## decision: about mods', '', '<!-- fw: type=decision; date=2026-10-01; files=mods/a/hooks/register.ts; spec=c -->', '',
].join('\n')

function world(on: any) {
  on('fs.read', () => ({ value: LEDGER }))
  on('tool.call', () => ({ result: 'ok', text: 'ok' }))
  on('ui.render', ($: any, e: any) => { const { Box } = $.ui.resolve(e); return h(Box, {}) })
}
const touch = ($: any, file_path: string, tool = 'Read') => $.tool.call({ tool, file_path, old_string: 'a', new_string: 'b', content: 'c' })
const band = ($: any, surface: 'terminal' | 'desktop' = 'terminal') =>
  $.ui.mount({ plugin: 'telescreen', surface, component: 'AbovePrompt', props: {} as any } as any)
const cmd = ($: any) =>
  $.command.run({ command: 'telescreen', args: '', origin: { kind: 'composer' }, presentation: { layout: 'main', columns: 80 } } as any)

for (const surface of ['terminal', 'desktop'] as const) {
  test(`a touch on a cited file shows the newest lesson on ${surface}`, async ($, on) => {
    world(on)
    await touch($, '/repo/scripts/gate.sh')
    const ui: any = await band($, surface)
    expect(await ui.find({ text: /the newer lesson about the gate/ })).toBeTruthy()
    expect(await ui.find({ text: /old lesson/ })).toBeFalsy()
  })
}

test('no match, no band', async ($, on) => {
  world(on)
  await touch($, 'src/unrelated.ts')
  const ui: any = await band($)
  expect(await ui.find({ text: /lesson|mods/ })).toBeFalsy()
})

test('Hide holds until a different slogan applies', async ($, on) => {
  world(on)
  await touch($, 'scripts/gate.sh', 'Edit')
  let ui: any = await band($)
  await ui.press({ key: 'hide' })
  ui = await band($)
  expect(await ui.find({ text: /newer lesson/ })).toBeFalsy()
  await touch($, 'scripts/gate.sh')
  ui = await band($)
  expect(await ui.find({ text: /newer lesson/ })).toBeFalsy()
  await touch($, 'mods/a/hooks/register.ts', 'Write')
  ui = await band($)
  expect(await ui.find({ text: /about mods/ })).toBeTruthy()
})

test('/telescreen counts entries and slogans shown', async ($, on) => {
  world(on)
  await touch($, 'scripts/gate.sh')
  await touch($, 'mods/a/hooks/register.ts')
  const r: any = await cmd($)
  expect(r.text).toContain('3 lessons')
  expect(r.text).toContain('2 slogans')
})
