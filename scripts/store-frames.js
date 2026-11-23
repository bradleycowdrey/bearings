// Turns the raw App Store captures (app-store.yml) into the listing's screenshots: on the Bearings sky, a
// small uppercase category line, a Fraunces headline and a one-line subhead above the real capture in a
// drawn iPhone (titanium rim, black bezel, Dynamic Island) or iPad. One story, one frame each:
//   1 Compass       Extra Large, the whole screen
//   2 Place & time  Small, the location bar lifted out of the screen
//   3 Elevation     Medium, the Elevation tile lifted out
//   4 Sun & moon    Large (iPhone) or Medium (iPad), the sun and moon tiles lifted out
//   5 Map           the map sheet; on iPhone zoomed on your heading, with the Maps credit moved inside the
//                   screen's safe area (it sits in the rounded corner in the raw capture)
//   6 Widgets       iPhone only: the Large widget and a Lock Screen with the Lock Screen widgets
// A lifted element is the capture's own pixels, found by its edges (the black gaps around it), drawn a
// little larger right over where it is, with the rest of the screen dimmed, so nothing shows twice.
//
// Usage: node scripts/store-frames.js --in <raw captures> --out <folder> [--strip <file.png>] [--date "Monday, November 9"]
// Raw captures (any that are missing skip their frame; a device without its -xl capture is skipped):
//   iphone-xl.png iphone-small.png iphone-medium.png iphone-large.png iphone-map.png   (6.9-inch, 1320 x 2868)
//   ipad-xl.png ipad-medium.png ipad-map.png                                            (13-inch, 2064 x 2752)
//   widget-large.png widget-lock-rectangular.png widget-lock-circular.png              (the iPhone self-test's)
// Writes iphone-1-compass.png … and ipad-1-compass.png … at the store sizes (1320 x 2868, 2064 x 2752).
// --date is the Lock Screen's date line (default: today in Colorado, where the captures are taken).
const path = require('path');
const fs = require('fs');
let playwright;
try { playwright = require('playwright'); } catch { playwright = require(path.join(require('child_process').execSync('npm root -g').toString().trim(), 'playwright')); }

const args = process.argv.slice(2);
const opt = (name) => { const i = args.indexOf(name); return i >= 0 && i + 1 < args.length ? args[i + 1] : null; };
const IN = opt('--in'), OUT = opt('--out'), STRIP = opt('--strip');
if (!IN || !OUT) { console.error('Usage: node scripts/store-frames.js --in <raw captures> --out <folder> [--strip <file.png>] [--date "Monday, November 9"]'); process.exit(2); }
const DATE = opt('--date') || new Intl.DateTimeFormat('en-US', { timeZone: 'America/Denver', weekday: 'long', month: 'long', day: 'numeric' }).format(new Date());

const STORY = [
  { id: 'compass', eyebrow: 'Compass', head: ['Get your', 'bearings.'], sub: 'A clear compass, true north or magnetic.', shot: 'xl' },
  { id: 'place', eyebrow: 'Place & time', head: ['Know where.', 'Know when.'], sub: 'The place you’re in, the date and the time.', shot: 'small', lift: ['bar'], phoneOnly: true },
  { id: 'elevation', eyebrow: 'Elevation', head: ['Elevation in', 'feet and metres.'], sub: 'With air pressure, from GPS or terrain.', shot: 'medium', lift: ['elevation'] },
  { id: 'sky', eyebrow: 'Sun & moon', head: ['Your sky,', 'on one screen.'], sub: 'Sunrise, sunset and the moon’s phase.', shot: { iphone: 'large', ipad: 'medium' }, lift: ['sun', 'moon'] },
  { id: 'map', eyebrow: 'Map', head: ['See which', 'way you face.'], sub: 'A map with your heading on it.', shot: 'map', map: true },
  { id: 'widgets', eyebrow: 'Widgets', head: ['Bearings,', 'at a glance.'], sub: 'On the Home Screen and the Lock Screen.', widgets: true, phoneOnly: true },
];

// Where to start looking for each lifted element, as a fraction of the capture (x, y). The element itself
// is then found from there by its edges, so a few points of layout change don't matter.
const SEEDS = {
  iphone: { small: { bar: [0.5, 0.092] }, medium: { elevation: [0.73, 0.79] }, large: { sun: [0.18, 0.915], moon: [0.5, 0.915] } },
  ipad: { medium: { elevation: [0.7, 0.67], sun: [0.32, 0.745], moon: [0.7, 0.745] } },
};

const DEVICES = {
  // iPhone 6.9-inch: the screen's corner radius is 62 pt; the Dynamic Island 126 x 37 pt, 11 pt from the top.
  iphone: { W: 1320, H: 2868, pt: 3, body: 1024, top: 640, inset: 0.036, rim: 0.011, radiusPt: 62, island: true },
  // iPad 13-inch: 18 pt screen corners, an even black bezel, the front camera on the long (right) edge.
  ipad: { W: 2064, H: 2752, pt: 2, body: 1560, top: 600, inset: 0.03, rim: 0.0065, radiusPt: 18, island: false },
};

const dataURL = (file) => `data:image/${file.endsWith('.woff2') ? 'font/woff2' : 'png'};base64,${fs.readFileSync(file).toString('base64')}`;
const font = path.join(__dirname, 'fonts', 'fraunces.woff2');

// Runs in the page: builds one frame from cfg and resolves when it is drawn.
async function build(cfg) {
  const load = (src) => new Promise((ok, fail) => { const i = new Image(); i.onload = () => ok(i); i.onerror = fail; i.src = src; });
  const pixels = (img) => { const c = document.createElement('canvas'); c.width = img.naturalWidth; c.height = img.naturalHeight; const x = c.getContext('2d'); x.drawImage(img, 0, 0); return x.getImageData(0, 0, c.width, c.height); };
  const el = (tag, css, parent, html) => { const e = document.createElement(tag); e.style.cssText = css; if (html != null) e.innerHTML = html; if (parent) parent.appendChild(e); return e; };
  const D = cfg.device, W = D.W, H = D.H, root = document.body;
  root.style.cssText = `margin:0;width:${W}px;height:${H}px;position:relative;overflow:hidden;background:#14243B`;

  // The sky, as on the app's location bar and icon: day blue at the top, night navy below, a soft glow.
  el('div', `position:absolute;inset:0;background:
    radial-gradient(110% 55% at 50% -6%, rgba(150,192,240,.42), rgba(150,192,240,0) 62%),
    radial-gradient(80% 40% at 50% 104%, rgba(61,116,176,.28), rgba(61,116,176,0) 70%),
    linear-gradient(180deg, #3D74B0 0%, #2A5287 34%, #1B3354 70%, #14243B 100%)`, root);

  // The words.
  const phone = cfg.kind === 'iphone';
  const head = el('div', `position:absolute;left:${phone ? 70 : 140}px;right:${phone ? 70 : 140}px;top:${phone ? 150 : 160}px;text-align:center;color:#fff`, root);
  el('div', `font:600 ${phone ? 38 : 46}px/1 var(--sans);letter-spacing:.14em;text-transform:uppercase;color:rgba(214,230,250,.82)`, head, cfg.frame.eyebrow.replace('&', '&amp;'));
  // Two lines on iPhone, one on iPad; a line that would run wider than the frame is set a little smaller
  // instead of wrapping, so every frame's device sits at the same height.
  const fit = (e, size) => { e.style.fontSize = size + 'px'; for (const l of e.children) { while (l.scrollWidth > head.clientWidth && size > 40) { size -= 2; e.style.fontSize = size + 'px'; } } };
  const title = el('div', `font-family:Fraunces,serif;font-weight:560;font-variation-settings:"opsz" 72;line-height:1.04;letter-spacing:-.004em;margin-top:${phone ? 28 : 34}px`, head,
    (phone ? cfg.frame.head : [cfg.frame.head.join(' ')]).map((l) => `<div style="white-space:nowrap;width:max-content;margin:0 auto">${l}</div>`).join(''));
  fit(title, phone ? 124 : 150);
  const sub = el('div', `font:600 1px/1.2 var(--sans);letter-spacing:-.01em;color:rgba(255,255,255,.9);margin-top:${phone ? 32 : 36}px`, head,
    `<div style="white-space:nowrap;width:max-content;margin:0 auto">${cfg.frame.sub}</div>`);
  fit(sub, phone ? 52 : 62);

  // The device: body (rim), bezel, screen at the capture's own pixels scaled to fit, buttons, island.
  function device(left, top, capW, capH) {
    const B = D.body, inset = Math.round(B * D.inset), rim = Math.round(B * D.rim);
    const sw = B - 2 * inset, k = sw / capW, sh = Math.round(capH * k), bh = sh + 2 * inset;
    const sr = D.radiusPt * D.pt * k, br = sr + inset;
    const box = el('div', `position:absolute;left:${left}px;top:${top}px;width:${B}px;height:${bh}px`, root);
    const button = (css) => el('div', `position:absolute;background:linear-gradient(90deg,#2b2d31,#74777d 50%,#2b2d31);border-radius:${B * 0.006}px;${css}`, box);
    if (phone) {
      const bw = Math.round(B * 0.011), out = -Math.round(B * 0.0065);
      button(`left:${out}px;top:${bh * 0.17}px;width:${bw}px;height:${bh * 0.04}px`);          // Action button
      button(`left:${out}px;top:${bh * 0.235}px;width:${bw}px;height:${bh * 0.068}px`);        // volume up
      button(`left:${out}px;top:${bh * 0.318}px;width:${bw}px;height:${bh * 0.068}px`);        // volume down
      button(`right:${out}px;top:${bh * 0.265}px;width:${bw}px;height:${bh * 0.105}px`);       // side button
      button(`right:${out}px;top:${bh * 0.56}px;width:${bw}px;height:${bh * 0.055}px;border-radius:${bw}px`); // Camera Control
    } else {
      const bw = Math.round(B * 0.008), out = -Math.round(B * 0.005);
      button(`top:${out}px;left:${B * 0.74}px;height:${bw}px;width:${B * 0.08}px;background:linear-gradient(180deg,#2b2d31,#74777d 50%,#2b2d31)`); // top button
      button(`right:${out}px;top:${bh * 0.07}px;width:${bw}px;height:${bh * 0.045}px`);  // volume up
      button(`right:${out}px;top:${bh * 0.125}px;width:${bw}px;height:${bh * 0.045}px`); // volume down
    }
    el('div', `position:absolute;inset:0;border-radius:${br}px;background:linear-gradient(135deg,#8a8d93 0%,#43464b 14%,#26282c 45%,#2e3034 70%,#55585e 88%,#9a9da3 100%);
      box-shadow:0 ${B * 0.07}px ${B * 0.13}px rgba(3,9,22,.55),0 ${B * 0.012}px ${B * 0.03}px rgba(3,9,22,.35)`, box);
    el('div', `position:absolute;inset:${rim}px;border-radius:${br - rim}px;background:#000;box-shadow:inset 0 0 0 ${Math.max(2, B * 0.0022)}px rgba(255,255,255,.07)`, box);
    const screen = el('div', `position:absolute;left:${inset}px;top:${inset}px;width:${sw}px;height:${sh}px;border-radius:${sr}px;overflow:hidden;background:#000;isolation:isolate`, box);
    // Content is laid out in the capture's own pixels, then scaled once.
    const content = el('div', `position:absolute;left:0;top:0;width:${capW}px;height:${capH}px;transform:scale(${k});transform-origin:0 0`, screen);
    const over = el('div', `position:absolute;left:${inset}px;top:${inset}px;width:${capW}px;height:${capH}px;transform:scale(${k});transform-origin:0 0;pointer-events:none`, box);
    if (phone) {
      // The Dynamic Island, with a faint edge and lens so it reads against the black status bar.
      const p = D.pt, iw = 126 * D.pt, ih = 37.33 * D.pt, it = 11 * D.pt;
      const isl = el('div', `position:absolute;left:${(capW - iw) / 2}px;top:${it}px;width:${iw}px;height:${ih}px;border-radius:${ih}px;background:#000;
        box-shadow:inset 0 0 0 ${1.2 * p}px rgba(255,255,255,.09), 0 0 0 ${0.6 * p}px rgba(0,0,0,.9)`, over);
      el('div', `position:absolute;right:${ih * 0.3}px;top:${ih * 0.3}px;width:${ih * 0.4}px;height:${ih * 0.4}px;border-radius:50%;
        background:radial-gradient(circle at 35% 35%, #2a3550 0%, #0b0f1a 55%, #05070c 100%);box-shadow:0 0 0 ${0.8 * p}px rgba(255,255,255,.05)`, isl);
    } else {
      el('div', `position:absolute;right:${-(inset - rim) / 2 / k - 7}px;top:${capH / 2 - 7}px;width:14px;height:14px;border-radius:50%;background:radial-gradient(circle at 35% 35%,#2a3550,#06080d 70%)`, over);
    }
    return { box, screen, content, over, k, sw, sh, bh, inset };
  }

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

  const B = D.body, left = (W - B) / 2;
  const f = cfg.frame;

  if (f.widgets) {
    // The Large widget floating on the sky, then an iPhone rising from the bottom edge showing a Lock Screen
    // with the Lock Screen widgets (white, as the Lock Screen tints them, on the wallpaper; no plate).
    const large = await load(cfg.images.large), rect = await load(cfg.images.rect), circ = await load(cfg.images.circ);
    const s = 1.42, lw = large.naturalWidth * s, lh = large.naturalHeight * s;
    el('img', `position:absolute;left:${(W - lw) / 2}px;top:648px;width:${lw}px;height:${lh}px;filter:drop-shadow(0 40px 60px rgba(3,9,22,.5)) drop-shadow(0 0 1.5px rgba(255,255,255,.18))`, root).src = cfg.images.large;
    const capW = D.W, capH = D.H, pt = D.pt;
    const dev = device(left, 648 + lh + 96, capW, capH);
    const c = dev.content;
    // Wallpaper: dusk over the Maroon Bells, with the peaks in the part of the screen the frame shows.
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
    return;
  }

  const shot = await load(cfg.images.shot), capW = shot.naturalWidth, capH = shot.naturalHeight;
  const dev = device(left, D.top, capW, capH);
  el('img', `position:absolute;left:0;top:0;width:${capW}px;height:${capH}px`, dev.content).src = cfg.images.shot;

  if (f.map && phone) {
    // Zoom the map (not the sheet's header or its buttons) on your position and heading, keep the buttons
    // where they are, and move the Maps credit up inside the safe area.
    const px = pixels(shot), P = D.pt;   // iPhone captures are @3x
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
    // Put the dot a little above the middle (the roads and the lake lie below it), then keep the zoomed map covering the box, drawn only from the
    // map itself (not the credit band at the bottom or the button column at the top right).
    let tx = bw / 2, ty = bh * 0.38;
    // Prefer pushing the zoomed copy of the buttons off the right edge (the real ones stay on top).
    const noButtons = bw - z * (bw - ctrlW - dx);
    tx = Math.min(Math.max(tx, noButtons), z * dx); tx = Math.max(tx, bw - z * (bw - dx));
    ty = Math.min(ty, z * dy); ty = Math.max(ty, bh - z * (bh - credit - dy));
    const zoom = el('div', `position:absolute;left:0;top:${mapTop}px;width:${bw}px;height:${bh}px;overflow:hidden;
      -webkit-mask-image:linear-gradient(180deg, transparent ${ctrlH - 40}px, #000 ${ctrlH + 20}px), linear-gradient(90deg, #000 ${bw - ctrlW - 70}px, transparent ${bw - ctrlW + 6}px);
      -webkit-mask-composite:source-over`, dev.content);
    el('img', `position:absolute;left:0;top:${-mapTop}px;width:${capW}px;height:${capH}px;transform-origin:${dx}px ${dot[1]}px;
      transform:translate(${tx - dx}px, ${ty - dy}px) scale(${z})`, zoom).src = cfg.images.shot;
    // The Maps credit: its own pixels as a white matte, inside the safe area.
    const cr = { x: 0, y: capH - 28 * P, w: 110 * P, h: 27 * P };
    const m = matte(shot, cr, null);
    el('img', `position:absolute;left:${14 * P}px;top:${capH - 34 * P - cr.h - 6 * P}px;width:${cr.w}px;height:${cr.h}px`, dev.content).src = m;
    return;
  }

  if (f.lift && cfg.seeds) {
    const px = pixels(shot), parts = [];
    for (const name of f.lift) { const s = cfg.seeds[name]; const r = s && find(px, s); if (r) parts.push(r); else throw new Error(`${cfg.kind} ${f.id}: no ${name} found from its seed (SEEDS in scripts/store-frames.js)`); }
    if (!parts.length) return;
    const ux0 = Math.min(...parts.map((r) => r.x)), uy0 = Math.min(...parts.map((r) => r.y));
    const ux1 = Math.max(...parts.map((r) => r.x + r.w)), uy1 = Math.max(...parts.map((r) => r.y + r.h));
    const uw = ux1 - ux0, uh = uy1 - uy0;
    // About 1.2x, less for wide elements, and never closer than 44 px to the frame's edges.
    let s = Math.min(phone ? 1.22 : 1.32, (W - 88) / (uw * dev.k));
    if (uw > capW * 0.7) s = Math.min(s, 1.07);
    el('div', `position:absolute;inset:0;background:rgba(0,0,0,.5)`, dev.content);
    // Drawn above the device (so it can stand out past the bezel), in the device's coordinates.
    const g = el('div', `position:absolute;left:${ux0}px;top:${uy0}px;width:${uw}px;height:${uh}px;transform:scale(${s});transform-origin:50% 50%`, dev.over);
    for (const r of parts) {
      const t = el('div', `position:absolute;left:${r.x - ux0}px;top:${r.y - uy0}px;width:${r.w}px;height:${r.h}px;border-radius:${r.radius}px;overflow:hidden;
        box-shadow:0 ${30 / dev.k}px ${60 / dev.k}px rgba(2,6,16,.6),0 0 0 ${2 / dev.k}px rgba(255,255,255,.16)`, g);
      el('img', `position:absolute;left:${-r.x}px;top:${-r.y}px;width:${capW}px;height:${capH}px`, t).src = cfg.images.shot;
    }
  }
}

(async () => {
  const has = (f) => fs.existsSync(path.join(IN, f));
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await playwright.chromium.launch();
  const written = [];
  for (const kind of ['iphone', 'ipad']) {
    if (!has(`${kind}-xl.png`)) { console.log(`No ${kind}-xl.png: no ${kind} frames`); continue; }
    const D = DEVICES[kind];
    const page = await browser.newPage({ viewport: { width: D.W, height: D.H }, deviceScaleFactor: 1 });
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
        [images.large, images.rect, images.circ] = need.map((f) => dataURL(path.join(IN, f)));
        if (has(`${kind}-medium.png`)) images.status = dataURL(path.join(IN, `${kind}-medium.png`));
      } else {
        const id = typeof frame.shot === 'string' ? frame.shot : frame.shot[kind];
        const file = `${kind}-${id}.png`;
        if (!has(file)) { console.log(`Skipping ${kind} ${frame.id}: no ${file}`); continue; }
        images.shot = dataURL(path.join(IN, file));
        seeds = (SEEDS[kind] || {})[id] || null;
      }
      const html = `<!doctype html><html><head><meta charset="utf-8"><style>
        @font-face { font-family: Fraunces; src: url(${dataURL(font)}) format("woff2"); font-weight: 100 900; }
        :root { --sans: -apple-system, "SF Pro Display", "SF Pro Text", Inter, "Helvetica Neue", Arial, sans-serif; }
        * { box-sizing: border-box; } body { -webkit-font-smoothing: antialiased; }
        img { display: block; }</style></head><body></body></html>`;
      await page.setContent(html);
      await page.evaluate(build, { kind, device: D, frame, images, seeds, date: DATE });
      await page.evaluate(() => document.fonts.ready);
      await page.waitForTimeout(200);
      const out = path.join(OUT, `${kind}-${n}-${frame.id}.png`);
      await page.screenshot({ path: out });
      console.log('wrote', out);
      written.push({ kind, out });
      n++;
    }
    await page.close();
  }
  if (STRIP && written.length) {
    // Every frame side by side at a common height, iPhone row above iPad row, for review.
    const rows = ['iphone', 'ipad'].map((k) => written.filter((w) => w.kind === k)).filter((r) => r.length);
    const h = 900, gap = 28;
    const rowW = (r) => r.reduce((a, w) => a + Math.round(h * DEVICES[w.kind].W / DEVICES[w.kind].H) + gap, gap);
    const width = Math.max(...rows.map(rowW)), height = rows.length * (h + gap) + gap;
    const page = await browser.newPage({ viewport: { width, height } });
    await page.setContent(`<body style="margin:0;background:#E9ECF1;width:${width}px;height:${height}px">${rows.map((r) =>
      `<div style="display:flex;gap:${gap}px;padding:${gap}px 0 0 ${gap}px">${r.map((w) => `<img src="${dataURL(w.out)}" style="height:${h}px;border-radius:12px">`).join('')}</div>`).join('')}</body>`);
    await page.waitForTimeout(200);
    fs.mkdirSync(path.dirname(STRIP), { recursive: true });
    await page.screenshot({ path: STRIP });
    console.log('wrote', STRIP);
  }
  await browser.close();
})().catch((e) => { console.error(e); process.exit(1); });
