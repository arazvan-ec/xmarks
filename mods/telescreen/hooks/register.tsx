import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import type { Slogan } from '../types'

const LEDGER = '.claude/flywheel/LEARNINGS.md'
const HEAD = /^## ([a-z-]+): (.+)$/
const FILES = /files=([^;]+)/
const slogan = atom({ plugin: 'telescreen', key: 'slogan' } as const, null)
const hidden = atom({ plugin: 'telescreen', key: 'hidden' } as const, false)

type Lesson = { type: string; title: string; files: string[] }
let lessons: Lesson[] | undefined
let shown = new Set<string>()

async function ledger($: any): Promise<Lesson[]> {
  if (lessons) return lessons
  const text = String(await $.fs.read(LEDGER).catch(() => ''))
  const out: Lesson[] = []
  for (const line of text.split('\n')) {
    const h = HEAD.exec(line)
    if (h) out.push({ type: h[1] ?? '', title: (h[2] ?? '').trim(), files: [] })
    const f = FILES.exec(line)
    const last = out[out.length - 1]
    if (f && last && !last.files.length) last.files = (f[1] ?? '').split(',').map(s => s.trim()).filter(Boolean)
  }
  return (lessons = out)
}

function cites(l: Lesson, path: string): string | undefined {
  return l.files.find(f => path === f || path.endsWith(`/${f}`))
}

async function watch($: any, path: string) {
  const all = await ledger($)
  for (let i = all.length - 1; i >= 0; i--) {
    const l = all[i]
    const file = l && cites(l, path)
    if (!l || !file) continue
    const prev = await read($, slogan)
    if (prev?.title === l.title) return
    shown.add(l.title)
    await update($, slogan, () => ({ type: l.type, title: l.title, file }))
    await update($, hidden, () => false)
    return
  }
}

export const register: Register = on => {
  lessons = undefined
  shown = new Set()

  on('session.start', ($, e, next) => {
    $.command.register({ name: 'telescreen', description: 'What the Telescreen has shown: lessons loaded, slogans this session' })
    return next(e)
  })

  on('command.run', { command: 'telescreen' }, async $ => {
    const n = (await ledger($)).length
    return { text: `${n} lessons loaded from ${LEDGER}; ${shown.size} slogans shown this session.` }
  })

  on('tool.call', async ($, e, next) => {
    const r = await next(e)
    const a: any = e
    if (r.deny === undefined && (e.tool === 'Read' || e.tool === 'Edit' || e.tool === 'Write') && a.file_path) await watch($, String(a.file_path))
    return r
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const s: Slogan | null = await read($, slogan)
    if (!s || (await read($, hidden))) return next(e)
    const { Box, Button, Text } = $.ui.resolve(e)
    return (
      <Box>
        <Text color="magenta">
          📺 {s.type.toUpperCase()} · {s.title} — {s.file}{' '}
        </Text>
        <Button key="hide" label="Hide" onPress={() => update($, hidden, () => true)} />
      </Box>
    )
  })
}
