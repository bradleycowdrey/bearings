// Writes Tests/fixtures/geo.json: expected coordinate formats for a spread of places, from web/core.js
// (itself checked against proj4, mgrs and open-location-code). The Swift and Kotlin unit tests read the
// same file, so all three apps format coordinates identically.  Usage: node scripts/make-fixtures.js
const T = require('../web/core.js');
const fs = require('fs');
const places = [
  ['Maroon Bells', 39.09898, -106.94117], ['Denver', 39.7392, -104.9903], ['London', 51.5074, -0.1278],
  ['Sydney', -33.8688, 151.2093], ['Tokyo', 35.6762, 139.6503], ['Reykjavík', 64.1466, -21.9426],
  ['Ushuaia', -54.8019, -68.303], ['Longyearbyen', 78.2232, 15.6267], ['Bergen', 60.39, 5.32],
  ['Null Island', 0.0001, 0.0001], ['Date line', -0.5, -179.9], ['Far north', 83.9, 10], ['South Pole', -89.9, 0],
  ['Everest', 27.98785, 86.92502], ['Quito', -0.1807, -78.4678], ['Cape Town', -33.9249, 18.4241],
  ['Honolulu', 21.3069, -157.8583], ['Edge of a minute', 10.99999, -20.000001], ['Anchorage', 61.2181, -149.9003],
];
let seed = 7; const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
for (let i = 0; i < 30; i++) places.push([`Random ${i + 1}`, +(rnd() * 160 - 79.9).toFixed(6), +(rnd() * 359.9 - 180).toFixed(6)]);
const out = places.map(([name, lat, lon]) => ({
  name, lat, lon,
  dd: T.copyText('dd', lat, lon), dms: T.copyText('dms', lat, lon), ddm: T.copyText('ddm', lat, lon),
  utm: T.utmText(lat, lon), mgrs: T.mgrs(lat, lon), plus: T.plusCode(lat, lon),
}));
const headings = [0, 11.24, 11.26, 22.5, 90, 180, 247, 348.74, 348.76, 359.9, -10, 725].map((h) => ({ deg: h, point: T.point(h), normalized: T.normalize(h) }));
const elevations = [0, 1609.344, 2922, 8848.86, -430.4].map((m) => ({ metres: m, ...T.elevation(m) }));
// Sun and moon at fixed moments (UTC milliseconds), at the named places and a few extremes.
const moments = [Date.UTC(2026, 10, 1, 16, 0), Date.UTC(2026, 5, 21, 12, 0), Date.UTC(2026, 11, 21, 3, 30), Date.UTC(2027, 2, 14, 22, 15)];
const sky = [];
for (const p of out.slice(0, 19)) for (const t of moments) {
  const sun = T.sunPosition(t, p.lat, p.lon), moon = T.moonPosition(t, p.lat, p.lon), times = T.sunTimes(t, p.lat, p.lon), phase = T.moonPhase(t);
  sky.push({ name: p.name, lat: p.lat, lon: p.lon, t, sunAzimuth: sun.azimuth, sunAltitude: sun.altitude, moonAzimuth: moon.azimuth, moonAltitude: moon.altitude,
    sunrise: times.sunrise, sunset: times.sunset, noon: times.noon, goldenHour: times.goldenHour, polar: times.polar || null,
    moonFraction: phase.fraction, moonPhase: phase.phase, moonName: phase.name });
}
// Distance and bearing between pairs, and how they read.
const pairs = [[39.09898, -106.94117, 39.1911, -106.8175], [51.5074, -0.1278, 48.8566, 2.3522], [-33.8688, 151.2093, -37.8136, 144.9631],
  [39.09898, -106.94117, 39.0995, -106.9411], [0, 0, 0, 180], [64.1466, -21.9426, 61.2181, -149.9003]].map(([a, b, c, d]) => {
  const m = T.distance(a, b, c, d);
  return { from: [a, b], to: [c, d], metres: m, bearing: T.bearing(a, b, c, d), feetText: T.distanceText(m, true), metresText: T.distanceText(m, false) };
});
const speeds = [0.4, 1.43, 4.45, 4.47, 13.4, 31.3].map((v) => ({ mps: v, feet: T.speedText(v, true), metric: T.speedText(v, false) }));
const pressures = [1013.25, 745.2, 1032.9].map((h) => ({ hpa: h, feet: T.pressureText(h, true), metric: T.pressureText(h, false) }));
// The nearest place in Resources/Cities.tsv.
const cities = T.parseCities(fs.readFileSync(require('path').join(__dirname, '../Resources/Cities.tsv'), 'utf8'));
const nearest = [[39.7392, -104.9903], [39.09898, -106.94117], [51.5074, -0.1278], [35.6762, 139.6503], [0, -140], [27.98785, 86.92502], [44.4280, -110.5885], [68.35, 18.83], [-33.9249, 18.4241]].map(([lat, lon]) => {
  const p = T.nearestPlace(lat, lon, cities);
  return { lat, lon, name: p ? p.name : null, region: p ? p.region : null, country: p ? p.country : null, km: p ? p.km : null, from: p ? p.from : null, feetText: T.placeText(p, true), metresText: T.placeText(p, false) };
});
fs.writeFileSync(require('path').join(__dirname, '../Tests/fixtures/geo.json'), JSON.stringify({ places: out, headings, elevations, sky, pairs, speeds, pressures, nearest }, null, 1) + '\n');
console.log(`Wrote ${out.length} places`);
