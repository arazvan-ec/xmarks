import type { Register } from 'claude-code'

const ITEM = /^\s*(?:(\d+)[.)]|[-*•])\s+(.+)$/
const CRITERION = new RegExp(
  [
    'so that', 'until', 'must', 'should', 'pass(?:es|ing)?', 'returns?', 'green', 'fails?', 'exit',
    'para que', 'hasta que', 'debe', 'que pase', 'en verde', 'devuelv', 'sin que', 'de forma que',
    '→', '->', '=', '[<>≤≥]', '\\d+\\s*(?:%|ms|s|kb|mb|lines?|items?|mods?|tests?|veces|times)',
    '`[^`]+`',
  ].join('|'),
  'i',
)

type Counts = { lists: number; items: number; bare: number }

function items(text: string): string[] {
  const plain = text.replace(/```[\s\S]*?```/g, '')
  const found = plain.split('\n').map(l => ITEM.exec(l)).filter((m): m is RegExpExecArray => m !== null)
  const numbered = found.filter(m => m[1]).length
  const bullets = found.length - numbered
  return numbered >= 2 || bullets >= 3 ? found.map(m => (m[2] ?? '').trim()) : []
}

async function counts($: any): Promise<Counts> {
  return ((await $.store.get('counts').catch(() => undefined)) as Counts | undefined) ?? { lists: 0, items: 0, bare: 0 }
}

export const register: Register = on => {
  on('session.start', ($, e, next) => {
    $.command.register({ name: 'newspeak', description: 'How many list items arrived with no success criterion' })
    return next(e)
  })

  on('command.run', { command: 'newspeak' }, async $ => {
    const c = await counts($)
    return { text: `${c.bare} of ${c.items} list items (in ${c.lists} lists) arrived with no success criterion.` }
  })

  on('prompt.submit', async ($, e, next) => {
    if (e.turnId) return next(e)
    const list = items(e.text)
    if (!list.length) return next(e)
    const bare = list.map((t, i) => ({ n: i + 1, t })).filter(x => !CRITERION.test(x.t))
    const c = await counts($)
    await $.store.set('counts', { lists: c.lists + 1, items: c.items + list.length, bare: c.bare + bare.length }).catch(() => undefined)
    if (!bare.length) return next(e)
    $.ui.status(`✎ ${bare.length} item${bare.length === 1 ? '' : 's'} without a criterion`)
    const note =
      'Newspeak: these items carry no success criterion, so they can be done confidently in the wrong direction. ' +
      'Before acting on them, ask the owner how each will be judged done (a command that passes, a value, an observable result):\n' +
      bare.map(x => `${x.n}. ${x.t}`).join('\n')
    return next({ ...e, context: [...(e.context ?? []), note] })
  })
}
