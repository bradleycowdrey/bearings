// Draws Bearings' icons and DMG background with Playwright (Chromium). The icon is the "Open C": the
// family's open C (the same stroke, radius and round caps as Cowdrey One, Cowdrey.MD and Cowdrey.PDF) as a
// compass bezel on the sky (day blue at the top left to night navy at the bottom right), opening to the
// north-east, with a pink north needle that swings out through the gap, a white south half and a navy hub.
// It is flat, with no drop shadow, like its siblings. Writes:
//   Resources/iOS/Assets.xcassets/AppIcon.appiconset/AppIcon.png, AppIcon-dark.png and AppIcon-tinted.png
//     (full bleed, 1024; the dark and tinted appearances are for iOS 18 and later)
//   Resources/AppIcon.png (Mac, 1024 canvas, 824 body with continuous corners and a soft shadow)
//   docs/icon.png (512)  Resources/dmg/background.png and background@2x.png
//   android/.../mipmap-*/ic_launcher.png (legacy, full bleed) and ic_launcher_foreground.png (adaptive; the
//     background is drawable/ic_launcher_bg.xml)  android/.../drawable-nodpi/app_mark.png and widget_preview.png
//     (the Small widget, for Android's widget picker)
// Usage: node scripts/make-art.js
const path = require('path');
const fs = require('fs');
let playwright;
try { playwright = require('playwright'); } catch { playwright = require(path.join(require('child_process').execSync('npm root -g').toString().trim(), 'playwright')); }
const root = path.resolve(__dirname, '..');

// Colours for each appearance. Light is the icon everywhere; dark and tinted are iOS 18's other appearances.
// Tinted is greyscale on black: iOS tints it by brightness, so the ring and the south half (white) stay
// brightest and the north half (mid grey) stays apart from them.
const LOOKS = {
  light: { sky: ['#4A82C0', '#3D74B0', '#14243B'], ring: '#FFFFFF', north: '#E8578A', northShade: '#C93A6C', south: '#FFFFFF', southShade: '#D9E3EF', hub: '#14243B' },
  dark: { sky: ['#1E2836', '#141B26', '#05070B'], ring: '#F2F5FA', north: '#EC5F91', northShade: '#CC4373', south: '#F2F5FA', southShade: '#C4CEDB', hub: '#05070B' },
  tinted: { sky: ['#000000', '#000000', '#000000'], ring: '#FFFFFF', north: '#8E8E93', northShade: '#727277', south: '#FFFFFF', southShade: '#D6D6D6', hub: '#000000' },
};

// The glyph in a 1024 box, centred on (512, 512).
// Ring: Cowdrey One's C (radius 282, stroke 104, round caps) at that icon's 0.955 scale. Its gap is
// Cowdrey One's 72° widened by 5° so the needle has clear air, and the gap's bisector lies on the needle's
// axis (bearing 45°, north-east), so the tip passes through the middle of the gap.
// Needle: the north tip clears the ring's outer edge by 40; the south half is 55% of the north; the hub
// sits on the pivot, where the four facets meet.
const C = 512, R = 282 * 0.955, STROKE = 104 * 0.955, AXIS = 45, GAP = 72 + 5;
const NORTH = Math.round(R + STROKE / 2 + 40), SOUTH = Math.round(NORTH * 0.55), HALF_WIDTH = 106, HUB = 24;
function glyph(look, scale = 1) {
  const at = (bearing) => { const a = (bearing - 90) * Math.PI / 180; return [(C + R * Math.cos(a)).toFixed(1), (C + R * Math.sin(a)).toFixed(1)]; };
  const [x0, y0] = at(AXIS + GAP / 2), [x1, y1] = at(AXIS - GAP / 2 + 360);
  const n = C - NORTH, s = C + SOUTH, l = C - HALF_WIDTH, r = C + HALF_WIDTH;
  return `<g transform="translate(${C} ${C}) scale(${scale}) translate(${-C} ${-C})">
    <path d="M${x0} ${y0} A${R.toFixed(1)} ${R.toFixed(1)} 0 1 1 ${x1} ${y1}" fill="none" stroke="${look.ring}" stroke-width="${STROKE.toFixed(1)}" stroke-linecap="round"/>
    <g transform="rotate(${AXIS} ${C} ${C})">
      <path d="M${C} ${n} L${r} ${C} L${C} ${s} L${l} ${C} Z" fill="${look.southShade}"/>
      <path d="M${C} ${n} L${r} ${C} L${l} ${C} Z" fill="${look.northShade}"/><path d="M${C} ${n} L${l} ${C} L${C} ${C} Z" fill="${look.north}"/>
      <path d="M${C} ${s} L${l} ${C} L${C} ${C} Z" fill="${look.south}"/>
    </g>
    <circle cx="${C}" cy="${C}" r="${HUB}" fill="${look.hub}"/></g>`;
}

// The sky runs on the diagonal, top left to bottom right, as on Cowdrey One.
const sky = (look, id) => `<linearGradient id="${id}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${look.sky[0]}"/><stop offset="0.38" stop-color="${look.sky[1]}"/><stop offset="1" stop-color="${look.sky[2]}"/></linearGradient>`;

// Full bleed, for iOS (the system masks it), docs/icon.png, the app mark and Android's legacy launcher icon.
const ios = (mode = 'light') => `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>${sky(LOOKS[mode], 'g')}</defs><rect width="1024" height="1024" fill="url(#g)"/>${glyph(LOOKS[mode])}</svg>`;

// The Mac icon: Apple's 824 body on a 1024 canvas, with continuous corners (a superellipse, as in Apple's
// template) and a soft shadow under the body only.
function squircle(x, y, size, n = 5) {
  const h = size / 2, pts = [];
  for (let i = 0; i < 720; i++) {
    const t = i / 720 * 2 * Math.PI, c = Math.cos(t), sn = Math.sin(t);
    pts.push(`${(x + h + h * Math.sign(c) * Math.abs(c) ** (2 / n)).toFixed(2)} ${(y + h + h * Math.sign(sn) * Math.abs(sn) ** (2 / n)).toFixed(2)}`);
  }
  return `M${pts.join(' L')} Z`;
}
const mac = `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>${sky(LOOKS.light, 'g')}<filter id="sh" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="12" stdDeviation="14" flood-opacity=".3"/></filter></defs>
  <path d="${squircle(100, 100, 824)}" fill="url(#g)" filter="url(#sh)"/>${glyph(LOOKS.light, 824 / 1024)}</svg>`;

// Android's adaptive icon: the glyph on a transparent 108 dp canvas (the sky is drawable/ic_launcher_bg.xml).
// The launcher shows the middle 72 dp, so 72/108 of the full-bleed size gives the same look as iOS, and the
// needle's tip stays inside the 66 dp safe circle.
const fg = `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">${glyph(LOOKS.light, 72 / 108)}</svg>`;
const dmg = (s) => `<html><body style="margin:0;width:660px;height:400px;background:#000;font-family:Inter,-apple-system,system-ui,sans-serif;color:#fff;position:relative;overflow:hidden;zoom:${s}">
  <div style="position:absolute;inset:0 0 auto;height:4px;background:#990F3D"></div>
  <div style="position:absolute;top:44px;width:100%;text-align:center;font-size:28px;font-weight:600;letter-spacing:-.5px">Bearings</div>
  <div style="position:absolute;top:88px;width:100%;text-align:center;font-size:15px;color:rgba(255,255,255,0.7)">A compass with your coordinates, elevation and a map.</div>
  <div style="position:absolute;left:92px;top:121px;width:176px;height:188px;border-radius:22px;background:rgba(255,255,255,0.08);border:1px solid rgba(255,255,255,0.12);box-sizing:border-box"></div>
  <div style="position:absolute;left:392px;top:121px;width:176px;height:188px;border-radius:22px;background:rgba(255,255,255,0.08);border:1px solid rgba(255,255,255,0.12);box-sizing:border-box"></div>
  <div style="position:absolute;left:280px;top:176px;width:100px;text-align:center;font-size:13px;color:#E0D8D0">Drag to install</div>
  <div style="position:absolute;left:286px;top:204px;width:80px;height:1.5px;background:#8E857B"></div>
  <div style="position:absolute;left:364px;top:199px;border-left:10px solid #8E857B;border-top:6px solid transparent;border-bottom:6px solid transparent"></div>
  <div style="position:absolute;top:366px;width:100%;text-align:center;font-size:13px;color:#8E857B">Bradley Cowdrey · bradcowdrey.com</div></body></html>`;

// The Small widget at the sample (Maroon Bells, 9:41 AM: the spot 9.2 mi at 46°, the sun at 144° and the
// moon at 258°, both up and off the half dial), in points in a 170 box, with the geometry of WidgetDial
// (Sources/Bearings/Views/WidgetViews.swift): each off-arc mark is a small glyph beside the arc's end
// with one small arrow under it, 10.9 pt from the widget's edge.
function smallWidget(px) {
  const cx = 85, cy = 118, r = 60, r0 = 57.5, rl = 39.5, pink = '#E04A7A', amber = '#F5B03C', cream = '#FFF1E5';
  const pt = (b, d) => [cx + Math.sin(b * Math.PI / 180) * d, cy - Math.cos(b * Math.PI / 180) * d];
  let o = `<rect width="170" height="170" rx="22" fill="#000"/>
    <defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3D74B0"/><stop offset="1" stop-color="#1C3A5E"/></linearGradient></defs>
    <rect x="8" y="8" width="154" height="40" rx="14" fill="url(#sky)"/>
    <text x="20" y="26" font-size="15" font-weight="600" fill="#fff">Maroon Bells</text>
    <text x="20" y="41" font-size="12" fill="rgba(255,255,255,0.75)">as of 9:41 AM</text>
    <path d="M${cx - r} ${cy} A${r} ${r} 0 0 1 ${cx + r} ${cy} Z" fill="#151515" stroke="rgba(255,255,255,0.16)"/>`;
  for (let d = -90; d <= 90; d += 10) {
    const major = d % 30 === 0, [x1, y1] = pt(d, r0), [x2, y2] = pt(d, r0 - (major ? 8 : 4.5));
    o += `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${d === 0 ? pink : major ? '#fff' : 'rgba(255,255,255,0.55)'}" stroke-width="${major ? 1.6 : 1}" stroke-linecap="round"/>`;
  }
  const letter = (t, b, d, size, weight, fill) => { const [x, y] = pt(b, d); return `<text x="${x}" y="${y}" font-size="${size}" font-weight="${weight}" fill="${fill}" text-anchor="middle" dominant-baseline="central">${t}</text>`; };
  o += letter('N', 0, rl, 14, 700, pink) + letter('E', 90, rl + 0.6, 12, 600, '#fff') + letter('W', 270, rl + 0.6, 12, 600, '#fff');
  o += `<line x1="${cx - 32.3}" y1="${cy}" x2="${cx + 32.3}" y2="${cy}" stroke="rgba(255,255,255,0.22)"/>`;
  // The spot: a dashed line from you and a teardrop on the rim.
  const hs = 5.6, head = r0 - hs - 0.5, tip = head - hs * 2.1, [lx1, ly1] = pt(46, 4), [lx2, ly2] = pt(46, tip - 1);
  const pin = (h, t, k) => `M0 ${-t} C${-k * 0.5} ${-h + k * 1.2} ${-k} ${-h + k * 0.7} ${-k} ${-h} A${k} ${k} 0 0 1 ${k} ${-h} C${k} ${-h + k * 0.7} ${k * 0.5} ${-h + k * 1.2} 0 ${-t} Z`;
  o += `<line x1="${lx1}" y1="${ly1}" x2="${lx2}" y2="${ly2}" stroke="${pink}" stroke-opacity="0.75" stroke-width="1.3" stroke-dasharray="2.5 2.5" stroke-linecap="round"/>
    <g transform="translate(${cx} ${cy}) rotate(46)"><path d="${pin(head, tip, hs)}" fill="${pink}" stroke="#000" stroke-width="1.2"/><circle cx="0" cy="${-head}" r="${hs * 0.38}" fill="#fff"/></g>
    <circle cx="${cx}" cy="${cy}" r="2.4" fill="#fff"/>
    <rect x="${cx - 22}" y="${cy - r * 0.38 - 8}" width="44" height="16" rx="8" fill="rgba(0,0,0,0.72)" stroke="${pink}" stroke-opacity="0.55"/>
    <text x="${cx}" y="${cy - r * 0.38}" font-size="11" font-weight="600" fill="#fff" text-anchor="middle" dominant-baseline="central">9.2 mi</text>`;
  // The edge marks: glyph 8.5 outside the rim and 5 above the horizon, the arrow 12 under it.
  const arrow = (x, y, b, fill) => `<path d="M0 -3.8 L3.2 3.2 L-3.2 3.2 Z" fill="${fill}" transform="translate(${x} ${y}) rotate(${b})"/>`;
  const sx = cx + r + 8.5, mx = cx - r - 8.5, ey = cy - 5;
  let rays = '';
  for (let i = 0; i < 8; i++) rays += `<line x1="${sx}" y1="${ey - 2.6 * 1.45}" x2="${sx}" y2="${ey - 5.2}" stroke="${amber}" stroke-width="1" stroke-linecap="round" transform="rotate(${i * 45} ${sx} ${ey})"/>`;
  o += `<circle cx="${sx}" cy="${ey}" r="2.6" fill="${amber}"/>${rays}${arrow(sx, ey + 12, 144, amber)}
    <circle cx="${mx}" cy="${ey}" r="4.2" fill="#4A443D"/><path d="M${mx} ${ey - 4.2} A4.2 4.2 0 0 0 ${mx} ${ey + 4.2} Z" fill="${cream}"/>${arrow(mx, ey + 12, 258, cream)}
    <text x="85" y="158" font-size="30" font-weight="500" fill="#fff" text-anchor="middle" letter-spacing="-0.6">9,587<tspan font-size="15" fill="rgba(255,255,255,0.75)" letter-spacing="0"> ft</tspan></text>`;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${px}" height="${px}" viewBox="0 0 170 170" font-family="Inter,Roboto,-apple-system,system-ui,sans-serif">${o}</svg>`;
}

(async () => {
  const browser = await playwright.chromium.launch();
  const page = await browser.newPage();
  async function svg(markup, out, size, transparent) {
    await page.setViewportSize({ width: size, height: size });
    await page.setContent(`<html><body style="margin:0;background:transparent">${markup.replace('width="1024" height="1024"', `width="${size}" height="${size}"`)}</body></html>`);
    fs.mkdirSync(path.dirname(out), { recursive: true });
    await page.screenshot({ path: out, omitBackground: !!transparent });
  }
  await svg(mac, path.join(root, 'Resources/AppIcon.png'), 1024, true);
  const appicon = path.join(root, 'Resources/iOS/Assets.xcassets/AppIcon.appiconset');
  await svg(ios('light'), path.join(appicon, 'AppIcon.png'), 1024);
  await svg(ios('dark'), path.join(appicon, 'AppIcon-dark.png'), 1024);
  await svg(ios('tinted'), path.join(appicon, 'AppIcon-tinted.png'), 1024);
  await svg(ios(), path.join(root, 'docs/icon.png'), 512);
  const res = path.join(root, 'android/app/src/main/res');
  for (const [d, px] of [['mdpi', 48], ['hdpi', 72], ['xhdpi', 96], ['xxhdpi', 144], ['xxxhdpi', 192]]) {
    await svg(ios(), path.join(res, `mipmap-${d}/ic_launcher.png`), px);
    await svg(fg, path.join(res, `mipmap-${d}/ic_launcher_foreground.png`), Math.round(px * 108 / 48), true);
  }
  await svg(ios(), path.join(res, 'drawable-nodpi/app_mark.png'), 256);
  // Android's widget picker shows this before the widget is added: the small widget at the sample place.
  await page.setViewportSize({ width: 220, height: 220 });
  await page.setContent(`<html><body style="margin:0;background:transparent">${smallWidget(220)}</body></html>`);
  await page.screenshot({ path: path.join(res, 'drawable-nodpi/widget_preview.png'), omitBackground: true });
  for (const [s, name] of [[1, 'background.png'], [2, 'background@2x.png']]) {
    await page.setViewportSize({ width: 660 * s, height: 400 * s });
    await page.setContent(dmg(s));
    fs.mkdirSync(path.join(root, 'Resources/dmg'), { recursive: true });
    await page.screenshot({ path: path.join(root, 'Resources/dmg', name) });
  }
  await browser.close();
  console.log('Drew the icons and the DMG background');
})();
