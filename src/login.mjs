// xmarks — one-time login: capture your X (Twitter) session into auth.json.
//
//   npm run login
//
// A browser window opens on x.com. Log in normally (password, 2FA, whatever
// X asks). When you can see your home timeline, come back to this terminal and
// press Enter — your session is saved to auth.json (Playwright storageState).
// That file is gitignored; treat it as a secret. `npm run scrape` reuses it.

import { chromium } from 'playwright';
import { createInterface } from 'node:readline';

const AUTH_PATH = 'auth.json';

function launchOptions() {
  const opts = { headless: false }; // headed so you can log in
  if (process.env.PW_EXECUTABLE_PATH) opts.executablePath = process.env.PW_EXECUTABLE_PATH;
  if (process.env.PW_CHANNEL) opts.channel = process.env.PW_CHANNEL; // e.g. PW_CHANNEL=chrome
  return opts;
}

const browser = await chromium.launch(launchOptions());
const context = await browser.newContext();
const page = await context.newPage();
await page.goto('https://x.com/login', { waitUntil: 'domcontentloaded' });

console.log('\n👉 A browser window opened on X. Log in there.');
console.log('   Once you can see your timeline, come back here and press Enter to save the session.\n');

await new Promise((resolve) => {
  const rl = createInterface({ input: process.stdin, output: process.stdout });
  rl.question('Press Enter when you are logged in… ', () => { rl.close(); resolve(); });
});

await context.storageState({ path: AUTH_PATH });
console.log(`\n✅ Session saved to ${AUTH_PATH} (gitignored — keep it secret).`);
console.log('   Now run:  npm run scrape\n');

await browser.close();
