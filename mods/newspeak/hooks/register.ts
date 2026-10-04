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
type Prose = { asks: number; kinds: Record<string, number>; recent: string[] }

// P77 step 1: count multi-item asks written as prose — measure, never nudge.
const PROSE: Record<string, RegExp> = {
  count: /\b(?:these|those|the|both|esos?|esas?|estos?|estas?|los|las)\s+\d+\b|\b\d+\s+(?:things|items|fixes|bugs|changes|steps|tasks|cosas|fallos|cambios|pasos|tareas|puntos)\b/i,
  quantifier: /\b(?:all of them|every one|each of|todas|todos|cada una?|ambos|ambas)\b/i,
  sequence: /\b(?:and then|after that|y luego|y después|después de eso|y a continuación)\b/i,
}

function items(text: string): string[] {
  const plain = text.replace(/```[\s\S]*?```/g, '')
  const found = plain.split('\n').map(l => ITEM.exec(l)).filter((m): m is RegExpExecArray => m !== null)
  const numbered = found.filter(m => m[1]).length
  const bullets = found.length - numbered
  return numbered >= 2 || bullets >= 3 ? found.map(m => (m[2] ?? '').trim()) : []
}

async function proseCount($: any, text: string) {
  const kinds = Object.entries(PROSE).filter(([, re]) => re.test(text)).map(([k]) => k)
  if (!kinds.length) return
  const p = ((await $.store.get('prose').catch(() => undefined)) as Prose | undefined) ?? { asks: 0, kinds: {}, recent: [] }
  for (const k of kinds) p.kinds[k] = (p.kinds[k] ?? 0) + 1
  p.asks += 1
  p.recent = [...p.recent, text.slice(0, 80)].slice(-20)
  await $.store.set('prose', p).catch(() => undefined)
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
    const p = ((await $.store.get('prose').catch(() => undefined)) as Prose | undefined)?.asks ?? 0
    return { text: `${c.bare} of ${c.items} list items (in ${c.lists} lists) arrived with no success criterion. ${p} prose multi-item ask${p === 1 ? '' : 's'} counted.` }
  })

  on('prompt.submit', async ($, e, next) => {
    if (e.turnId) return next(e)
    const list = items(e.text)
    if (!list.length) {
      await proseCount($, e.text.replace(/```[\s\S]*?```/g, ''))
      return next(e)
    }
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
