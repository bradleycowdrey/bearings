// Tests for the web app (docs/app.html) and its core (web/core.js), run with Playwright:
//   node tests/web.test.js [screenshot-dir]
// 1. The core against Tests/fixtures/geo.json (shared with the Swift and Kotlin tests) and, when they're
//    installed, against reference libraries (proj4, mgrs, open-location-code) at 500 random places.
// 2. The page (served over HTTP, as on the site) at phone, small phone, tablet and desktop sizes: the place
//    and time, compass input with true north, the sun and moon, a marked spot, bearing lock, coordinate
//    formats, units, night mode, the menu, copying, a live (mocked) elevation, and no compass on a desktop.
//    Layout (the apps' Medium layout, docs/LAYOUTS.md): the slim location bar at the top, a dial of at least 40%
//    of the height on a phone, one Targets card, the 2 × 2 of tiles, two panes on a wide window; one screen on
//    a phone, no sideways scroll, nothing cut short and no "…". What is drawn is checked too: the screenshot's
//    own pixels (black screen, the sky bar, the maroon lock row, no crimson anywhere).
// 3. docs/app.html is the build of web/app.html and web/core.js (scripts/build-web.sh), never a second copy.
const path = require('path');
const fs = require('fs');
let playwright;
try { playwright = require('playwright'); } catch { playwright = require(path.join(require('child_process').execSync('npm root -g').toString().trim(), 'playwright')); }

const T = require('../web/core.js');
const FIX = require('../Tests/fixtures/geo.json');
const http = require('http');
let PAGE = '';
const SHOTS = process.argv[2];
const MB = FIX.places.find((p) => p.name === 'Maroon Bells');

let passed = 0, failed = 0;
const results = [];
function check(ok, what) { ok ? passed++ : failed++; results.push(`${ok ? 'PASS' : 'FAIL'} ${what}`); }

// ---------- 1. Core ----------
for (const p of FIX.places) {
  const got = { dd: T.copyText('dd', p.lat, p.lon), dms: T.copyText('dms', p.lat, p.lon), ddm: T.copyText('ddm', p.lat, p.lon),
    utm: T.utmText(p.lat, p.lon), mgrs: T.mgrs(p.lat, p.lon), plus: T.plusCode(p.lat, p.lon) };
  const bad = Object.keys(got).filter((k) => got[k] !== p[k]);
  check(bad.length === 0, `core formats for ${p.name}${bad.length ? ': ' + bad.map((k) => `${k} ${got[k]} ≠ ${p[k]}`).join('; ') : ''}`);
}
for (const h of FIX.headings) check(T.point(h.deg) === h.point, `compass point for ${h.deg}°`);
for (const e of FIX.elevations) { const g = T.elevation(e.metres); check(g.ft === e.ft && g.m === e.m, `elevation ${e.metres} m`); }
{
  const s = T.smoother(0.5); s.push(359); const h = s.push(1);
  check(h < 0.01 || h > 359.99, 'smoothing across north stays at north');
  check(T.delta(350, 10) === 20 && T.delta(10, 350) === -20, 'the short way round');
}
try {
  const proj4 = require('proj4'), mgrs = require('mgrs'), { OpenLocationCode } = require('open-location-code');
  const olc = new OpenLocationCode();
  let seed = 11; const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
  let worst = 0, mgrsBad = 0, plusBad = 0;
  for (let i = 0; i < 500; i++) {
    const lat = +(rnd() * 163.8 - 79.9).toFixed(6), lon = +(rnd() * 359.98 - 180).toFixed(6);
    const u = T.utm(lat, lon);
    const p = proj4('WGS84', `+proj=utm +zone=${u.zone} ${lat < 0 ? '+south' : ''} +datum=WGS84`, [lon, lat]);
    worst = Math.max(worst, Math.abs(p[0] - u.easting), Math.abs(p[1] - u.northing));
    const g = T.mgrs(lat, lon).replace(/ /g, ''), r = mgrs.forward([lon, lat], 5);
    if (g.slice(0, -10) !== r.slice(0, -10) || Math.abs(+g.slice(-10, -5) - +r.slice(-10, -5)) > 1 || Math.abs(+g.slice(-5) - +r.slice(-5)) > 1) mgrsBad++;
    // The npm library predates the reference's rounding step, so at an exact cell boundary it can land a
    // cell lower; nudging past the float noise must then agree.
    const pc = T.plusCode(lat, lon);
    if (pc !== olc.encode(lat, lon, 10) && pc !== olc.encode(lat + 1e-9, lon + 1e-9, 10)) plusBad++;
  }
  check(worst < 0.05, `UTM within 5 cm of proj4 at 500 places (worst ${(worst * 100).toFixed(2)} cm)`);
  check(mgrsBad === 0, `MGRS matches the mgrs library at 500 places (${mgrsBad} differ)`);
  check(plusBad === 0, `Plus Codes match open-location-code at 500 places (${plusBad} differ)`);
} catch (e) { results.push(`SKIP reference libraries (${e.code || e.message})`); }

// The newer parts of the core, against the same fixture the Swift and Kotlin tests read.
{
  const near = (a, b, e) => (a === null && b === null) || (a !== null && b !== null && Math.abs(a - b) <= e);
  let bad = [];
  for (const k of FIX.sky) {
    const sun = T.sunPosition(k.t, k.lat, k.lon), moon = T.moonPosition(k.t, k.lat, k.lon), times = T.sunTimes(k.t, k.lat, k.lon), ph = T.moonPhase(k.t);
    if (!near(sun.azimuth, k.sunAzimuth, 1e-6) || !near(sun.altitude, k.sunAltitude, 1e-6) || !near(moon.azimuth, k.moonAzimuth, 1e-6)
      || !near(moon.altitude, k.moonAltitude, 1e-6) || !near(times.sunrise, k.sunrise, 1000) || !near(times.sunset, k.sunset, 1000)
      || !near(ph.fraction, k.moonFraction, 1e-9) || ph.name !== k.moonName) bad.push(`${k.name}@${k.t}`);
  }
  check(bad.length === 0, `sun and moon at ${FIX.sky.length} places and times${bad.length ? ': ' + bad.slice(0, 4).join(', ') : ''}`);
  bad = FIX.pairs.filter((p) => Math.abs(T.distance(...p.from, ...p.to) - p.metres) > 1e-6 || Math.abs(T.bearing(...p.from, ...p.to) - p.bearing) > 1e-9
    || T.distanceText(p.metres, true) !== p.feetText || T.distanceText(p.metres, false) !== p.metresText);
  check(bad.length === 0, 'distances and bearings');
  check(FIX.speeds.every((v) => T.speedText(v.mps, true) === v.feet && T.speedText(v.mps, false) === v.metric), 'speeds');
  check(FIX.pressures.every((v) => T.pressureText(v.hpa, true) === v.feet && T.pressureText(v.hpa, false) === v.metric), 'pressures');
  const cities = T.parseCities(fs.readFileSync(path.join(__dirname, '../Resources/Cities.tsv'), 'utf8'));
  bad = FIX.nearest.filter((n) => { const p = T.nearestPlace(n.lat, n.lon, cities); return T.placeText(p, true) !== n.feetText || T.placeText(p, false) !== n.metresText; });
  check(bad.length === 0, `place names from the city list${bad.length ? ': ' + bad.map((n) => n.lat + ',' + n.lon).join('; ') : ''}`);
  try {
    const G = require('geomagnetism');
    let seed = 9, worst = 0; const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
    for (let i = 0; i < 500; i++) {
      const lat = rnd() * 170 - 85, lon = rnd() * 360 - 180, t = Date.UTC(2025, 1, 1) + rnd() * 4 * 365 * 86400000;
      worst = Math.max(worst, Math.abs(T.delta(T.magneticDeclination(lat, lon, 0, t), G.model(new Date(t)).point([lat, lon]).decl)));
    }
    check(worst < 0.05, `magnetic declination within 0.05° of the geomagnetism library at 500 places (worst ${worst.toFixed(3)}°)`);
  } catch (e) { results.push(`SKIP declination reference (${e.code || e.message})`); }
}

// ---------- 2. The page ----------
const VIEWPORTS = [['phone', 393, 852], ['small phone', 375, 667], ['tablet', 834, 1194], ['desktop', 1280, 800]];
const DENVER = { latitude: 39.7392, longitude: -104.9903, accuracy: 6 };

// One source of truth: docs/app.html must be web/app.html with web/core.js inlined (run scripts/build-web.sh).
{
  const read = (f) => fs.readFileSync(path.join(__dirname, '..', f), 'utf8');
  const [before, after] = read('web/app.html').split('/* __CORE__ */'), built = read('docs/app.html');
  check(after !== undefined && built.includes(before) && built.includes(after) && built.includes(read('web/core.js')), 'docs/app.html is the build of web/app.html and web/core.js');
  check(!fs.existsSync(path.join(__dirname, '../web/site.html')) || read('web/site.html') === read('docs/index.html'), 'docs/index.html is the build of web/site.html');
  check(!/#990F3D|crimson/i.test(read('web/app.html')) && !/#990F3D|crimson/i.test(read('docs/index.html')), 'no crimson in the web app or the product page');
  check(!/fonts\.googleapis|Inter,/.test(read('web/app.html')), 'the web app uses the system font stack, no web fonts');
}

/** A screenshot's pixels: Chromium writes 8-bit RGB or RGBA, not interlaced, which is all this reads. */
function decodePNG(buf) {
  const zlib = require('zlib');
  let pos = 8, w = 0, h = 0, ch = 4; const idat = [];
  while (pos < buf.length) {
    const len = buf.readUInt32BE(pos), type = buf.toString('latin1', pos + 4, pos + 8), data = buf.subarray(pos + 8, pos + 8 + len);
    if (type === 'IHDR') { w = data.readUInt32BE(0); h = data.readUInt32BE(4); ch = data[9] === 2 ? 3 : 4; if (data[8] !== 8 || (data[9] !== 2 && data[9] !== 6) || data[12] !== 0) throw new Error('unsupported PNG'); }
    if (type === 'IDAT') idat.push(data);
    pos += 12 + len;
  }
  const raw = zlib.inflateSync(Buffer.concat(idat)), stride = w * ch, px = Buffer.alloc(h * stride);
  for (let y = 0; y < h; y++) {
    const f = raw[y * (stride + 1)], line = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1)), o = y * stride;
    for (let x = 0; x < stride; x++) {
      const a = x >= ch ? px[o + x - ch] : 0, b = y ? px[o - stride + x] : 0, c = x >= ch && y ? px[o - stride + x - ch] : 0;
      let v = line[x];
      if (f === 1) v += a; else if (f === 2) v += b; else if (f === 3) v += (a + b) >> 1;
      else if (f === 4) { const p = a + b - c, pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c); v += pa <= pb && pa <= pc ? a : pb <= pc ? b : c; }
      px[o + x] = v & 255;
    }
  }
  return { w, h, at: (x, y) => { const o = Math.round(y) * stride + Math.round(x) * ch; return [px[o], px[o + 1], px[o + 2]]; },
    count: (test) => { let n = 0; for (let o = 0; o < px.length; o += ch) if (test(px[o], px[o + 1], px[o + 2])) n++; return n; } };
}
const close = (p, q, tol) => Math.abs(p[0] - q[0]) <= tol && Math.abs(p[1] - q[1]) <= tol && Math.abs(p[2] - q[2]) <= tol;

function serve() {
  const root = path.resolve(__dirname, '../docs');
  const types = { '.html': 'text/html; charset=utf-8', '.tsv': 'text/tab-separated-values; charset=utf-8', '.png': 'image/png' };
  return new Promise((resolve) => {
    const server = http.createServer((req, res) => {
      const file = path.join(root, decodeURIComponent(new URL(req.url, 'http://x').pathname));
      if (!file.startsWith(root) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) { res.writeHead(404); res.end(); return; }
      res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
      fs.createReadStream(file).pipe(res);
    }).listen(0, '127.0.0.1', () => resolve(server));
  });
}

async function open(browser, w, h, query, opts = {}) {
  const context = await browser.newContext({ viewport: { width: w, height: h }, permissions: opts.permissions || [], geolocation: opts.geolocation,
    hasTouch: !!opts.touch, timezoneId: 'America/Denver', locale: 'en-US', deviceScaleFactor: opts.scale || 1 });
  if (opts.storage) await context.addInitScript((s) => { for (const [k, v] of Object.entries(s)) localStorage.setItem(k, JSON.stringify(v)); }, opts.storage);
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  page.on('console', (m) => { if (m.type() === 'error' && !/net::|Failed to load|ERR_|maplibre/i.test(m.text())) errors.push(m.text()); });
  // No network in tests: the map library and its style fail (the page must cope); Open-Meteo is answered here.
  await page.route(/fonts\.(googleapis|gstatic)|unpkg\.com|openfreemap/, (r) => r.abort());
  await page.route(/api\.open-meteo\.com/, (r) => r.fulfill({ contentType: 'application/json', body: JSON.stringify({ elevation: [opts.elevation ?? 2922.0] }) }));
  await page.goto(PAGE + query);
  return { context, page, errors };
}

/** What is wrong with the layout as drawn: sideways scroll, text cut short or ending in "…", blocks on top of
    each other, anything outside the window's width, small touch targets. */
async function layout(page) {
  return page.evaluate(() => {
    const out = [], seen = (e) => e.offsetParent !== null && !e.closest('[hidden]');
    if (document.documentElement.scrollWidth > innerWidth + 1) out.push(`sideways scroll (${document.documentElement.scrollWidth} > ${innerWidth})`);
    for (const e of document.querySelectorAll('.tile .v > span, .tile .v.one, .tile .k, .tile .s, .where h1, .where .when, .readout, .trow .name, .trow .val, .subline, .nohead-words')) {
      if (!seen(e)) continue;
      if (e.scrollWidth > e.clientWidth + 1) out.push(`cut short: ${e.textContent.trim().slice(0, 30)}`);
      const p = e.parentElement.getBoundingClientRect(), r = e.getBoundingClientRect();
      if (r.right > p.right + 1 || r.left < p.left - 1) out.push(`spills out of its box: ${e.textContent.trim().slice(0, 30)}`);
    }
    for (const e of document.querySelectorAll('.app *')) {
      if (!seen(e) || e.closest('.menu')) continue;
      if (getComputedStyle(e).textOverflow === 'ellipsis') out.push(`may end in "…": ${e.id || e.className}`);
      const r = e.getBoundingClientRect();
      if (r.width && (r.right > innerWidth + 1 || r.left < -1) && !e.closest('svg')) out.push(`outside the window: ${e.id || e.className}`);
    }
    const words = document.querySelector('#targets').textContent + document.querySelector('.where').textContent + [...document.querySelectorAll('.tile')].map((t) => t.textContent).join(' ');
    if (/…/.test(words)) out.push(`an ellipsis in the bar, Targets or tiles: ${words.replace(/\s+/g, ' ').match(/.{0,20}…/)[0]}`);
    // Rows of a Targets row never run into each other: the name ends before the value starts.
    for (const row of document.querySelectorAll('.trow')) {
      if (!seen(row)) continue;
      const a = row.querySelector('.name').getBoundingClientRect(), b = row.querySelector('.val').getBoundingClientRect(), x = row.querySelector('.x').getBoundingClientRect();
      if (b.left < a.left + 1 || b.right > x.left + 1 || x.right > row.getBoundingClientRect().right + 1) out.push(`Targets row is crowded: ${row.textContent.trim().slice(0, 30)}`);
      const range = document.createRange(); range.selectNodeContents(row.querySelector('.name'));
      if (range.getBoundingClientRect().right > b.left - 4) out.push(`Targets row text collides: ${row.textContent.trim().slice(0, 30)}`);
    }
    const blocks = ['#bar', '#compass', '#targets', '.tiles'].map((s) => document.querySelector(s)).filter(seen);
    const oneColumn = getComputedStyle(document.querySelector('.app')).display !== 'grid';
    for (let i = 1; i < blocks.length; i++) {
      const a = blocks[i - 1].getBoundingClientRect(), b = blocks[i].getBoundingClientRect();
      if (b.top < a.bottom - 0.5 && (oneColumn || i === 1 || i === 3)) out.push(`${blocks[i].id || blocks[i].className} overlaps ${blocks[i - 1].id || blocks[i - 1].className}`);
    }
    const tiles = [...document.querySelectorAll('#tiles > *')].filter(seen).map((e) => e.getBoundingClientRect());
    for (let i = 0; i < tiles.length; i++) for (let j = i + 1; j < tiles.length; j++) {
      const a = tiles[i], b = tiles[j];
      if (a.left < b.right - 1 && b.left < a.right - 1 && a.top < b.bottom - 1 && b.top < a.bottom - 1) out.push(`tiles ${i} and ${j} overlap`);
    }
    // Touch targets: at least 44 × 44 including their invisible margins (checked on the visible box ≥ 32).
    for (const b of document.querySelectorAll('button')) {
      if (!seen(b) || b.closest('.menu, dialog')) continue;
      const r = b.getBoundingClientRect();
      if (r.width < 32 || r.height < 32) out.push(`small target: ${b.id || b.className} ${Math.round(r.width)}×${Math.round(r.height)}`);
    }
    return out;
  });
}
const box = (page, sel) => page.$eval(sel, (e) => { const r = e.getBoundingClientRect(); return { x: r.left, y: r.top, w: r.width, h: r.height, r: r.right, b: r.bottom }; });

(async () => {
  const server = await serve();
  PAGE = `http://127.0.0.1:${server.address().port}/app.html`;
  const browser = await playwright.chromium.launch();
  // No-break spaces (which keep numbers with their units) read as ordinary spaces here; the checks below test them on purpose.
  const txt = (page, sel) => page.$eval(sel, (e) => e.textContent.replace(/[  ]/g, ' ').trim());
  const raw = (page, sel) => page.$eval(sel, (e) => e.textContent);
  const shown = (page, sel) => page.$eval(sel, (e) => !e.closest('[hidden]') && (e.namespaceURI !== 'http://www.w3.org/1999/xhtml' || e.offsetParent !== null || getComputedStyle(e).position === 'fixed'));
  const T0 = Date.UTC(2026, 10, 1, 16, 41);   // Sun, Nov 1 2026, 9:41 AM in Colorado
  const sky = T.sunTimes(T0, MB.lat, MB.lon), moon = T.moonPhase(T0), moonPct = `${Math.round(moon.fraction * 100)}%`;
  const hm = (ms) => new Intl.DateTimeFormat('en-US', { hour: 'numeric', minute: '2-digit', timeZone: 'America/Denver' }).format(ms).replace(/[  ]/g, ' ');

  for (const [name, w, h] of VIEWPORTS) {
    const { context, page, errors } = await open(browser, w, h, `?demo&nomap&heading=228&lock=240&spot&moving&t=${T0}`);
    await page.waitForTimeout(400);
    const wide = w > h;
    check(await txt(page, '#deg') === '228°' && await txt(page, '#pt') === 'SW', `${name}: sample heading reads 228° SW`);
    check(await txt(page, '#place') === 'Maroon Bells, Colorado' && await txt(page, '#when') === 'Sun, Nov 1 · 9:41 AMSample', `${name}: the place, the time and the Sample pill (${await txt(page, '#when')})`);
    check(await txt(page, '#subline') === 'True north · 8° E declination · ±8° accuracy', `${name}: the status line (${await txt(page, '#subline')})`);
    const sub = await raw(page, '#subline');
    check(sub.includes('8° E declination') && sub.includes('±8° accuracy') && !/ ·/.test(sub) && !/· /.test(sub), `${name}: the status line breaks only after a dot, never inside a number and its unit`);

    // One Targets card: the lock row on the maroon tint, then the marked spot, each with its ✕.
    check(await shown(page, '#targets') && await shown(page, '#lockRow') && await shown(page, '#spotRow') && await shown(page, '#lockClear') && await shown(page, '#spotClear'), `${name}: the Targets card shows the lock and the spot, each with a ✕`);
    check(await txt(page, '#lockText') === 'Locked 240°' && await txt(page, '#lockTurn') === 'turn 12° right' && (await raw(page, '#lockTurn')) === 'turn 12° right', `${name}: the locked bearing (${await txt(page, '#lockText')}, ${await txt(page, '#lockTurn')})`);
    check(await txt(page, '#spotText') === '9.2 mi · 46° NE' && !/ /.test(await raw(page, '#spotText')), `${name}: the marked spot's distance and direction (${await txt(page, '#spotText')})`);
    const rows = [await box(page, '#targets'), await box(page, '#lockRow'), await box(page, '#spotRow')];
    check(Math.abs(rows[1].y - rows[0].y) < 1 && Math.abs(rows[2].y - rows[1].b) < 2 && Math.abs(rows[2].b - rows[0].b) < 1 && Math.abs(rows[1].w - rows[0].w) < 1, `${name}: the two rows are one card`);
    check(await page.$eval('#lockRow', (e) => getComputedStyle(e).backgroundColor) === 'rgb(61, 33, 40)', `${name}: the lock row is on the maroon tint`);

    // The tiles: Position (one tile, the format in its caption), Elevation, Sun, and the map.
    check(await txt(page, '#posK') === 'Position · DD' && await page.$eval('#posK', (e) => getComputedStyle(e).textTransform) === 'uppercase', `${name}: the Position tile's caption, in capitals`);
    check(await txt(page, '#latV') === MB.dd.split(', ')[0] && await txt(page, '#lonV') === MB.dd.split(', ')[1], `${name}: latitude and longitude`);
    check(await txt(page, '#eleV') === '9,587 ft' && await txt(page, '#eleS') === '2,922 m · Terrain data', `${name}: elevation with metres (${await txt(page, '#eleV')}, ${await txt(page, '#eleS')})`);
    check(await txt(page, '#sunUp') === `↑ ${hm(sky.sunrise)}` && await txt(page, '#sunDown') === `↓ ${hm(sky.sunset)}`, `${name}: sunrise and sunset (${await txt(page, '#sunUp')} ${await txt(page, '#sunDown')})`);
    check(/^↑ \d+:\d\d AM$/.test(await raw(page, '#sunUp')), `${name}: a time never splits from its arrow or its AM`);
    if (wide) check(await shown(page, '#moonTile') && await txt(page, '#moonV') === moonPct && (await txt(page, '#moonS')).toLowerCase() === moon.name.toLowerCase() && !(await shown(page, '#moonPct')), `${name}: the Moon tile (${await txt(page, '#moonV')}, ${await txt(page, '#moonS')})`);
    else check(await txt(page, '#sunK') === `Sun·${moonPct}` && await shown(page, '#moonPct') && !(await shown(page, '#moonTile')), `${name}: the moon in the Sun tile's caption (${await txt(page, '#sunK')})`);
    check(await shown(page, '#sunG') && await shown(page, '#moonG') && await shown(page, '#spotG') && await shown(page, '#lockMark'), `${name}: sun, moon, marked spot and lock on the dial`);
    check(!(await shown(page, '#speedChip')) && await txt(page, '#speedChip') === '', `${name}: no speed chip in the sample, which is still (as in the apps)`);

    // The dial's colours: pink for north only; the marked spot, the lock and the lubber line are white.
    const fills = await page.evaluate(() => ({
      pink: [...document.querySelectorAll('#dialSvg [fill="#E04A7A"], #dialSvg [stroke="#E04A7A"]')].map((e) => e.tagName + (e.textContent || e.getAttribute('transform'))).sort().join('|'),
      white: ['#spotG path', '#lockMark path', '#lubber'].map((s) => document.querySelector(s).getAttribute('fill')).join('|'), arc: document.querySelector('#lockArc').getAttribute('stroke') }));
    check(fills.pink === 'linerotate(0 200 200)|textN' && fills.white === '#FFFFFF|#FFFFFF|#FFFFFF' && /255,255,255/.test(fills.arc), `${name}: pink means north only; the spot and the lock are white (${fills.pink}; ${fills.white})`);

    // Where things are.
    const bar = await box(page, '#bar'), dial = await box(page, '.dial-wrap'), compass = await box(page, '#compass'), targets = rows[0];
    const pos = await box(page, '#posTile'), ele = await box(page, '#eleTile'), sun = await box(page, '#sunTile'), mapBox = await box(page, '#mapCard');
    check(bar.y <= 20 && bar.h <= (w >= 700 ? 60 : 44) && bar.w >= Math.min(w, wide ? w : 752) - 50 && bar.b <= dial.y, `${name}: the slim location bar is at the top (${Math.round(bar.h)} high at ${Math.round(bar.y)})`);
    check(Math.abs(dial.w - dial.h) < 1 && dial.x >= 0 && dial.r <= w, `${name}: the dial is round and inside the window`);
    if (!wide) {
      check(dial.h >= 0.4 * h, `${name}: the dial is at least 40% of the height (${Math.round(dial.h)} of ${h}, ${Math.round(100 * dial.h / h)}%)`);
      check(compass.b <= targets.y && targets.b <= pos.y, `${name}: dial, readout and status, then Targets, then the tiles`);
      check(Math.abs(pos.y - ele.y) < 1 && Math.abs(sun.y - mapBox.y) < 1 && sun.y > pos.b && Math.abs(pos.x - sun.x) < 1 && Math.abs(ele.x - mapBox.x) < 1 && ele.x > pos.r
        && Math.abs(pos.w - ele.w) < 1 && Math.abs(sun.h - mapBox.h) < 1, `${name}: a 2 × 2 of tiles, the map the fourth`);
      check(await shown(page, '#mapOpen'), `${name}: the Map tile opens the map`);
    } else {
      const moonBox = await box(page, '#moonTile');
      check(compass.r <= targets.x && dial.h >= 0.5 * h && targets.y >= bar.b && Math.abs(targets.r - bar.r) < 2, `${name}: two panes, the dial on the left (${Math.round(dial.h)} of ${h})`);
      check(Math.abs(pos.y - ele.y) < 1 && Math.abs(sun.y - moonBox.y) < 1 && sun.y > pos.b && mapBox.y > sun.b && mapBox.w > pos.w * 1.9 && mapBox.h >= 140 && mapBox.b <= h, `${name}: tiles 2 × 2 with a map card below (${Math.round(mapBox.w)} × ${Math.round(mapBox.h)})`);
    }
    const probs = await layout(page);
    check(probs.length === 0, `${name}: layout${probs.length ? ' – ' + probs.join('; ') : ''}`);
    const sh = await page.evaluate(() => document.documentElement.scrollHeight);
    check(sh <= h + 1, `${name}: fits one screen (${sh} ≤ ${h})`);

    // What is drawn: the screenshot's own pixels.
    const png = decodePNG(await page.screenshot());
    const lockPx = png.at(rows[1].x + 4, rows[1].y + rows[1].h / 2), barPx = png.at(bar.x + bar.w * 0.6, bar.y + bar.h / 2), dialPx = png.at(dial.x + dial.w * 0.4, dial.y + dial.h * 0.4);
    check(close(png.at(2, h - 2), [0, 0, 0], 2) && close(png.at(w - 2, 2), [0, 0, 0], 2), `${name}: drawn on black`);
    check(barPx[2] > barPx[0] + 30 && barPx[2] > 60, `${name}: the bar is drawn on the day's sky (${barPx})`);
    check(close(lockPx, [61, 33, 40], 6), `${name}: the lock row is drawn maroon (${lockPx})`);
    check(close(dialPx, [20, 20, 20], 6), `${name}: the dial's disc is drawn dark (${dialPx})`);
    check(png.count((r, g, b) => Math.abs(r - 153) < 12 && Math.abs(g - 15) < 12 && Math.abs(b - 61) < 12) === 0, `${name}: no crimson is drawn anywhere`);
    check(png.count((r, g, b) => Math.abs(r - 224) < 10 && Math.abs(g - 74) < 10 && Math.abs(b - 122) < 10) > 20, `${name}: north is drawn pink`);
    if (SHOTS) await page.screenshot({ path: path.join(SHOTS, `web-${name.replace(' ', '-')}.png`) });
    check(errors.length === 0, `${name}: no script errors${errors.length ? ' – ' + errors.join('; ') : ''}`);
    await context.close();
  }

  // The picture at the top of README.md: `README_SHOT=docs/screenshot-app.png node tests/web.test.js` retakes it
  // (the sample on a phone, 393 × 852 at 2×), so it always shows the screen these tests have just checked.
  if (process.env.README_SHOT) {
    const { context, page } = await open(browser, 393, 852, `?demo&nomap&heading=228&lock=240&spot&t=${T0}`, { touch: true, scale: 2 });
    await page.waitForTimeout(900);
    await page.screenshot({ path: process.env.README_SHOT });
    const size = fs.readFileSync(process.env.README_SHOT).readUInt32BE(16);
    check(size === 786, `the README picture is written at 2× (${size} px wide)`);
    await context.close();
  }

  // Formats, units, north, night mode, the menu and the map (phone); every format again on a narrow phone.
  {
    const { context, page, errors } = await open(browser, 393, 852, '?demo&nomap&heading=228&lock=240&spot');
    await page.waitForTimeout(300);
    const seen = [], caps = [], bad = [];
    for (let i = 0; i < 6; i++) {
      const single = await page.$eval('#gridV', (e) => !e.hidden);
      seen.push(single ? await txt(page, '#gridV') : `${await txt(page, '#latV')}, ${await txt(page, '#lonV')}`);
      caps.push((await txt(page, '#posK')).replace('Position · ', ''));
      bad.push(...(await layout(page)).map((p) => `${caps[i]}: ${p}`));
      await page.click('#posTile');
    }
    check(JSON.stringify(seen) === JSON.stringify([MB.dd, MB.dms, MB.ddm, MB.utm, MB.mgrs, MB.plus]), `tapping the Position tile cycles every format (${seen.join(' | ')})`);
    check(caps.join(' ') === 'DD DMS DDM UTM MGRS Plus', `the caption names the format (${caps.join(' ')})`);
    check(bad.length === 0, `every format fits its tile${bad.length ? ' – ' + bad.join('; ') : ''}`);
    await page.click('#moreBtn');
    check(await page.$eval('#menu', (e) => !e.hidden), 'the ⋯ menu opens');
    const menuBox = await box(page, '#menu');
    check(menuBox.x >= 0 && menuBox.r <= 393 && menuBox.b <= 852, 'the menu is inside the window');
    await page.click('#menu [data-feet="0"]');
    check(await txt(page, '#eleV') === '2,922 m' && await txt(page, '#eleS') === '9,587 ft · Terrain data', 'Metres First puts metres first');
    await page.click('#moreBtn'); await page.click('#menu [data-fmt="utm"]');
    check(await txt(page, '#gridV') === MB.utm, 'choosing UTM in the menu');
    await page.click('#moreBtn'); await page.click('#menu [data-north="magnetic"]');
    await page.waitForTimeout(100);
    check((await txt(page, '#subline')).startsWith('Magnetic north'), 'Magnetic North in the menu');
    await page.click('#moreBtn'); await page.keyboard.press('Escape');
    check(await page.$eval('#menu', (e) => e.hidden) && await page.evaluate(() => document.activeElement.id) === 'moreBtn', 'Escape closes the menu and returns to its button');
    // The Map tile opens the map over the whole screen; Done or Escape puts it back.
    await page.click('#mapOpen');
    let big = await box(page, '#mapCard');
    check(big.w === 393 && big.h === 852 && await page.evaluate(() => document.activeElement.id) === 'mapClose' && await page.$eval('#mapCard', (e) => e.getAttribute('role')) === 'dialog', `the Map tile opens the map larger (${big.w} × ${big.h})`);
    await page.keyboard.press('Escape');
    big = await box(page, '#mapCard');
    check(big.w < 200 && await page.evaluate(() => document.activeElement.id) === 'mapOpen', 'Escape closes the map and returns to the tile');
    await page.click('#mapOpen'); await page.click('#mapClose');
    check((await box(page, '#mapCard')).w < 200, 'Done closes the map');
    await page.click('#moreBtn'); await page.click('#menu [data-act="night"]');
    check(await shown(page, '#nightFilter'), 'Night Mode turns the screen red');
    await page.reload(); await page.waitForTimeout(300);
    check(await txt(page, '#gridV') === MB.utm && await txt(page, '#eleV') === '2,922 m' && await shown(page, '#nightFilter'), 'settings are remembered');
    const png = decodePNG(await page.screenshot());
    check(png.count((r, g, b) => g > 60 || b > 60) === 0 && png.count((r) => r > 150) > 500, 'night mode is drawn in red only');
    if (SHOTS) await page.screenshot({ path: path.join(SHOTS, 'web-night.png') });
    check(errors.length === 0, `menu: no script errors${errors.length ? ' – ' + errors.join('; ') : ''}`);
    await context.close();
  }
  {
    const { context, page, errors } = await open(browser, 320, 568, '?demo&nomap&heading=228&lock=240&spot', { storage: { 'bearings.feet': false } });
    await page.waitForTimeout(300);
    const bad = [];
    for (let i = 0; i < 6; i++) { const cap = await txt(page, '#posK'); bad.push(...(await layout(page)).map((p) => `${cap}: ${p}`)); await page.click('#posTile'); }
    check(bad.length === 0, `narrow phone (320 wide): nothing is cut short in any format${bad.length ? ' – ' + bad.join('; ') : ''}`);
    if (SHOTS) await page.screenshot({ path: path.join(SHOTS, 'web-narrow.png'), fullPage: true });
    check(errors.length === 0, `narrow: no script errors${errors.length ? ' – ' + errors.join('; ') : ''}`);
    await context.close();
  }

  // The sample with no compass (as a phone without one, and every desktop): words, not a dash.
  {
    const { context, page, errors } = await open(browser, 393, 852, `?demo&nomap&nocompass&spot&t=${T0}`);
    await page.waitForTimeout(400);
    check(await shown(page, '#noHeading') && await txt(page, '#noHeading') === 'No heading' && !(await shown(page, '#readout')), 'no compass: "No heading" in words takes the readout\'s place');
    check(await txt(page, '#subline') === 'Position, sun and map still work', `no compass: the status line says what still works (${await txt(page, '#subline')})`);
    check(await page.$eval('#card', (e) => e.style.transform) === 'rotate(0deg)' && await shown(page, '#noHeadG') && !(await shown(page, '#lubber')) && !(await shown(page, '#lockMark')), 'no compass: the dial stays north-up and says so');
    check(await shown(page, '#sunG') && await shown(page, '#spotG') && await shown(page, '#spotRow') && !(await shown(page, '#lockRow')) && await txt(page, '#spotText') === '9.2 mi · 46° NE', 'no compass: the sun and the marked spot still show');
    check(await page.$eval('#srHeading', (e) => e.textContent) === 'Heading unavailable', 'no compass: announced once as "Heading unavailable"');
    const dial = await box(page, '.dial-wrap');
    check(dial.h >= 0.4 * 852, `no compass: the dial keeps its size (${Math.round(dial.h)})`);
    const probs = await layout(page);
    check(probs.length === 0, `no compass: layout${probs.length ? ' – ' + probs.join('; ') : ''}`);
    if (SHOTS) await page.screenshot({ path: path.join(SHOTS, 'web-no-compass.png') });
    check(errors.length === 0, `no compass: no script errors${errors.length ? ' – ' + errors.join('; ') : ''}`);
    await context.close();
  }
  // ?store hides the Sample pill (the web's version of the apps' --store launch argument).
  {
    const { context, page } = await open(browser, 393, 852, `?demo&nomap&store&heading=228&t=${T0}`);
    await page.waitForTimeout(300);
    check(await txt(page, '#when') === 'Sun, Nov 1 · 9:41 AM' && !(await shown(page, '#targets')), `?store hides the Sample pill; no Targets card without a lock or spot (${await txt(page, '#when')})`);
    const pos = await box(page, '#posTile'), compass = await box(page, '#compass');
    check(pos.y >= compass.b, 'without Targets the tiles follow the status line');
    await context.close();
  }

  // Location allowed: the place from the city list, live compass events, true north, locking, a spot, copying.
  {
    const { context, page, errors } = await open(browser, 393, 852, '', {
      permissions: ['geolocation', 'clipboard-read', 'clipboard-write'], geolocation: DENVER, touch: true, elevation: 1609.0,
      storage: { 'bearings.trueNorth': false, 'bearings.feet': true } });
    await page.waitForFunction(() => document.querySelector('#latV').textContent !== '—', null, { timeout: 5000 }).catch(() => {});
    check(await txt(page, '#latV') === '39.73920° N', 'with location allowed, the coordinates appear');
    await page.waitForFunction(() => /Denver/.test(document.querySelector('#place').textContent), null, { timeout: 8000 }).catch(() => {});
    check(await txt(page, '#place') === 'Denver, Colorado', `the place is named from the city list (${await txt(page, '#place')})`);
    await page.waitForFunction(() => /ft/.test(document.querySelector('#eleV').textContent), null, { timeout: 5000 }).catch(() => {});
    check(await txt(page, '#eleV') === '5,279 ft' && await txt(page, '#eleS') === '1,609 m · Terrain data', `ground elevation from Open-Meteo (${await txt(page, '#eleV')}, ${await txt(page, '#eleS')})`);
    check((await txt(page, '#posS')).startsWith('±20 ft'), `accuracy (${await txt(page, '#posS')})`);
    check(await page.$('.sample') === null, 'no Sample pill on a real place');
    await page.waitForFunction(() => /can’t load/.test(document.querySelector('#mapMsg').textContent), null, { timeout: 20000 }).catch(() => {});
    check(/can’t load/.test(await txt(page, '#mapMsg')), 'without the map library, the map says so and the rest still works');
    const fire = (alpha, n = 1) => page.evaluate(([a, k]) => { for (let i = 0; i < k; i++) window.dispatchEvent(new DeviceOrientationEvent('deviceorientationabsolute', { alpha: a, beta: 10, gamma: -5, absolute: true })); }, [alpha, n]);
    await fire(90); await page.waitForTimeout(100);
    check(await txt(page, '#deg') === '270°' && await txt(page, '#pt') === 'W', `a compass reading turns the dial (${await txt(page, '#deg')})`);
    check(await page.$eval('#card', (e) => e.style.transform) === 'rotate(90deg)', 'the card turns the short way');
    check(await page.$eval('#bubble', (e) => e.getAttribute('opacity')) === '1', 'the level shows');
    await page.click('#moreBtn'); await page.click('#menu [data-north="true"]'); await page.waitForTimeout(100);
    const decl = T.magneticDeclination(DENVER.latitude, DENVER.longitude, 0, Date.now());
    check(await txt(page, '#deg') === `${Math.round(270 + decl)}°` && (await txt(page, '#subline')).startsWith(`True north · ${Math.round(decl)}° E declination`), `True North adds the declination (${await txt(page, '#deg')}, ${decl.toFixed(1)}° E)`);
    check(!(await shown(page, '#targets')), 'no Targets card before a lock or a spot');
    await page.click('#dial');
    check(await shown(page, '#targets') && await txt(page, '#lockText') === `Locked ${Math.round(270 + decl)}°` && await txt(page, '#lockTurn') === 'on bearing' && !(await txt(page, '#subline')).includes('Locked'), 'tapping the dial locks the bearing: the Targets card appears');
    await fire(100, 40); await page.waitForTimeout(100);
    check(await txt(page, '#lockTurn') === 'turn 10° right', `turning away shows how far (${await txt(page, '#lockTurn')})`);
    await page.click('#dial');
    check(!(await shown(page, '#lockRow')) && !(await shown(page, '#targets')), 'tapping again clears it, and the card goes');
    await page.click('#dial'); await page.click('#lockClear');
    check(!(await shown(page, '#lockRow')) && !(await shown(page, '#lockMark')), 'the lock row\'s ✕ clears the lock');
    await page.click('#moreBtn'); await page.click('#menu [data-act="spot"]');
    check(await shown(page, '#targets') && await shown(page, '#spotRow') && await txt(page, '#spotText') === 'You’re here', 'Mark This Spot: the Targets card appears');
    await context.setGeolocation({ latitude: 39.7486, longitude: -104.9903, accuracy: 6 });   // about 1 km north
    await page.waitForFunction(() => /ft|mi/.test(document.querySelector('#spotText').textContent), null, { timeout: 5000 }).catch(() => {});
    check(/^0\.\d mi · \d+° S/.test(await txt(page, '#spotText')), `walking away, the spot is behind you (${await txt(page, '#spotText')})`);
    const probs = await layout(page);
    check(probs.length === 0, `live: layout${probs.length ? ' – ' + probs.join('; ') : ''}`);
    await page.click('#spotClear');
    check(!(await shown(page, '#spotRow')) && !(await shown(page, '#targets')), 'the ✕ clears the spot');
    await page.click('#moreBtn'); await page.click('#menu [data-act="copy"]');
    await page.waitForTimeout(100);
    const clip = await page.evaluate(() => navigator.clipboard.readText()).catch(() => '');
    check(clip === '39.74860° N, 104.99030° W' && await txt(page, '#toast') === 'Coordinates copied', `Copy Coordinates, and it says so (${clip})`);
    if (SHOTS) await page.screenshot({ path: path.join(SHOTS, 'web-live.png') });
    check(errors.length === 0, `live: no script errors${errors.length ? ' – ' + errors.join('; ') : ''}`);
    await context.close();
  }

  // Desktop: no compass, location not yet allowed.
  {
    const { context, page, errors } = await open(browser, 1280, 800, '');
    await page.waitForTimeout(2800);
    check(await shown(page, '#noHeading') && await txt(page, '#noHeading') === 'No heading' && await txt(page, '#subline') === 'Position, sun and map still work', 'a desktop says "No heading" and what still works');
    check(await page.$eval('#startCompass', (e) => e.hidden), 'a desktop doesn’t offer Start Compass');
    check(await page.$eval('#askLoc', (e) => !e.hidden) && await txt(page, '#place') === 'Bearings', 'it offers Use My Location');
    // Two panes before a position is known: the ask is one card down the right pane, not a strip over a hole.
    const askBox = await page.$eval('#askLoc', (e) => { const r = e.getBoundingClientRect(); return { h: r.height, bottom: r.bottom, vh: innerHeight }; });
    check(askBox.h >= 240 && askBox.vh - askBox.bottom <= 32, `desktop: the location ask fills the right pane (${Math.round(askBox.h)} px, ${Math.round(askBox.vh - askBox.bottom)} px under it)`);
    const probs = await layout(page);
    check(probs.length === 0, `desktop, no compass: layout${probs.length ? ' – ' + probs.join('; ') : ''}`);
    if (SHOTS) await page.screenshot({ path: path.join(SHOTS, 'web-desktop-no-compass.png') });
    check(errors.length === 0, `desktop: no script errors${errors.length ? ' – ' + errors.join('; ') : ''}`);
    await context.close();
  }

  await browser.close();
  server.close();
  for (const r of results) console.log(r);
  console.log(`${failed === 0 ? 'ALL PASSED' : 'FAILED'}: ${passed} passed, ${failed} failed`);
  process.exit(failed === 0 ? 0 : 1);
})();
