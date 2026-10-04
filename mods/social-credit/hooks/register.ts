import type { Register } from 'claude-code'

const START = 100
const THRESHOLD = 80
const RULES: Record<string, string> = {
  'edit over rewrite': 'Change the lines that change: Edit, never a Write over a file you have read.',
  'test-first': 'Every scripts/<name>.sh moves with scripts/test-<name>.sh, and the test is written first.',
  'no silent skips': 'No SKIP_* override and no --no-verify without a stated reason the owner can read.',
}

type Act = { points: number; rule: string; what: string }
let score: number | undefined
let broken: string[] = []
let acts: Act[] = []
let read = new Set<string>()
let touched = new Set<string>()

async function load($: any) {
  if (score !== undefined) return
  score = ((await $.store.get('score').catch(() => undefined)) as number | undefined) ?? START
  broken = ((await $.store.get('broken').catch(() => undefined)) as string[] | undefined) ?? []
}

async function grade($: any, points: number, rule: string, what: string) {
  await load($)
  score = (score ?? START) + points
  acts = [...acts, { points, rule, what }].slice(-30)
  if (points < 0 && !broken.includes(rule)) broken = [...broken, rule].sort()
  await $.store.set('score', score).catch(() => undefined)
  await $.store.set('broken', broken).catch(() => undefined)
  $.ui.status(`🪪 citizen score ${score}${score < THRESHOLD ? ' · under re-education' : ''}`)
}

function script(path: string): { name: string; isTest: boolean } | undefined {
  const m = /(?:^|\/)scripts\/(test-)?([a-z0-9._-]+)\.sh$/.exec(path)
  return m ? { name: m[2] ?? '', isTest: Boolean(m[1]) } : undefined
}

export const register: Register = on => {
  score = undefined
  broken = []
  acts = []
  read = new Set()
  touched = new Set()

  on('session.start', async ($, e, next) => {
    $.command.register({ name: 'social-credit', description: 'Your citizen score and recent acts; `amnesty` resets it to 100' })
    return next(e)
  })

  on('command.run', { command: 'social-credit' }, async ($, e) => {
    await load($)
    if (e.args.trim() === 'amnesty') {
      score = START
      broken = []
      await $.store.set('score', score).catch(() => undefined)
      await $.store.set('broken', broken).catch(() => undefined)
      $.ui.status(`🪪 citizen score ${score}`)
      return { text: 'Amnesty granted. Score restored to 100.' }
    }
    const rows = acts.map(a => `  ${a.points > 0 ? '+' : ''}${a.points}  ${a.rule} — ${a.what}`)
    return { text: [`Citizen score: ${score}`, ...(rows.length ? rows : ['  no acts recorded this session'])].join('\n') }
  })

  on('tool.call', async ($, e, next) => {
    const r = await next(e)
    if (r.deny !== undefined) return r
    const a: any = e
    const path = String(a.file_path ?? '')
    if (e.tool === 'Read') read.add(path)
    if (e.tool === 'Edit') await grade($, 1, 'edit over rewrite', path)
    if (e.tool === 'Write' && read.has(path)) await grade($, -5, 'edit over rewrite', path)
    const s = (e.tool === 'Edit' || e.tool === 'Write') && script(path)
    if (s) {
      if (!s.isTest) await grade($, touched.has(`test-${s.name}`) ? 3 : -3, 'test-first', path)
      touched.add(s.isTest ? `test-${s.name}` : s.name)
    }
    if (e.tool === 'Bash') {
      const c = String(a.command ?? '')
      if (/\bgit\s+commit\b/.test(c)) await grade($, 1, 'evidence lands in git', c.slice(0, 40))
      if (/\bSKIP_[A-Z_]+=|--no-verify\b/.test(c)) await grade($, -10, 'no silent skips', c.slice(0, 40))
    }
    return r
  })

  on('prompt.compose', async ($, e, next) => {
    const r = await next(e)
    await load($)
    if ((score ?? START) >= THRESHOLD || !broken.length) return r
    const text = ['Re-education. The record shows these rules broken; keep them from now on:', ...broken.map(b => `- ${b}: ${RULES[b] ?? b}`)].join('\n')
    return { ...r, sections: [...r.sections, { id: 'social-credit:re-education', text, scope: 'session' as const }] }
  })
}
