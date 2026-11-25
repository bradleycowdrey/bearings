// Turns the raw App Store captures (app-store.yml) into the listing's screenshots, in the Cowdrey family's template
// (scripts/store-frame.mjs, shared with Two Degrees, Cowdrey.MD and Cowdrey.PDF): Cowdrey One's Fraunces headline,
// an Instrument Sans sub-line, the same sizes and places on every app's pictures, the template's iPhone and iPad, and
// Bearings' sky-blue ground (THEMES.bearings). One story, one picture each:
//   1 Compass       Extra Large, the whole screen
//   2 Place & time  Small, the location bar lifted out of the screen
//   3 Elevation     Medium, the Elevation tile lifted out
//   4 Sun & moon    Large (iPhone) or Medium (iPad), the sun and moon tiles lifted out
//   5 Map           the map sheet; on iPhone zoomed on your heading, with the Maps credit moved inside the
//                   screen's safe area (it sits in the rounded corner in the raw capture)
//   6 Widgets       iPhone only: a Lock Screen with the Lock Screen widgets, the Large widget floating over it
// The screen is drawn first at the capture's own size (the capture itself, dimmed under a lifted element, the zoomed
// map, or the Lock Screen), then set in the template's device under the copy. A lifted element is the capture's own
// pixels, found by its edges (the black gaps around it), drawn a little larger right over where it is, so nothing
// shows twice; the app's pixels are never repainted.
//
// Usage: node scripts/store-frames.mjs --in <raw captures> --out <folder> [--date "Monday, November 9"]
// Raw captures (any that are missing skip their picture; a device without its -xl capture is skipped):
//   iphone-xl.png iphone-small.png iphone-medium.png iphone-large.png iphone-map.png   (6.9-inch, 1320 x 2868)
//   ipad-xl.png ipad-medium.png ipad-map.png                                            (13-inch, 2064 x 2752)
//   widget-large.png widget-lock-rectangular.png widget-lock-circular.png              (the iPhone self-test's)
// Writes iphone-1-compass.png … and ipad-1-compass.png … at the store sizes (1320 x 2868, 2064 x 2752), opaque RGB.
// --date is the Lock Screen's date line (default: today in Colorado, where the captures are taken).
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { THEMES, LAYOUT, frameHtml, rgbPng } from './store-frame.mjs';

const require = createRequire(import.meta.url);
let playwright;
try { playwright = require('playwright'); } catch {
  playwright = require(path.join(require('node:child_process').execSync('npm root -g').toString().trim(), 'playwright'));
}

const HERE = path.dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const opt = (name) => { const i = args.indexOf(name); return i >= 0 && i + 1 < args.length ? args[i + 1] : null; };
const IN = opt('--in'), OUT = opt('--out');
if (!IN || !OUT) { console.error('Usage: node scripts/store-frames.mjs --in <raw captures> --out <folder> [--date "Monday, November 9"]'); process.exit(2); }
const DATE = opt('--date') || new Intl.DateTimeFormat('en-US', { timeZone: 'America/Denver', weekday: 'long', month: 'long', day: 'numeric' }).format(new Date());
const THEME = THEMES.bearings;

// iPhone and iPad share the words. Every headline is two lines, so every iPhone picture's device sits at one height.
const STORY = [
  { id: 'compass', head: 'Get your\nbearings.', sub: 'A clear compass, true north or magnetic.', shot: 'xl' },
  { id: 'place', head: 'Know where.\nKnow when.', sub: 'The place you’re in, the date and the time.', shot: 'small', lift: ['bar'], phoneOnly: true },
  { id: 'elevation', head: 'Elevation in\nfeet and metres.', sub: 'With air pressure, from GPS or terrain.', shot: 'medium', lift: ['elevation'] },
  { id: 'sky', head: 'Your sky,\non one screen.', sub: 'Sunrise, sunset and the moon’s phase.', shot: { iphone: 'large', ipad: 'medium' }, lift: ['sun', 'moon'] },
  { id: 'map', head: 'See which\nway you face.', sub: 'A map with your heading on it.', shot: 'map', map: true },
  { id: 'widgets', head: 'Bearings,\nat a glance.', sub: 'On the Home Screen and the Lock Screen.', widgets: true, phoneOnly: true },
];
const LINES = 2;

// Where to start looking for each lifted element, as a fraction of the capture (x, y). The element itself
// is then found from there by its edges, so a few points of layout change don't matter.
const SEEDS = {
  iphone: { small: { bar: [0.5, 0.092] }, medium: { elevation: [0.73, 0.79] }, large: { sun: [0.18, 0.915], moon: [0.5, 0.915] } },
  ipad: { medium: { elevation: [0.7, 0.67], sun: [0.32, 0.745], moon: [0.7, 0.745] } },
};
const CAPTURE = { iphone: { W: 1320, H: 2868, pt: 3 }, ipad: { W: 2064, H: 2752, pt: 2 } };

const b64 = (f) => fs.readFileSync(path.join(HERE, 'store-fonts', f)).toString('base64');
const FONTS = { fraunces: b64('fraunces.woff2'), instrument: b64('instrument-sans.woff2') };
const dataURL = (buf) => `data:image/png;base64,${buf.toString('base64')}`;

// Where the template puts the screen on the canvas (scripts/store-frame.mjs, frameHtml), for laying things over it.
function screenBox(kind) {
  const L = LAYOUT[kind], W = L.canvas[0];
  const top = L.devTopOneLine && LINES === 1 ? L.devTopOneLine : L.devTop;
  const sw = L.screen[0] * L.s, sh = L.screen[1] * L.s, ow = sw + 2 * (L.bezel + L.band);
  return { x: (W - ow) / 2 + L.bezel + L.band, y: top + L.bezel + L.band, w: sw, h: sh, top };
}

// Runs in the page, at the capture's size: draws the screen and reports the lifted elements it found.
async function drawScreen(cfg) {
  const load = (src) => new Promise((ok, fail) => { const i = new Image(); i.onload = () => ok(i); i.onerror = fail; i.src = src; });
  const pixels = (img) => { const c = document.createElement('canvas'); c.width = img.naturalWidth; c.height = img.naturalHeight; const x = c.getContext('2d'); x.drawImage(img, 0, 0); return x.getImageData(0, 0, c.width, c.height); };
  const el = (tag, css, parent, html) => { const e = document.createElement(tag); e.style.cssText = css; if (html != null) e.innerHTML = html; if (parent) parent.appendChild(e); return e; };
  const { W: capW, H: capH, pt } = cfg.capture, root = document.body, f = cfg.frame;
  root.style.cssText = `margin:0;width:${capW}px;height:${capH}px;position:relative;overflow:hidden;background:#000`;

  // Pixels that aren't the screen's black background, and the element around a seed point (flood fill).
  function find(px, seed) {
    const { width: w, height: h, data } = px;
    const on = (x, y) => { const i = (y * w + x) * 4; return Math.max(data[i], data[i + 1], data[i + 2]) > 12; };
    let sx = Math.round(seed[0] * w), sy = Math.round(seed[1] * h);
    if (!on(sx, sy)) {   // nearest lit pixel within 60 px
      let best = null;
      for (let r = 1; r <= 60 && !best; r++) for (let dy = -r; dy <= r && !best; dy++) for (let dx = -r; dx <= r; dx++) {
        if (Math.max(Math.abs(dx), Math.abs(dy)) !== r) continue;
        const x = sx + dx, y = sy + dy;
        if (x >= 0 && y >= 0 && x < w && y < h && on(x, y)) { best = [x, y]; break; }
      }
      if (!best) return null;
      [sx, sy] = best;
    }
    const seen = new Uint8Array(w * h), stack = [sy * w + sx];
    let x0 = sx, x1 = sx, y0 = sy, y1 = sy; seen[sy * w + sx] = 1;
    while (stack.length) {
      const p = stack.pop(), x = p % w, y = (p - x) / w;
      if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y;
      for (const q of [p - 1, p + 1, p - w, p + w]) {
        const qx = q % w, qy = (q - qx) / w;
        if (q < 0 || q >= w * h || Math.abs(qx - x) > 1 || seen[q] || !on(qx, qy)) continue;
        seen[q] = 1; stack.push(q);
      }
    }
    // The corner radius, from how far the first lit pixel sits in from the left a few rows down.
    const t = 4; let i = 0; while (x0 + i < x1 && !on(x0 + i, y0 + t)) i++;
    const radius = Math.max(6, i + t + Math.sqrt(2 * i * t));
    // A tile or a bar, not half the screen (the layout changed and the seed fell somewhere else).
    if ((x1 - x0) * (y1 - y0) > w * h * 0.2) return null;
    return { x: x0, y: y0, w: x1 - x0 + 1, h: y1 - y0 + 1, radius };
  }

  // White glyphs on a plain backdrop, as white with alpha (for Lock Screen widgets and the Maps credit).
  function matte(img, rect, bgLum) {
    const c = document.createElement('canvas'); c.width = rect.w; c.height = rect.h;
    const x = c.getContext('2d'); x.drawImage(img, rect.x, rect.y, rect.w, rect.h, 0, 0, rect.w, rect.h);
    const d = x.getImageData(0, 0, rect.w, rect.h), a = d.data;
    let bg = bgLum;
    if (bg == null) {   // the median brightness of the border
      const v = [];
      for (let i = 0; i < rect.w; i++) for (const j of [0, rect.h - 1]) { const o = (j * rect.w + i) * 4; v.push(0.3 * a[o] + 0.59 * a[o + 1] + 0.11 * a[o + 2]); }
      v.sort((p, q) => p - q); bg = v[v.length >> 1];
    }
    for (let o = 0; o < a.length; o += 4) {
      const lum = 0.3 * a[o] + 0.59 * a[o + 1] + 0.11 * a[o + 2];
      const al = Math.max(0, Math.min(1, (lum - bg - 4) / (250 - bg))) * (a[o + 3] / 255);
      a[o] = a[o + 1] = a[o + 2] = 255; a[o + 3] = Math.round(al * 255);
    }
    x.putImageData(d, 0, 0);
    return c.toDataURL();
  }

  if (f.widgets) {
    // A Lock Screen with the Lock Screen widgets (white, as the Lock Screen tints them, on the wallpaper; no plate).
    const rect = await load(cfg.images.rect), circ = await load(cfg.images.circ);
    const c = root;
    // Wallpaper: dusk over the Maroon Bells.
    el('div', `position:absolute;inset:0;background:linear-gradient(180deg,#0C1730 0%,#1A3460 22%,#35629C 34%,#7F9FC4 40%,#D9AE8E 45%,#C4826A 49%,#5A4A5E 56%)`, c);
    el('div', `position:absolute;inset:0`, c, `<svg width="${capW}" height="${capH}" viewBox="0 0 440 956" preserveAspectRatio="none" style="position:absolute;inset:0">
      <path d="M0 440 L36 420 L70 392 L96 362 L112 372 L136 326 L156 346 L178 318 L200 352 L226 374 L256 360 L290 388 L326 380 L364 404 L404 396 L440 412 L440 956 L0 956 Z" fill="#2B3550"/>
      <path d="M136 326 L144 340 L139 348 L150 352 L156 346 Z M178 318 L186 334 L181 342 L193 346 L200 352 Z" fill="#EEF1F6" opacity=".8"/>
      <path d="M0 470 L60 448 L120 458 L180 438 L250 456 L320 442 L380 462 L440 452 L440 956 L0 956 Z" fill="#161D30"/></svg>`);
    // Status bar icons from a real capture (the Lock Screen has the big clock instead of the small time).
    if (cfg.images.status) {
      const st = await load(cfg.images.status), sx = Math.round(capW * 0.68), sy = 0, sW = capW - sx, sH = Math.round(54 * pt);
      const cv = document.createElement('canvas'); cv.width = sW; cv.height = sH; cv.getContext('2d').drawImage(st, sx, sy, sW, sH, 0, 0, sW, sH);
      el('img', `position:absolute;left:${sx}px;top:${sy}px;width:${sW}px;height:${sH}px;mix-blend-mode:screen`, c).src = cv.toDataURL();
    }
    el('div', `position:absolute;left:0;right:0;top:${68 * pt}px;text-align:center;font:600 ${22 * pt}px/1 var(--sans);color:rgba(255,255,255,.92)`, c, cfg.date);
    el('div', `position:absolute;left:0;right:0;top:${84 * pt}px;text-align:center;font:600 ${110 * pt}px/1 var(--sans);letter-spacing:-.02em;color:rgba(255,255,255,.95);font-variant-numeric:tabular-nums`, c, '9:41');
    const rw = 172 * pt, rh = 76 * pt, cd = 76 * pt, gap = 14 * pt, rowTop = 218 * pt, rowLeft = (capW - rw - gap - cd) / 2;
    const rectM = matte(rect, { x: 0, y: 0, w: rect.naturalWidth, h: rect.naturalHeight }, 31);
    const circM = matte(circ, { x: 0, y: 0, w: circ.naturalWidth, h: circ.naturalHeight }, 31);
    el('img', `position:absolute;left:${rowLeft}px;top:${rowTop}px;width:${rw}px;height:${rh}px;opacity:.94`, c).src = rectM;
    // The circular widget sits on the Lock Screen's own frosted disc (AccessoryWidgetBackground).
    el('div', `position:absolute;left:${rowLeft + rw + gap}px;top:${rowTop}px;width:${cd}px;height:${cd}px;border-radius:50%;background:rgba(255,255,255,.14)`, c);
    el('img', `position:absolute;left:${rowLeft + rw + gap}px;top:${rowTop}px;width:${cd}px;height:${cd}px;opacity:.94`, c).src = circM;
    return null;
  }

  const shot = await load(cfg.images.shot);
  el('img', `position:absolute;left:0;top:0;width:${capW}px;height:${capH}px;display:block`, root).src = cfg.images.shot;

  if (f.map && cfg.kind === 'iphone') {
    // Zoom the map (not the sheet's header or its buttons) on your position and heading, keep the buttons
    // where they are, and move the Maps credit up inside the safe area.
    const px = pixels(shot), P = pt;   // iPhone captures are @3x
    // The map starts where the sheet's header ends: the first row below the header that changes colour.
    const at = (x, y) => { const i = (y * capW + x) * 4; return [px.data[i], px.data[i + 1], px.data[i + 2]]; };
    let mapTop = Math.round(capH * 0.1);
    const hdr = at(Math.round(capW * 0.3), Math.round(capH * 0.09));
    for (let y = Math.round(capH * 0.09); y < capH * 0.2; y++) {
      const c = at(Math.round(capW * 0.3), y);
      if (Math.abs(c[0] - hdr[0]) + Math.abs(c[1] - hdr[1]) + Math.abs(c[2] - hdr[2]) > 24) { mapTop = y; break; }
    }
    // Your position: the white dot (the brightest round blob in the map, away from the buttons and credit).
    let sx = 0, sy = 0, n = 0;
    for (let y = mapTop + 20; y < capH - 140; y += 2) for (let x = 20; x < capW - 200; x += 2) {
      const c = at(x, y); if (c[0] > 235 && c[1] > 235 && c[2] > 235) { sx += x; sy += y; n++; }
    }
    const dot = n ? [sx / n, sy / n] : [capW / 2, (capH + mapTop) / 2];
    const z = 1.55, bw = capW, bh = capH - mapTop, ctrlW = 64 * P, ctrlH = 200 * P, credit = 46 * P;
    const dx = dot[0], dy = dot[1] - mapTop;
    // Put the dot a little above the middle (the roads and the lake lie below it), then keep the zoomed map covering
    // the box, drawn only from the map itself (not the credit band at the bottom or the button column at the top right).
    let tx = bw / 2, ty = bh * 0.38;
    // Prefer pushing the zoomed copy of the buttons off the right edge (the real ones stay on top).
    const noButtons = bw - z * (bw - ctrlW - dx);
    tx = Math.min(Math.max(tx, noButtons), z * dx); tx = Math.max(tx, bw - z * (bw - dx));
    ty = Math.min(ty, z * dy); ty = Math.max(ty, bh - z * (bh - credit - dy));
    const zoom = el('div', `position:absolute;left:0;top:${mapTop}px;width:${bw}px;height:${bh}px;overflow:hidden;
      -webkit-mask-image:linear-gradient(180deg, transparent ${ctrlH - 40}px, #000 ${ctrlH + 20}px), linear-gradient(90deg, #000 ${bw - ctrlW - 70}px, transparent ${bw - ctrlW + 6}px);
      -webkit-mask-composite:source-over`, root);
    el('img', `position:absolute;left:0;top:${-mapTop}px;width:${capW}px;height:${capH}px;transform-origin:${dx}px ${dot[1]}px;
      transform:translate(${tx - dx}px, ${ty - dy}px) scale(${z})`, zoom).src = cfg.images.shot;
    // The Maps credit: its own pixels as a white matte, inside the safe area.
    const cr = { x: 0, y: capH - 28 * P, w: 110 * P, h: 27 * P };
    el('img', `position:absolute;left:${14 * P}px;top:${capH - 34 * P - cr.h - 6 * P}px;width:${cr.w}px;height:${cr.h}px`, root).src = matte(shot, cr, null);
    return null;
  }

  if (f.lift && cfg.seeds) {
    const px = pixels(shot), parts = [];
    for (const name of f.lift) {
      const s = cfg.seeds[name], r = s && find(px, s);
      if (!r) throw new Error(`${cfg.kind} ${f.id}: no ${name} found from its seed (SEEDS in scripts/store-frames.mjs)`);
      parts.push(r);
    }
    el('div', `position:absolute;inset:0;background:rgba(0,0,0,.5)`, root);   // the rest of the screen, dimmed
    return parts;
  }
  return null;
}

// The lifted elements (the capture's own pixels) and the floating Large widget, laid over the template's frame.
function overlay(kind, frame, parts, images) {
  const L = LAYOUT[kind], W = L.canvas[0], C = CAPTURE[kind], scr = screenBox(kind), k = scr.w / C.W;
  if (frame.widgets) {
    // The Large widget a little larger than on a Home Screen, below the Lock Screen's clock and widgets.
    const [lw0, lh0] = images.largeSize, lw = scr.w * 0.83 * 1.1, lh = lh0 * lw / lw0;
    return `<img src="${images.large}" style="position:absolute;left:${(W - lw) / 2}px;top:${scr.y + scr.h * 0.5}px;width:${lw}px;height:${lh}px;
      filter:drop-shadow(0 40px 60px rgba(3,9,22,.55)) drop-shadow(0 0 1.5px rgba(255,255,255,.18))">`;
  }
  if (!parts) return '';
  const ux0 = Math.min(...parts.map((r) => r.x)), uy0 = Math.min(...parts.map((r) => r.y));
  const ux1 = Math.max(...parts.map((r) => r.x + r.w)), uy1 = Math.max(...parts.map((r) => r.y + r.h));
  const uw = ux1 - ux0, uh = uy1 - uy0;
  // About 1.2x, less for wide elements, and never closer than 44 px to the picture's edges.
  let s = Math.min(kind === 'iphone' ? 1.22 : 1.32, (W - 88) / (uw * k));
  if (uw > C.W * 0.7) s = Math.min(s, 1.07);
  const tiles = parts.map((r) => `<div style="position:absolute;left:${(r.x - ux0) * k}px;top:${(r.y - uy0) * k}px;width:${r.w * k}px;height:${r.h * k}px;
      border-radius:${r.radius * k}px;overflow:hidden;box-shadow:0 30px 60px rgba(2,6,16,.6),0 0 0 2px rgba(255,255,255,.16)">
      <img src="${images.shot}" style="position:absolute;left:${-r.x * k}px;top:${-r.y * k}px;width:${C.W * k}px;height:${C.H * k}px;max-width:none"></div>`).join('');
  return `<div style="position:absolute;left:${scr.x + ux0 * k}px;top:${scr.y + uy0 * k}px;width:${uw * k}px;height:${uh * k}px;transform:scale(${s});transform-origin:50% 50%">${tiles}</div>`;
}

// The template's compose (scripts/store-frame.mjs), with the overlay added after the device.
async function compose(browser, kind, story, extra) {
  const L = LAYOUT[kind], [W, H] = L.canvas;
  const ctx = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
  const p = await ctx.newPage();
  const html = frameHtml(kind, story, THEME, FONTS).replace(/<\/body>\s*<\/html>\s*$/, `${extra}\n</body></html>`);
  await p.setContent(html, { waitUntil: 'load' });
  await p.evaluate(() => document.fonts.ready);
  if (L.baseline) await p.waitForFunction(() => document.body.dataset.ready === '1');
  await p.waitForTimeout(200);
  const top = screenBox(kind).top;
  const box = await p.evaluate(() => { const r = document.querySelector('.copy').getBoundingClientRect(); return { top: r.top, bottom: r.bottom }; });
  if (box.bottom > top - 20) throw new Error(`${story.file}: the copy runs into the device (${Math.round(box.bottom)} > ${top - 20})`);
  if (box.top < 90) throw new Error(`${story.file}: the copy runs off the top (${Math.round(box.top)} < 90)`);
  const out = rgbPng(await p.screenshot({ type: 'png' }), THEME.base);
  await ctx.close();
  if (out.readUInt32BE(16) !== W || out.readUInt32BE(20) !== H || out[25] !== 2) throw new Error(`${story.file}: not a ${W}x${H} RGB PNG`);
  return out;
}

const has = (f) => fs.existsSync(path.join(IN, f));
const read = (f) => fs.readFileSync(path.join(IN, f));
fs.mkdirSync(OUT, { recursive: true });
const browser = await playwright.chromium.launch();
try {
  for (const kind of ['iphone', 'ipad']) {
    if (!has(`${kind}-xl.png`)) { console.log(`No ${kind}-xl.png: no ${kind} pictures`); continue; }
    const C = CAPTURE[kind];
    const page = await browser.newPage({ viewport: { width: C.W, height: C.H }, deviceScaleFactor: 1 });
    page.on('console', (m) => console.log(`  [${kind}] ${m.text()}`));
    let n = 1;
    for (const frame of STORY) {
      if (frame.phoneOnly && kind !== 'iphone') continue;
      const images = {};
      let seeds = null;
      if (frame.widgets) {
        const need = ['widget-large.png', 'widget-lock-rectangular.png', 'widget-lock-circular.png'];
        const missing = need.filter((f) => !has(f));
        if (missing.length) { console.log(`Skipping ${kind} ${frame.id}: no ${missing.join(', ')}`); continue; }
        const large = read(need[0]);
        [images.large, images.rect, images.circ] = [large, read(need[1]), read(need[2])].map(dataURL);
        images.largeSize = [large.readUInt32BE(16), large.readUInt32BE(20)];
        if (has(`${kind}-medium.png`)) images.status = dataURL(read(`${kind}-medium.png`));
      } else {
        const id = typeof frame.shot === 'string' ? frame.shot : frame.shot[kind];
        const file = `${kind}-${id}.png`;
        if (!has(file)) { console.log(`Skipping ${kind} ${frame.id}: no ${file}`); continue; }
        images.shot = dataURL(read(file));
        seeds = (SEEDS[kind] || {})[id] || null;
      }
      await page.setContent(`<!doctype html><html><head><meta charset="utf-8"><style>
        :root { --sans: -apple-system, "SF Pro Display", "SF Pro Text", Inter, "Helvetica Neue", Arial, sans-serif; }
        * { box-sizing: border-box; } body { -webkit-font-smoothing: antialiased; } img { display: block; }</style></head><body></body></html>`);
      const parts = await page.evaluate(drawScreen, { kind, capture: C, frame, images, seeds, date: DATE });
      await page.evaluate(() => document.fonts.ready);
      await page.waitForTimeout(200);
      const png = await page.screenshot({ type: 'png' });
      const name = `${kind}-${n}-${frame.id}.png`;
      const out = await compose(browser, kind, { head: frame.head, sub: frame.sub, png, file: name, lines: LINES }, overlay(kind, frame, parts, images));
      fs.writeFileSync(path.join(OUT, name), out);
      console.log('wrote', path.join(OUT, name));
      n++;
    }
    await page.close();
  }
} finally {
  await browser.close();
}
