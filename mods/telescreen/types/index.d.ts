export type Slogan = { type: string; title: string; file: string }

declare module 'claude-code' {
  interface PluginState {
    telescreen: { slogan: Slogan | null; hidden: boolean }
  }
}
