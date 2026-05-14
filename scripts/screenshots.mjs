// ╔════════════════════════════════════════════════════════════════════════╗
// ║  The Company — screenshot capture                                       ║
// ║                                                                         ║
// ║  Captures the company's web UI into screenshots/ for the README.        ║
// ║  Run:  pnpm screenshots   (the web app must be running — pnpm dev)      ║
// ║                                                                         ║
// ║  Captures the public pages always. Pass a session token to also         ║
// ║  capture the signed-in dashboard:                                        ║
// ║    SHOT_AUTH_TOKEN=<supabase access token> pnpm screenshots             ║
// ╚════════════════════════════════════════════════════════════════════════╝
import { createRequire } from 'node:module';
import fs from 'node:fs';
import path from 'node:path';

const require = createRequire(import.meta.url);
const ROOT = path.resolve(import.meta.dirname, '..');
const OUT = path.join(ROOT, 'screenshots');
const BASE = process.env.SHOT_BASE_URL || 'http://localhost:3000';

// resolve playwright from anywhere in the workspace (pnpm doesn't link it
// into the root node_modules — it's a dependency of the tests package)
let chromium;
try {
  const resolved = require.resolve('playwright', {
    paths: [ROOT, path.join(ROOT, 'tests'), path.join(ROOT, 'apps', 'web')],
  });
  ({ chromium } = require(resolved));
} catch {
  console.error('playwright not found — run: pnpm install');
  process.exit(1);
}

// find a usable chromium: playwright's default, or a binary under
// PLAYWRIGHT_BROWSERS_PATH (handy on machines where the version is pinned).
function findChromium() {
  const root = process.env.PLAYWRIGHT_BROWSERS_PATH;
  if (!root || !fs.existsSync(root)) return undefined;
  for (const dir of fs.readdirSync(root)) {
    if (!dir.startsWith('chromium-')) continue;
    const p = path.join(root, dir, 'chrome-linux', 'chrome');
    if (fs.existsSync(p)) return p;
  }
  return undefined;
}

// fullPage:false captures just the 1440x900 viewport (good for hero/above-the-fold
// pages); fullPage:true captures the whole scrollable page (good for content pages).
const PUBLIC_PAGES = [
  { name: 'landing', url: '/',      wait: 3500, fullPage: false },
  { name: 'login',   url: '/auth',  wait: 3000, fullPage: false },
  { name: 'legal',   url: '/legal', wait: 3000, fullPage: true },
];
const AUTH_PAGES = [
  { name: 'dashboard', url: '/dashboard', wait: 5000, fullPage: true },
];

async function launch() {
  try {
    return await chromium.launch();
  } catch {
    const exe = findChromium();
    if (!exe) throw new Error(
      "couldn't launch Chromium. Install it with: pnpm exec playwright install chromium",
    );
    return await chromium.launch({ executablePath: exe });
  }
}

async function shoot(ctx, p) {
  const page = await ctx.newPage();
  const url = BASE + p.url;
  try {
    await page.goto(url, { waitUntil: 'networkidle', timeout: 45000 });
  } catch {
    try { await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 45000 }); }
    catch { console.log(`  ${p.name.padEnd(10)} SKIPPED (no response at ${url})`); await page.close(); return; }
  }
  await page.waitForTimeout(p.wait);
  const file = path.join(OUT, `${p.name}.png`);
  await page.screenshot({ path: file, fullPage: p.fullPage !== false });
  const kb = Math.round(fs.statSync(file).size / 1024);
  console.log(`  ${p.name.padEnd(10)} -> screenshots/${p.name}.png (${kb} KB)`);
  await page.close();
}

const main = async () => {
  fs.mkdirSync(OUT, { recursive: true });
  console.log(`Capturing ${BASE} ...`);
  const browser = await launch();
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });

  for (const p of PUBLIC_PAGES) await shoot(ctx, p);

  const token = process.env.SHOT_AUTH_TOKEN;
  if (token) {
    // seed the Supabase session so the signed-in dashboard renders
    await ctx.addInitScript((t) => {
      try {
        for (const k of Object.keys(localStorage)) {
          if (k.includes('-auth-token')) localStorage.removeItem(k);
        }
        localStorage.setItem('sb-access-token', t);
      } catch {}
    }, token);
    for (const p of AUTH_PAGES) await shoot(ctx, p);
  } else {
    console.log('  (set SHOT_AUTH_TOKEN to also capture the signed-in dashboard)');
  }

  await browser.close();
  console.log('Done.');
};

main().catch((e) => { console.error(String(e?.message || e)); process.exit(1); });
