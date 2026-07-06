// xmarks — scrape your X (Twitter) bookmarks into data/bookmarks.{json,md}.
//
//   npm run login    # once, to save your session (auth.json)
//   npm run scrape   # extract all bookmarks
//
// How it works: it opens x.com/i/bookmarks with your saved session and listens
// for the internal GraphQL "Bookmarks" responses the page fires as it loads,
// scrolling until the bookmark count stops growing. This is far more robust
// than scraping the (constantly-changing) HTML. Raw payloads are kept in
// data/bookmarks.raw.json so parsing can be fixed without re-scraping.

import { chromium } from 'playwright';
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { parseBookmarks, toMarkdown } from './parse.mjs';

const AUTH_PATH = 'auth.json';
const OUT_DIR = 'data';
const BOOKMARKS_URL = 'https://x.com/i/bookmarks';
const MAX_SCROLLS = 2000;      // hard safety cap
const STABLE_STOP = 4;         // stop after N scrolls with no new bookmarks
const NAV_TIMEOUT = 60000;

function launchOptions() {
  const opts = { headless: !process.env.PW_HEADFUL };
  if (process.env.PW_EXECUTABLE_PATH) opts.executablePath = process.env.PW_EXECUTABLE_PATH;
  if (process.env.PW_CHANNEL) opts.channel = process.env.PW_CHANNEL;
  return opts;
}

await main();

async function main() {
  if (!existsSync(AUTH_PATH)) {
    console.error(`\n✖ No ${AUTH_PATH} found. Run "npm run login" first to save your X session.\n`);
    process.exitCode = 1;
    return;
  }
  mkdirSync(OUT_DIR, { recursive: true });

  const browser = await chromium.launch(launchOptions());
  try {
    const context = await browser.newContext({ storageState: AUTH_PATH });
    const page = await context.newPage();

    // Capture raw GraphQL Bookmarks responses as the page fires them.
    const rawResponses = [];
    page.on('response', async (resp) => {
      const url = resp.url();
      if (url.includes('/graphql/') && /\/Bookmarks(\b|\?|$)/.test(url)) {
        try { rawResponses.push(await resp.json()); } catch { /* not JSON — ignore */ }
      }
    });

    console.log('→ Opening bookmarks…');
    try {
      await page.goto(BOOKMARKS_URL, { waitUntil: 'domcontentloaded', timeout: NAV_TIMEOUT });
    } catch (e) {
      console.error(`\n✖ Couldn't open ${BOOKMARKS_URL}: ${String(e.message).split('\n')[0]}`);
      console.error('  Check your internet connection and try again.\n');
      process.exitCode = 3;
      return;
    }
    await page.waitForTimeout(3000);

    // Detect a missing/expired session (X bounces to a login/signup flow).
    if (/\/login|\/i\/flow\/login|\/i\/flow\/signup/.test(page.url())) {
      console.error('\n✖ Not logged in (session missing or expired). Re-run "npm run login".\n');
      process.exitCode = 2;
      return;
    }

    // Scroll until the unique bookmark count stops growing.
    let lastCount = -1;
    let stable = 0;
    for (let i = 0; i < MAX_SCROLLS && stable < STABLE_STOP; i++) {
      await page.evaluate(() => window.scrollBy(0, 3000));
      await page.waitForTimeout(1000);
      const count = parseBookmarks(rawResponses).length;
      if (count === lastCount) stable++;
      else { stable = 0; lastCount = count; }
      if (i % 10 === 0) console.log(`  …${count} bookmarks so far`);
    }
    await page.waitForTimeout(1000);

    const bookmarks = parseBookmarks(rawResponses);
    console.log(`✓ Captured ${bookmarks.length} bookmarks from ${rawResponses.length} API responses.`);

    writeFileSync(`${OUT_DIR}/bookmarks.raw.json`, JSON.stringify(rawResponses, null, 2));
    writeFileSync(`${OUT_DIR}/bookmarks.json`, JSON.stringify(bookmarks, null, 2));
    writeFileSync(`${OUT_DIR}/bookmarks.md`, toMarkdown(bookmarks));
    console.log(`✓ Wrote ${OUT_DIR}/bookmarks.json, ${OUT_DIR}/bookmarks.md, ${OUT_DIR}/bookmarks.raw.json`);

    if (bookmarks.length === 0) {
      console.warn(
        '\n⚠ 0 bookmarks parsed. Either you have none, or X changed its GraphQL shape.\n' +
        `   Inspect ${OUT_DIR}/bookmarks.raw.json and adjust the parser in src/parse.mjs.\n`
      );
    }
  } finally {
    await browser.close();
  }
}
