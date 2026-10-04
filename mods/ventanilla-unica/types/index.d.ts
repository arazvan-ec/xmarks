export type Stamp = { gate: string; verdict: 'PASS' | 'FAIL' | 'SKIPPED' }
export type Window = { stamps: Stamp[]; running: boolean; total?: string }

declare module 'claude-code' {
  interface PluginState {
    'ventanilla-unica': { window: Window }
  }
}
