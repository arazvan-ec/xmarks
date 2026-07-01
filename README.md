# xmarks

Export your **X (Twitter) bookmarks** to local files (`data/bookmarks.json` + `data/bookmarks.md`) using your own logged-in browser session — no API keys, no paid tier, no database.

It drives a real browser with Playwright, opens your bookmarks, and captures X's internal GraphQL responses as the page loads (robust to HTML/CSS changes). You run it on **your** machine, so your session and IP are yours — nothing is pasted into a cloud service.

## Setup

Requires Node 18+.

```bash
npm install
npx playwright install chromium
```

## Use

```bash
npm run login     # opens a browser — log in to X, then press Enter to save the session
npm run scrape    # extracts all your bookmarks
```

Outputs (in `data/`):
- `bookmarks.json` — clean records: `id`, `author_handle`, `author_name`, `text`, `url`, `created_at`, `media`, `urls`.
- `bookmarks.md` — a readable list to skim.
- `bookmarks.raw.json` — the raw API payloads (gitignored), so the parser can be fixed without re-scraping.

Re-run `npm run scrape` anytime to refresh. If it says you're not logged in, your session expired — just `npm run login` again.

### Options (env vars)
- `PW_HEADFUL=1` — watch the browser while it scrapes (default is headless).
- `PW_CHANNEL=chrome` — use your installed Google Chrome instead of Playwright's Chromium.
- `PW_EXECUTABLE_PATH=/path/to/chrome` — point at a specific browser binary.

## Security

`auth.json` holds your X session and is **gitignored** — never commit it. It grants access to your account; if you want to invalidate it, log out of that session on X. `data/bookmarks.json`/`.md` contain your own bookmark contents — this is a private repo, but decide for yourself whether to commit them.

## Notes

Scraping your own bookmarks is a personal, non-commercial use of your own data, but it relies on X's private endpoints and is against X's ToS in the strict sense — keep it personal and don't hammer it. If X changes its GraphQL shape and parsing breaks, the raw payloads in `data/bookmarks.raw.json` let you fix `src/scrape.mjs` without re-fetching.

---

This repo also hosts **flywheel**, a Claude Code plugin for disciplined AI-assisted development (see `flywheel/` and the marketplace at `.claude-plugin/marketplace.json`).
