import { test, expect } from 'claude-code/testing'

const USAGE = { input_tokens: 1, output_tokens: 1 }
function classifier(on: any, answer: () => string | undefined | Error) {
  on('model.complete', () => {
    const a = answer()
    if (a instanceof Error) return { value: { isAnswered: false, reason: 'api-error' } }
    return { value: { isAnswered: true, text: a ?? 'none of them', usage: USAGE } }
  })
  on('ui.status', () => ({ value: undefined }))
  on('ui.toast', () => ({ value: undefined }))
}

const SONNET = 'claude-sonnet-5-5'
const OPUS = 'claude-opus-5-5'

function engine(on: any, label: string | undefined) {
  const sent: any[] = []
  classifier(on, () => label)
  on('prompt.submit', (_$: any, e: any) => ({ text: e.text }))
  on('command.run', () => ({ text: '' }))
  on('turn.step', async function* (_$: any, e: any) {
    sent.push({ model: e.model, effort: e.effort, agentId: e.agentId })
    return { turnId: e.turnId, index: e.index, answer: '', toolUses: [], stopReason: 'end_turn', usage: null }
  })
  return sent
}

function submit($: any, e: object) {
  return $.prompt.submit({ wait: false, origin: { kind: 'composer' }, ...e })
}

async function step($: any, extra: object = {}) {
  const s = $.turn.step({ turnId: 't', index: 0, model: 'session-model', effort: 'max', messageCount: 1, ...extra })
  for await (const _ of s) {}
}

test('starts at sonnet/medium before any prompt', async ($, on) => {
  const sent = engine(on, undefined)
  await step($)
  expect(sent[0]).toEqual({ model: SONNET, effort: 'medium', agentId: undefined })
})

test('judgment routes the turn to opus/high', async ($, on) => {
  const sent = engine(on, 'judgment')
  await submit($, { text: 'design the migration strategy for the billing schema' })
  await step($)
  expect(sent[0].model).toBe(OPUS)
  expect(sent[0].effort).toBe('high')
})

test('mechanical routes to sonnet/low', async ($, on) => {
  const sent = engine(on, 'mechanical')
  await submit($, { text: 'rename foo to bar in utils.ts' })
  await step($)
  expect(sent[0]).toEqual({ model: SONNET, effort: 'low', agentId: undefined })
})

test('a prompt delivered mid-turn does not re-decide', async ($, on) => {
  let label = 'judgment'
  const sent: any[] = []
  classifier(on, () => label)
  on('prompt.submit', (_$: any, e: any) => ({ text: e.text }))
  on('turn.step', async function* (_$: any, e: any) {
    sent.push(e.model)
    return { turnId: e.turnId, index: e.index, answer: '', toolUses: [], stopReason: 'end_turn', usage: null }
  })
  await submit($, { text: 'think hard about the architecture' })
  label = 'mechanical'
  await submit($, { text: 'also rename x', turnId: 't' })
  await step($)
  expect(sent[0]).toBe(OPUS)
})

test('subagent steps pass untouched', async ($, on) => {
  const sent = engine(on, 'mechanical')
  await submit($, { text: 'rename foo' })
  await step($, { agentId: 'a1', model: 'claude-haiku-4-5', effort: undefined })
  expect(sent[0].model).toBe('claude-haiku-4-5')
})

test('an unclassifiable prompt keeps the current tier', async ($, on) => {
  const sent = engine(on, undefined)
  await submit($, { text: '???' })
  await step($)
  expect(sent[0].model).toBe(SONNET)
  expect(sent[0].effort).toBe('medium')
})

test('a failed classification keeps the tier', async ($, on) => {
  const sent: any[] = []
  classifier(on, () => new Error('down'))
  on('prompt.submit', (_$: any, e: any) => ({ text: e.text }))
  on('turn.step', async function* (_$: any, e: any) {
    sent.push(e.effort)
    return { turnId: e.turnId, index: e.index, answer: '', toolUses: [], stopReason: 'end_turn', usage: null }
  })
  await submit($, { text: 'design it' })
  await step($)
  expect(sent[0]).toBe('medium')
})

test('a slash command keeps the tier and is not classified', async ($, on) => {
  let asked = 0
  classifier(on, () => { asked++; return 'judgment' })
  on('prompt.submit', (_$: any, e: any) => ({ text: e.text }))
  await submit($, { text: '/compact' })
  expect(asked).toBe(0)
})

test('/committee pins a tier until auto', async ($, on) => {
  const sent = engine(on, 'mechanical')
  await $.command.run({ command: 'committee', args: 'opus', origin: { kind: 'composer' }, presentation: { layout: 'main', columns: 80 } } as any)
  await submit($, { text: 'rename foo' })
  await step($)
  expect(sent[0].model).toBe(OPUS)
  await $.command.run({ command: 'committee', args: 'auto', origin: { kind: 'composer' }, presentation: { layout: 'main', columns: 80 } } as any)
  await submit($, { text: 'rename foo' })
  await step($)
  expect(sent[1].effort).toBe('low')
})

test('P78: each session leaves its tally of decisions in the store', async ($, on) => {
  const store = new Map<string, unknown>()
  on('store.get', (_$: any, e: any) => ({ value: store.get(e.key) }))
  on('store.set', (_$: any, e: any) => { store.set(e.key, e.value); return { value: undefined } })
  on('session.end', () => ({ sessionId: 's' }))
  let label = 'judgment'
  classifier(on, () => label)
  on('prompt.submit', (_$: any, e: any) => ({ text: e.text }))
  await submit($, { text: 'design it' })
  label = 'mechanical'
  await submit($, { text: 'rename it' })
  await submit($, { text: 'rename that too' })
  await submit($, { text: '/compact' })
  await $.session.end({ reason: 'exit' } as any)
  const s = store.get('sessions') as any[]
  expect(s.length).toBe(1)
  expect(s[0].tally).toEqual({ judgment: 1, mechanical: 2 })
  expect(s[0].switches).toBe(2)
})

test('P78: /committee stats sums the stored sessions', async ($, on) => {
  const store = new Map<string, unknown>([['sessions', [{ tally: { routine: 3 }, switches: 0 }, { tally: { judgment: 1, routine: 1 }, switches: 2 }]]])
  on('store.get', (_$: any, e: any) => ({ value: store.get(e.key) }))
  on('ui.status', () => ({ value: undefined }))
  const r: any = await $.command.run({ command: 'committee', args: 'stats', origin: { kind: 'composer' }, presentation: { layout: 'main', columns: 80 } } as any)
  expect(r.text).toContain('2 sessions')
  expect(r.text).toContain('routine 4')
  expect(r.text).toContain('judgment 1')
  expect(r.text).toContain('2 switches')
})
