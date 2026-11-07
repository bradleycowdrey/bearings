// Draws Bearings' icons and DMG background with Playwright (Chromium), in the style of Two Degrees:
// the app's sky (day blue fading to night navy), white ticks and needle, pink north, and the crimson
// band shared by every Bradley Cowdrey app. Writes:
//   Resources/AppIcon.png (Mac, 1024, rounded with margin)  Resources/iOS/Assets.xcassets/AppIcon.appiconset/AppIcon.png (full bleed)
//   docs/icon.png (512)  Resources/dmg/background.png and background@2x.png  android/.../mipmap-*/ic_launcher*.png
// Usage: node scripts/make-art.js
const path = require('path');
const fs = require('fs');
let playwright;
try { playwright = require('playwright'); } catch { playwright = require(path.join(require('child_process').execSync('npm root -g').toString().trim(), 'playwright')); }
const root = path.resolve(__dirname, '..');

// The compass needle on a ring of ticks, in a 1024 box, centred at (cx, cy) with radius r.
function needle(cx, cy, r) {
  let ticks = '';
  for (let d = 0; d < 360; d += 15) {
    const major = d % 90 === 0;
    ticks += `<line x1="${cx}" y1="${cy - r}" x2="${cx}" y2="${cy - r + (major ? r * 0.16 : r * 0.08)}" stroke="${d === 0 ? '#E04A7A' : major ? '#FFFFFF' : 'rgba(255,255,255,0.5)'}" stroke-width="${major ? r * 0.045 : r * 0.022}" stroke-linecap="round" transform="rotate(${d} ${cx} ${cy})"/>`;
  }
  const w = r * 0.24, len = r * 0.74;
  return `<circle cx="${cx}" cy="${cy}" r="${r}" fill="rgba(255,255,255,0.06)" stroke="rgba(255,255,255,0.22)" stroke-width="${r * 0.03}"/>${ticks}
    <path d="M${cx} ${cy - len} L${cx + w} ${cy} L${cx - w} ${cy} Z" fill="#E04A7A"/>
    <path d="M${cx} ${cy + len} L${cx - w} ${cy} L${cx + w} ${cy} Z" fill="#FFFFFF"/>
    <circle cx="${cx}" cy="${cy}" r="${r * 0.07}" fill="#14213A"/>`;
}

const glow = `<defs>
  <linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3D74B0"/><stop offset="0.5" stop-color="#1C3A5E"/><stop offset="1" stop-color="#0A0E1C"/></linearGradient>
  <filter id="grain"><feTurbulence type="fractalNoise" baseFrequency="0.85" numOctaves="2" stitchTiles="stitch"/><feColorMatrix type="saturate" values="0"/></filter>
  <clipPath id="sq"><rect x="100" y="100" width="824" height="824" rx="185"/></clipPath>
  <filter id="sh" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="12" stdDeviation="14" flood-opacity=".35"/></filter></defs>`;

const mac = `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">${glow}
  <g filter="url(#sh)"><rect x="100" y="100" width="824" height="824" rx="185" fill="url(#g)"/></g>
  <g clip-path="url(#sq)"><rect x="100" y="100" width="824" height="824" filter="url(#grain)" opacity="0.05"/><rect x="100" y="100" width="824" height="28" fill="#990F3D"/></g>
  ${needle(512, 526, 300)}</svg>`;
const ios = `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">${glow}
  <rect width="1024" height="1024" fill="url(#g)"/><rect width="1024" height="1024" filter="url(#grain)" opacity="0.05"/><rect width="1024" height="34" fill="#990F3D"/>
  ${needle(512, 522, 370)}</svg>`;
const fg = `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">${needle(512, 512, 250)}</svg>`;
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
  await svg(ios, path.join(root, 'Resources/iOS/Assets.xcassets/AppIcon.appiconset/AppIcon.png'), 1024);
  await svg(ios, path.join(root, 'docs/icon.png'), 512);
  const res = path.join(root, 'android/app/src/main/res');
  for (const [d, px] of [['mdpi', 48], ['hdpi', 72], ['xhdpi', 96], ['xxhdpi', 144], ['xxxhdpi', 192]]) {
    await svg(ios, path.join(res, `mipmap-${d}/ic_launcher.png`), px);
    await svg(fg, path.join(res, `mipmap-${d}/ic_launcher_foreground.png`), Math.round(px * 108 / 48), true);
  }
  await svg(ios, path.join(res, 'drawable-nodpi/app_mark.png'), 256);
  // Android's widget picker shows this before the widget is added: the small widget at the sample place.
  await page.setViewportSize({ width: 220, height: 220 });
  await page.setContent(`<html><body style="margin:0;background:transparent;font-family:Inter,-apple-system,system-ui,sans-serif">
    <div style="width:220px;height:220px;border-radius:28px;background:#1A1816;color:#fff;box-sizing:border-box;padding:18px 18px 16px;position:relative;overflow:hidden">
      <div style="position:absolute;inset:0 0 auto;height:4px;background:#990F3D"></div>
      <div style="font-size:15px;font-weight:600;letter-spacing:-.2px;line-height:19px">Maroon Bells,<br>Colorado</div>
      <div style="margin-top:16px;font-size:38px;font-weight:600;letter-spacing:-1.5px;line-height:40px">9,587 ft</div>
      <div style="font-size:17px;color:#B0A898;font-weight:500">2,922 m</div>
      <div style="position:absolute;left:18px;bottom:16px;font-size:12px;color:#E0D8D0;line-height:16px">39.09898° N<br>106.94117° W</div>
    </div></body></html>`);
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
