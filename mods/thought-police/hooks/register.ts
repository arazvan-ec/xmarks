import type { Register } from 'claude-code'

const MIN_LINE = 12
const ECHO = 8
const FENCE = /```[^\n]*\n([\s\S]*?)```/g

let written = new Set<string>()

function lines(text: string): string[] {
  return text.split('\n').map(l => l.trim()).filter(l => l.length >= MIN_LINE)
}

function echoed(reply: string): number {
  let n = 0
  for (const m of reply.matchAll(FENCE)) for (const l of lines(m[1] ?? '')) if (written.has(l)) n++
  return n
}

export const register: Register = on => {
  written = new Set()

  on('prompt.submit', ($, e, next) => {
    if (!e.turnId) written = new Set()
    return next(e)
  })

  on('tool.call', async ($, e, next) => {
    const r = await next(e)
    if (r.deny !== undefined) return r
    const a: any = e
    const text = e.tool === 'Write' ? a.content : e.tool === 'Edit' ? a.new_string : undefined
    if (typeof text === 'string') for (const l of lines(text)) written.add(l)
    return r
  })

  on('classic.Stop', async ($, e, next) => {
    const r = await next(e)
    if (e.stop_hook_active || !e.last_assistant_message) return r
    const n = echoed(e.last_assistant_message)
    if (n < ECHO) return r
    $.ui.toast(`Thought Police: ${n} lines of this turn's code were pasted back into chat.`)
    return {
      ...r,
      block:
        `The reply repeats ${n} lines of code written this turn. The diff is already in git: ` +
        `report what and where (file:line), not the code. Rewrite the reply short.`,
    }
  })
}
