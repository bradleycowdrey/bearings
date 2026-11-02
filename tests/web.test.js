// Tests for the web app (docs/app.html) and its core (web/core.js), run with Playwright:
//   node tests/web.test.js [screenshot-dir]
// 1. The core against Tests/fixtures/geo.json (shared with the Swift and Kotlin tests) and, when they're
//    installed, against reference libraries (proj4, mgrs, open-location-code) at 500 random places.
// 2. The page (served over HTTP, as on the site) at phone, small phone, tablet and desktop sizes: the place
//    and time, compass input with true north, the sun and moon, a marked spot, bearing lock, coordinate
//    formats, units, night mode, the menu, copying, a live (mocked) elevation, and no compass on a desktop.
//    Layout: one screen on a phone, no sideways scroll, nothing clipped.
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
const VIEWPORTS = [['phone', 390, 844], ['small phone', 375, 667], ['tablet', 768, 1024], ['desktop', 1280, 900]];
const DENVER = { latitude: 39.7392, longitude: -104.9903, accuracy: 6 };

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
    hasTouch: !!opts.touch, timezoneId: 'America/Denver', locale: 'en-US' });
  if (opts.storage) await context.addInitScript((s) => { for (const [k, v] of Object.entries(s)) localStorage.setItem(k, JSON.stringify(v)); }, opts.storage);
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  page.on('console', (m) => { if (m.type() === 'error' && !/net::|Failed to load|ERR_|maplibre/i.test(m.text())) errors.push(m.text()); });
  // No network in tests: fonts and the map library fail (the page must cope); Open-Meteo is answered here.
  await page.route(/fonts\.(googleapis|gstatic)|unpkg\.com|openfreemap/, (r) => r.abort());
  await page.route(/api\.open-meteo\.com/, (r) => r.fulfill({ contentType: 'application/json', body: JSON.stringify({ elevation: [opts.elevation ?? 2922.0] }) }));
  await page.goto(PAGE + query);
  return { context, page, errors };
}

async function layout(page) {
  return page.evaluate(() => {
    const out = [];
    if (document.documentElement.scrollWidth > innerWidth + 1) out.push(`sideways scroll (${document.documentElement.scrollWidth} > ${innerWidth})`);
    for (const e of document.querySelectorAll('.tile .v, .tile .k, .where h1, .readout .deg, .spot .txt')) {
      if (e.offsetParent === null) continue;
      if (e.scrollWidth > e.clientWidth + 1) out.push(`cut short: ${e.textContent.trim().slice(0, 30)}`);
    }
    const blocks = [...document.querySelectorAll('.panel > *')].filter((e) => !e.hidden && e.offsetParent !== null);
    for (let i = 1; i < blocks.length; i++) {
      const a = blocks[i - 1].getBoundingClientRect(), b = blocks[i].getBoundingClientRect();
      if (b.top < a.bottom - 0.5) out.push(`${blocks[i].className} overlaps ${blocks[i - 1].className}`);
    }
    // Touch targets: at least 44 × 44 including their invisible margins (checked on the visible box ≥ 32).
    for (const b of document.querySelectorAll('button')) {
      if (b.offsetParent === null || b.closest('.menu, dialog')) continue;
      const r = b.getBoundingClientRect();
      if (r.width < 32 || r.height < 32) out.push(`small target: ${b.id || b.className} ${Math.round(r.width)}×${Math.round(r.height)}`);
    }
    return out;
  });
}

(async () => {
  const server = await serve();
  PAGE = `http://127.0.0.1:${server.address().port}/app.html`;
  const browser = await playwright.chromium.launch();
  // No-break spaces (which keep numbers with their units) read as ordinary spaces here; the checks below test them on purpose.
  const txt = (page, sel) => page.$eval(sel, (e) => e.textContent.replace(/\u00a0/g, ' ').trim());
  const raw = (page, sel) => page.$eval(sel, (e) => e.textContent);
  const shown = (page, sel) => page.$eval(sel, (e) => !e.hasAttribute('hidden') && !e.hidden);
  const T0 = Date.UTC(2026, 10, 1, 16, 0);   // Sun, Nov 1 2026, 9:00 AM in Colorado
  const sky = T.sunTimes(T0, MB.lat, MB.lon);
  const hm = (ms) => new Intl.DateTimeFormat('en-US', { hour: 'numeric', minute: '2-digit', timeZone: 'America/Denver' }).formatToParts(ms).filter((p) => p.type !== 'dayPeriod').map((p) => p.value).join('').trim();

  for (const [name, w, h] of VIEWPORTS) {
    const { context, page, errors } = await open(browser, w, h, `?demo&nomap&heading=228&lock=240&spot&moving&t=${T0}`);
    await page.waitForTimeout(400);
    check(await txt(page, '#deg') === '228°' && await txt(page, '#pt') === 'SW', `${name}: sample heading reads 228° SW`);
    check(await txt(page, '#place') === 'Maroon Bells, Colorado' && (await txt(page, '#when')).startsWith('Sun, Nov 1 · 9:00 AM'), `${name}: the place and the time (${await txt(page, '#when')})`);
    check((await txt(page, '#subline')).includes('Locked 240° · turn 12° right') && (await txt(page, '#subline')).includes('True north · 8° E'), `${name}: true north, declination and the locked bearing`);
    const sub = await raw(page, '#subline');
    check(sub.includes('turn\u00a012°\u00a0right') && sub.includes('8°\u00a0E') && !/ ·/.test(sub) && !/·\u00a0/.test(sub), `${name}: the subline breaks only after a dot, never inside a number and its unit`);
    check((await raw(page, '#sunS')).includes(`${T.moonPhase(T0).name.replace(' ', '\u00a0')}\u00a0· `), `${name}: the moon's phase stays with its percentage`);
    check(await txt(page, '#latV') === MB.dd.split(', ')[0] && await txt(page, '#lonV') === MB.dd.split(', ')[1], `${name}: latitude and longitude`);
    check(await txt(page, '#sunV') === `${hm(sky.sunrise)} – ${hm(sky.sunset)}`, `${name}: sunrise and sunset (${await txt(page, '#sunV')})`);
    check((await txt(page, '#sunS')).startsWith(T.moonPhase(T0).name), `${name}: the moon's phase`);
    check(await shown(page, '#sunG') && await shown(page, '#moonG') && await shown(page, '#spotG') && await shown(page, '#lockMark'), `${name}: sun, moon, marked spot and lock on the dial`);
    check((await txt(page, '#spotText')).includes('9.2 mi · 46° NE'), `${name}: the marked spot's distance and direction (${await txt(page, '#spotText')})`);
    check(await txt(page, '#speedChip') === '3.2 mph', `${name}: speed while moving`);
    const probs = await layout(page);
    check(probs.length === 0, `${name}: layout${probs.length ? ' – ' + probs.join('; ') : ''}`);
    if (w <= 500) {
      const sh = await page.evaluate(() => document.documentElement.scrollHeight);
      check(sh <= h + 1, `${name}: fits one screen (${sh} ≤ ${h})`);
    }
    if (SHOTS) await page.screenshot({ path: path.join(SHOTS, `web-${name.replace(' ', '-')}.png`) });
    check(errors.length === 0, `${name}: no script errors${errors.length ? ' – ' + errors.join('; ') : ''}`);
    await context.close();
  }

  // Formats, units, north, night mode and the menu (phone).
  {
    const { context, page, errors } = await open(browser, 390, 844, '?demo&nomap&heading=228');
    await page.waitForTimeout(300);
    const seen = [];
    for (let i = 0; i < 6; i++) {
      const single = await page.$eval('#gridTile', (e) => !e.hidden);
      seen.push(single ? await txt(page, '#gridV') : `${await txt(page, '#latV')}, ${await txt(page, '#lonV')}`);
      await page.click(single ? '#gridTile' : '#latTile');
    }
    check(JSON.stringify(seen) === JSON.stringify([MB.dd, MB.dms, MB.ddm, MB.utm, MB.mgrs, MB.plus]), `tapping the coordinates cycles every format (${seen.join(' | ')})`);
    check(await txt(page, '#eleV') === '9,587 ft2,922 m', `elevation in feet first (${await txt(page, '#eleV')})`);
    await page.click('#moreBtn');
    check(await page.$eval('#menu', (e) => !e.hidden), 'the ⋯ menu opens');
    await page.click('#menu [data-feet="0"]');
    check(await txt(page, '#eleV') === '2,922 m9,587 ft', 'Metres First puts metres first');
    await page.click('#moreBtn'); await page.click('#menu [data-fmt="utm"]');
    check(await txt(page, '#gridV') === MB.utm, 'choosing UTM in the menu');
    await page.click('#moreBtn'); await page.click('#menu [data-north="magnetic"]');
    await page.waitForTimeout(100);
    check((await txt(page, '#subline')).startsWith('Magnetic north'), 'Magnetic North in the menu');
    await page.click('#moreBtn'); await page.click('#menu [data-act="night"]');
    check(await shown(page, '#nightFilter'), 'Night Mode turns the screen red');
    await page.reload(); await page.waitForTimeout(300);
    check(await txt(page, '#gridV') === MB.utm && await txt(page, '#eleV') === '2,922 m9,587 ft' && await shown(page, '#nightFilter'), 'settings are remembered');
    if (SHOTS) await page.screenshot({ path: path.join(SHOTS, 'web-night.png') });
    check(errors.length === 0, `menu: no script errors${errors.length ? ' – ' + errors.join('; ') : ''}`);
    await context.close();
  }

  // Location allowed: the place from the city list, live compass events, true north, locking, a spot, copying.
  {
    const { context, page, errors } = await open(browser, 390, 844, '', {
      permissions: ['geolocation', 'clipboard-read', 'clipboard-write'], geolocation: DENVER, touch: true, elevation: 1609.0,
      storage: { 'bearings.trueNorth': false, 'bearings.feet': true } });
    await page.waitForFunction(() => document.querySelector('#latV').textContent !== '—', null, { timeout: 5000 }).catch(() => {});
    check(await txt(page, '#latV') === '39.73920° N', 'with location allowed, the coordinates appear');
    await page.waitForFunction(() => /Denver/.test(document.querySelector('#place').textContent), null, { timeout: 8000 }).catch(() => {});
    check(await txt(page, '#place') === 'Denver, Colorado', `the place is named from the city list (${await txt(page, '#place')})`);
    await page.waitForFunction(() => /ft/.test(document.querySelector('#eleV').textContent), null, { timeout: 5000 }).catch(() => {});
    check(await txt(page, '#eleV') === '5,279 ft1,609 m' && await txt(page, '#eleS') === 'Terrain data', `ground elevation from Open-Meteo (${await txt(page, '#eleV')})`);
    check((await txt(page, '#latS')).startsWith('±20 ft'), `accuracy (${await txt(page, '#latS')})`);
    await page.waitForFunction(() => /can’t load/.test(document.querySelector('#mapMsg').textContent), null, { timeout: 20000 }).catch(() => {});
    check(/can’t load/.test(await txt(page, '#mapMsg')), 'without the map library, the map says so and the rest still works');
    const fire = (alpha, n = 1) => page.evaluate(([a, k]) => { for (let i = 0; i < k; i++) window.dispatchEvent(new DeviceOrientationEvent('deviceorientationabsolute', { alpha: a, beta: 10, gamma: -5, absolute: true })); }, [alpha, n]);
    await fire(90); await page.waitForTimeout(100);
    check(await txt(page, '#deg') === '270°' && await txt(page, '#pt') === 'W', `a compass reading turns the dial (${await txt(page, '#deg')})`);
    check(await page.$eval('#card', (e) => e.style.transform) === 'rotate(90deg)', 'the card turns the short way');
    check(await page.$eval('#bubble', (e) => e.getAttribute('opacity')) === '1', 'the level shows');
    await page.click('#moreBtn'); await page.click('#menu [data-north="true"]'); await page.waitForTimeout(100);
    const decl = T.magneticDeclination(DENVER.latitude, DENVER.longitude, 0, Date.now());
    check(await txt(page, '#deg') === `${Math.round(270 + decl)}°` && (await txt(page, '#subline')).startsWith(`True north · ${Math.round(decl)}° E`), `True North adds the declination (${await txt(page, '#deg')}, ${decl.toFixed(1)}° E)`);
    await page.click('#dial');
    check((await txt(page, '#subline')).includes(`Locked ${Math.round(270 + decl)}° · on bearing`), 'tapping the dial locks the bearing');
    await fire(100, 40); await page.waitForTimeout(100);
    check((await txt(page, '#subline')).includes('turn 10° right'), `turning away shows how far (${await txt(page, '#subline')})`);
    await page.click('#dial');
    check(!(await txt(page, '#subline')).includes('Locked'), 'tapping again clears it');
    await page.click('#moreBtn'); await page.click('#menu [data-act="spot"]');
    check(await shown(page, '#spotPill') && (await txt(page, '#spotText')).includes('You’re here'), 'Mark This Spot');
    await context.setGeolocation({ latitude: 39.7486, longitude: -104.9903, accuracy: 6 });   // about 1 km north
    await page.waitForFunction(() => /ft|mi/.test(document.querySelector('#spotText').textContent), null, { timeout: 5000 }).catch(() => {});
    check(/0\.\d mi · \d+° S/.test(await txt(page, '#spotText')), `walking away, the spot is behind you (${await txt(page, '#spotText')})`);
    await page.click('#spotClear');
    check(!(await shown(page, '#spotPill')), 'the ✕ clears the spot');
    await page.click('#moreBtn'); await page.click('#menu [data-act="copy"]');
    await page.waitForTimeout(100);
    const clip = await page.evaluate(() => navigator.clipboard.readText()).catch(() => '');
    check(clip === '39.74860° N, 104.99030° W', `Copy Coordinates (${clip})`);
    if (SHOTS) await page.screenshot({ path: path.join(SHOTS, 'web-live.png') });
    check(errors.length === 0, `live: no script errors${errors.length ? ' – ' + errors.join('; ') : ''}`);
    await context.close();
  }

  // Desktop: no compass, location not yet allowed.
  {
    const { context, page, errors } = await open(browser, 1280, 900, '');
    await page.waitForTimeout(2800);
    check(await page.$eval('#dialNote', (e) => !e.hidden) && /No compass/.test(await txt(page, '#dialNote')), 'a desktop says it has no compass');
    check(await page.$eval('#startCompass', (e) => e.hidden), 'a desktop doesn’t offer Start Compass');
    check(await page.$eval('#askLoc', (e) => !e.hidden) && await txt(page, '#place') === 'Bearings', 'it offers Use My Location');
    check(errors.length === 0, `desktop: no script errors${errors.length ? ' – ' + errors.join('; ') : ''}`);
    await context.close();
  }

  await browser.close();
  server.close();
  for (const r of results) console.log(r);
  console.log(`${failed === 0 ? 'ALL PASSED' : 'FAILED'}: ${passed} passed, ${failed} failed`);
  process.exit(failed === 0 ? 0 : 1);
})();
