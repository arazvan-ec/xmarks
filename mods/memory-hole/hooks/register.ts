import type { Register } from 'claude-code'

const HELD = new Set(['Edit', 'Write', 'NotebookEdit'])
const LIST_FILE = /(\.plan\.md$|(^|\/)scratchpad\/|(^|\/)(tasks|todo)\.md$)/i
const NOTE =
  'Memory Hole: this prompt carries a list. Before any other edit, write it numbered to a file — ' +
  '.claude/flywheel/specs/<slug>.plan.md for cycle work, the scratchpad otherwise — and close it item by item from that file.'

let open = false

function isList(text: string): boolean {
  const plain = text.replace(/```[\s\S]*?```/g, '')
  const numbered = plain.match(/^\s*\d+[.)]\s+\S/gm)?.length ?? 0
  const bullets = plain.match(/^\s*[-*•]\s+\S/gm)?.length ?? 0
  return numbered >= 2 || bullets >= 3
}

function release($: any, why: string) {
  open = false
  $.ui.status(undefined)
  $.ui.toast(`Memory Hole ${why}.`)
}

export const register: Register = on => {
  open = false

  on('session.start', ($, e, next) => {
    $.command.register({ name: 'memory-hole', description: 'Memory Hole: `release` lets edits through without a list file (logged)' })
    return next(e)
  })

  on('command.run', { command: 'memory-hole' }, ($, e) => {
    if (e.args.trim() !== 'release') return { text: open ? 'A list is waiting to be written to a file.' : 'No list is being held.' }
    release($, 'released by hand — the list was not written to a file')
    return { text: 'Released.' }
  })

  on('prompt.submit', ($, e, next) => {
    if (e.turnId || !isList(e.text)) return next(e)
    open = true
    $.ui.status('🕳 list held — write it to a file first')
    return next({ ...e, context: [...(e.context ?? []), NOTE] })
  })

  on('tool.call', ($, e, next) => {
    if (!open || !HELD.has(e.tool)) return next(e)
    const a: any = e
    const path = String(a.file_path ?? a.notebook_path ?? '')
    if (e.tool !== 'NotebookEdit' && LIST_FILE.test(path)) {
      release($, `closed: the list lives in ${path}`)
      return next(e)
    }
    return {
      deny:
        `${$.plugin.name}: that list never existed until it is a file. Write it numbered to a .plan.md or the ` +
        `scratchpad first (or /memory-hole release).`,
    }
  })
}
