// Turns the raw App Store captures (app-store.yml) into the listing's screenshots on the Cowdrey family standard:
// every picture is made by scripts/app-store/store-frame.mjs, a word-for-word copy of the family template (the
// master is design/app-store/store-frame.mjs in bradleycowdrey/cowdrey-one; never edit the copy here), with
// Bearings' theme: a Fraunces headline and an Instrument Sans sub-line above the real app, in dark mode, in a
// plain iPhone or iPad. One story, one picture each:
//   1 Compass       Extra Large
//   2 Place & time  Small (iPhone only)
//   3 Elevation     Medium
//   4 Sun & moon    Large (on iPad, Medium if there is no ipad-large.png)
//   5 Map           the map sheet
//   6 Widgets       iPhone only: a Lock Screen drawn here, with the clock, the Lock Screen widgets and the Large
//                   widget as the self-test draws them (there is no way to put widgets on a Simulator's screens)
//
// Usage: node scripts/store-frames.mjs --in <raw captures> --out <folder> [--date "Tuesday, November 24"]
// Raw captures (any that are missing skip their picture; a device without its -xl capture is skipped):
//   iphone-xl.png iphone-small.png iphone-medium.png iphone-large.png iphone-map.png   (6.9-inch, 1320 x 2868)
//   ipad-xl.png ipad-medium.png ipad-large.png ipad-map.png                             (13-inch, 2064 x 2752)
//   widget-large.png widget-lock-rectangular.png widget-lock-circular.png              (the iPhone self-test's)
// Writes iphone-1-compass.png … and ipad-1-compass.png … as opaque RGB PNGs at the store sizes.
// --date is the Lock Screen's date line (default: today in Colorado, where the captures are taken).
import fs from 'node:fs';
import path from 'node:path';
import { execSync } from 'node:child_process';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { compose, frameHtml, LAYOUT, THEMES } from './app-store/store-frame.mjs';

const require = createRequire(import.meta.url);
let playwright;
try { playwright = require('playwright'); } catch { playwright = require(path.join(execSync('npm root -g').toString().trim(), 'playwright')); }

const args = process.argv.slice(2);
const opt = (name) => { const i = args.indexOf(name); return i >= 0 && i + 1 < args.length ? args[i + 1] : null; };
const IN = opt('--in'), OUT = opt('--out');
if (!IN || !OUT) { console.error('Usage: node scripts/store-frames.mjs --in <raw captures> --out <folder> [--date "Tuesday, November 24"]'); process.exit(2); }
const DATE = opt('--date') || new Intl.DateTimeFormat('en-US', { timeZone: 'America/Denver', weekday: 'long', month: 'long', day: 'numeric' }).format(new Date());

// Headlines are two lines on iPhone and one on iPad (every headline in a set has the same number of lines).
const STORY = [
  { id: 'compass', head: ['Get your', 'bearings.'], sub: 'A clear compass, true north or magnetic.', shot: 'xl' },
  { id: 'place', head: ['Know where.', 'Know when.'], sub: 'The place you’re in, the date and the time.', shot: 'small', phoneOnly: true },
  { id: 'elevation', head: ['Elevation in', 'feet and metres.'], sub: 'With air pressure, from GPS or terrain.', shot: 'medium' },
  { id: 'sky', head: ['Your sky,', 'on one screen.'], sub: 'Sunrise, sunset and the moon’s phase.', shot: 'large', fallback: 'medium' },
  { id: 'map', head: ['See which', 'way you face.'], sub: 'A map with your heading on it.', shot: 'map' },
  { id: 'widgets', head: ['Bearings,', 'at a glance.'], sub: 'On the Home Screen and the Lock Screen.', widgets: true, phoneOnly: true },
];
const LINES = { iphone: 2, ipad: 1 };

const here = path.dirname(fileURLToPath(import.meta.url));
const FONTS = {
  fraunces: fs.readFileSync(path.join(here, 'app-store/fraunces.woff2')).toString('base64'),
  instrument: fs.readFileSync(path.join(here, 'app-store/instrument-sans.woff2')).toString('base64'),
};
const has = (f) => fs.existsSync(path.join(IN, f));
const raw = (f) => fs.readFileSync(path.join(IN, f));
const dataURL = (buf) => `data:image/png;base64,${buf.toString('base64')}`;

// The template keeps the copy clear of the device; this also checks the set's line count, so a headline that
// wraps on its own (or a sub-line that wraps twice) stops the run instead of shifting one picture.
async function checkLines(browser, kind, story) {
  const [W, H] = LAYOUT[kind].canvas;
  const page = await browser.newPage({ viewport: { width: W, height: H } });
  await page.setContent(frameHtml(kind, story, THEMES.bearings, FONTS));
  await page.evaluate(() => document.fonts.ready);
  const n = await page.evaluate(() => {
    const lines = (e) => Math.round(e.getBoundingClientRect().height / parseFloat(getComputedStyle(e).lineHeight));
    return { head: lines(document.querySelector('h1')), sub: lines(document.querySelector('p')) };
  });
  await page.close();
  if (n.head !== story.lines) throw new Error(`${story.file}: the headline takes ${n.head} lines, not ${story.lines}`);
  if (n.sub > 2) throw new Error(`${story.file}: the sub-line takes ${n.sub} lines`);
}

// The widgets picture's screen, at the iPhone capture's size (440 x 956 pt at 3x): a Lock Screen with dusk over the
// Maroon Bells, the status bar icons from a real capture, the date and the clock, the Lock Screen widgets under the
// clock (white, as the Lock Screen tints them, on the wallpaper; the circular one on its frosted disc) and the Large
// widget below them, all as the self-test draws them for the store sample.
async function lockScreen(browser, status) {
  const W = 1320, H = 2868, P = 3;
  const large = raw('widget-large.png'), rect = raw('widget-lock-rectangular.png'), circ = raw('widget-lock-circular.png');
  const rw = 172 * P, rh = 76 * P, cd = 76 * P, gap = 14 * P, rowTop = 218 * P, rowLeft = (W - rw - gap - cd) / 2;
  const lw = 364 * P, lh = 382 * P, lTop = 326 * P;
  const html = `<!doctype html><html><head><meta charset="utf-8"><style>
    * { margin: 0; box-sizing: border-box; }
    html, body { width: ${W}px; height: ${H}px; overflow: hidden; background: #0C1730; -webkit-font-smoothing: antialiased; }
    body { position: relative; font-family: -apple-system, "SF Pro Display", Inter, "Helvetica Neue", Arial, sans-serif; color: #fff; }
    .abs { position: absolute; }
  </style></head><body>
  <svg class="abs" style="inset:0" width="${W}" height="${H}" viewBox="0 0 440 956">
    <defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#0C1730"/><stop offset=".40" stop-color="#1A3460"/><stop offset=".62" stop-color="#35629C"/>
      <stop offset=".74" stop-color="#7F9FC4"/><stop offset=".81" stop-color="#D9AE8E"/><stop offset=".86" stop-color="#C4826A"/>
      <stop offset=".93" stop-color="#5A4A5E"/></linearGradient></defs>
    <rect width="440" height="956" fill="url(#sky)"/>
    <g transform="translate(0 420)">
      <path d="M0 440 L36 420 L70 392 L96 362 L112 372 L136 326 L156 346 L178 318 L200 352 L226 374 L256 360 L290 388 L326 380 L364 404 L404 396 L440 412 L440 536 L0 536 Z" fill="#2B3550"/>
      <path d="M136 326 L144 340 L139 348 L150 352 L156 346 Z M178 318 L186 334 L181 342 L193 346 L200 352 Z" fill="#EEF1F6" opacity=".8"/>
      <path d="M0 470 L60 448 L120 458 L180 438 L250 456 L320 442 L380 462 L440 452 L440 536 L0 536 Z" fill="#161D30"/>
    </g>
  </svg>
  <div class="abs" style="left:${Math.round(W * 0.68)}px;top:0;width:${W - Math.round(W * 0.68)}px;height:${54 * P}px;mix-blend-mode:screen;
    background:url(${dataURL(status)}) ${-Math.round(W * 0.68)}px 0 / ${W}px ${H}px no-repeat"></div>
  <div class="abs" style="left:0;right:0;top:${68 * P}px;text-align:center;font-weight:600;font-size:${22 * P}px;line-height:1;color:rgba(255,255,255,.92)">${DATE}</div>
  <div class="abs" style="left:0;right:0;top:${84 * P}px;text-align:center;font-weight:600;font-size:${110 * P}px;line-height:1;letter-spacing:-.02em;color:rgba(255,255,255,.95);font-variant-numeric:tabular-nums">9:41</div>
  <canvas id="rect" class="abs" style="left:${rowLeft}px;top:${rowTop}px;width:${rw}px;height:${rh}px;opacity:.94"></canvas>
  <div class="abs" style="left:${rowLeft + rw + gap}px;top:${rowTop}px;width:${cd}px;height:${cd}px;border-radius:50%;background:rgba(255,255,255,.14)"></div>
  <canvas id="circ" class="abs" style="left:${rowLeft + rw + gap}px;top:${rowTop}px;width:${cd}px;height:${cd}px;opacity:.94"></canvas>
  <img id="large" class="abs" style="left:${(W - lw) / 2}px;top:${lTop}px;width:${lw}px;height:${lh}px;filter:drop-shadow(0 ${10 * P}px ${18 * P}px rgba(3,9,22,.45))" src="${dataURL(large)}">
  <script>
    // White glyphs on the self-test's plain plate, as white with alpha.
    function matte(id, src, bg) {
      return new Promise((ok) => { const i = new Image(); i.onload = () => {
        const c = document.getElementById(id); c.width = i.naturalWidth; c.height = i.naturalHeight;
        const x = c.getContext('2d'); x.drawImage(i, 0, 0);
        const d = x.getImageData(0, 0, c.width, c.height), a = d.data;
        for (let o = 0; o < a.length; o += 4) {
          const lum = 0.3 * a[o] + 0.59 * a[o + 1] + 0.11 * a[o + 2];
          const al = Math.max(0, Math.min(1, (lum - bg - 4) / (250 - bg))) * (a[o + 3] / 255);
          a[o] = a[o + 1] = a[o + 2] = 255; a[o + 3] = Math.round(al * 255);
        }
        x.putImageData(d, 0, 0); ok(); }; i.src = src; });
    }
    Promise.all([matte('rect', '${dataURL(rect)}', 31), matte('circ', '${dataURL(circ)}', 31), document.getElementById('large').decode(), document.fonts.ready])
      .then(() => { document.body.dataset.ready = '1'; });
  </script></body></html>`;
  const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
  await page.setContent(html);
  await page.waitForFunction(() => document.body.dataset.ready === '1');
  await page.waitForTimeout(200);
  const png = await page.screenshot({ type: 'png' });
  await page.close();
  return png;
}

fs.mkdirSync(OUT, { recursive: true });
const browser = await playwright.chromium.launch(fs.existsSync('/opt/pw-browsers/chromium') ? { executablePath: '/opt/pw-browsers/chromium' } : {});
try {
  for (const kind of ['iphone', 'ipad']) {
    if (!has(`${kind}-xl.png`)) { console.log(`No ${kind}-xl.png: no ${kind} pictures`); continue; }
    let n = 1;
    for (const s of STORY) {
      if (s.phoneOnly && kind !== 'iphone') continue;
      let png;
      if (s.widgets) {
        const missing = ['widget-large.png', 'widget-lock-rectangular.png', 'widget-lock-circular.png'].filter((f) => !has(f));
        if (missing.length) { console.log(`Skipping ${kind} ${s.id}: no ${missing.join(', ')}`); continue; }
        png = await lockScreen(browser, raw(has(`${kind}-medium.png`) ? `${kind}-medium.png` : `${kind}-xl.png`));
      } else {
        let file = `${kind}-${s.shot}.png`;
        if (!has(file) && s.fallback && has(`${kind}-${s.fallback}.png`)) {
          console.log(`::warning::No ${file}: ${kind} ${s.id} uses ${kind}-${s.fallback}.png`);
          file = `${kind}-${s.fallback}.png`;
        }
        if (!has(file)) { console.log(`Skipping ${kind} ${s.id}: no ${file}`); continue; }
        png = raw(file);
      }
      const out = `${kind}-${n}-${s.id}.png`;
      const story = { head: s.head.join(LINES[kind] === 1 ? ' ' : '\n'), sub: s.sub, png, title: 'Bearings', lines: LINES[kind], file: out };
      await checkLines(browser, kind, story);
      fs.writeFileSync(path.join(OUT, out), await compose(browser, kind, story, THEMES.bearings, FONTS));
      console.log('wrote', path.join(OUT, out));
      n++;
    }
  }
} finally {
  await browser.close();
}
