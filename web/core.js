/* Bearings core: headings, coordinate formats, units, sun and moon, distances. Pure functions, no DOM.
   The Swift (Sources/BearingsCore) and Kotlin (android/.../Core.kt) versions mirror these one for one,
   and all three are checked against the same reference values. */
(function (root) {
  'use strict';

  const POINTS = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', 'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'];
  const NAMES = ['North', 'North-northeast', 'Northeast', 'East-northeast', 'East', 'East-southeast', 'Southeast', 'South-southeast',
    'South', 'South-southwest', 'Southwest', 'West-southwest', 'West', 'West-northwest', 'Northwest', 'North-northwest'];

  /** 0 ≤ angle < 360. */
  function normalize(deg) { const d = deg % 360; return d < 0 ? d + 360 : d; }
  /** The short way from `from` to `to`, in -180…180 (positive is clockwise). */
  function delta(from, to) { let d = normalize(to - from); if (d > 180) d -= 360; return d; }
  /** One of the 16 compass points. */
  function point(deg) { return POINTS[Math.round(normalize(deg) / 22.5) % 16]; }
  function pointName(deg) { return NAMES[Math.round(normalize(deg) / 22.5) % 16]; }

  /** Smooths headings as a unit vector, so 359° and 1° average to 0°, not 180°.
      `k` is how much of each new reading to take (0…1). */
  function smoother(k) {
    let x = null, y = null;
    return {
      push(deg) {
        const r = deg * Math.PI / 180;
        if (x === null) { x = Math.cos(r); y = Math.sin(r); }
        else { x += k * (Math.cos(r) - x); y += k * (Math.sin(r) - y); }
        return normalize(Math.atan2(y, x) * 180 / Math.PI);
      },
      reset() { x = y = null; },
    };
  }

  // ---------- Coordinate formats ----------

  function hemi(v, pos, neg) { return v < 0 ? neg : pos; }
  function fixed(v, n) { return v.toFixed(n); }
  function pad(v, w) { return String(v).padStart(w, '0'); }

  /** 39.73920° N */
  function dd(v, isLat) { return `${fixed(Math.abs(v), 5)}° ${isLat ? hemi(v, 'N', 'S') : hemi(v, 'E', 'W')}`; }

  /** 39° 44′ 21.1″ N (seconds to a tenth, about 3 m). */
  function dms(v, isLat) {
    const a = Math.abs(v);
    let tenths = Math.round(a * 36000);            // whole tenths of a second, so 59.95″ never shows as 60.0″
    const d = Math.floor(tenths / 36000); tenths -= d * 36000;
    const m = Math.floor(tenths / 600); tenths -= m * 600;
    return `${d}° ${pad(m, 2)}′ ${pad((tenths / 10).toFixed(1), 4)}″ ${isLat ? hemi(v, 'N', 'S') : hemi(v, 'E', 'W')}`;
  }

  /** 39° 44.352′ N (minutes to a thousandth, about 2 m). */
  function ddm(v, isLat) {
    const a = Math.abs(v);
    let th = Math.round(a * 60000);
    const d = Math.floor(th / 60000); th -= d * 60000;
    return `${d}° ${pad((th / 1000).toFixed(3), 6)}′ ${isLat ? hemi(v, 'N', 'S') : hemi(v, 'E', 'W')}`;
  }

  // UTM on WGS84 (Snyder's series: well under a metre inside a zone).
  const A = 6378137, F = 1 / 298.257223563, K0 = 0.9996;
  const E2 = F * (2 - F), EP2 = E2 / (1 - E2);
  const BANDS = 'CDEFGHJKLMNPQRSTUVWX';

  function utmZone(lat, lon) {
    let zone = Math.floor((lon + 180) / 6) + 1;
    if (lon >= 180) zone = 60;
    if (lat >= 56 && lat < 64 && lon >= 3 && lon < 12) zone = 32;                  // Norway
    if (lat >= 72 && lat < 84) {                                                  // Svalbard
      if (lon >= 0 && lon < 9) zone = 31; else if (lon >= 9 && lon < 21) zone = 33;
      else if (lon >= 21 && lon < 33) zone = 35; else if (lon >= 33 && lon < 42) zone = 37;
    }
    return zone;
  }

  /** {zone, band, easting, northing} or null near the poles (UTM covers 80° S to 84° N). */
  function utm(lat, lon) {
    if (!(lat >= -80 && lat < 84)) return null;
    const zone = utmZone(lat, lon);
    const band = BANDS[Math.min(19, Math.floor((lat + 80) / 8))];
    const phi = lat * Math.PI / 180, lam = lon * Math.PI / 180, lam0 = ((zone - 1) * 6 - 180 + 3) * Math.PI / 180;
    const s = Math.sin(phi), c = Math.cos(phi), t = Math.tan(phi);
    const N = A / Math.sqrt(1 - E2 * s * s), T = t * t, C = EP2 * c * c, Aa = c * (lam - lam0);
    const e4 = E2 * E2, e6 = e4 * E2;
    const M = A * ((1 - E2 / 4 - 3 * e4 / 64 - 5 * e6 / 256) * phi
      - (3 * E2 / 8 + 3 * e4 / 32 + 45 * e6 / 1024) * Math.sin(2 * phi)
      + (15 * e4 / 256 + 45 * e6 / 1024) * Math.sin(4 * phi)
      - (35 * e6 / 3072) * Math.sin(6 * phi));
    const easting = K0 * N * (Aa + (1 - T + C) * Aa ** 3 / 6 + (5 - 18 * T + T * T + 72 * C - 58 * EP2) * Aa ** 5 / 120) + 500000;
    let northing = K0 * (M + N * t * (Aa * Aa / 2 + (5 - T + 9 * C + 4 * C * C) * Aa ** 4 / 24
      + (61 - 58 * T + T * T + 600 * C - 330 * EP2) * Aa ** 6 / 720));
    if (lat < 0) northing += 10000000;
    return { zone, band, easting, northing };
  }

  /** 13S 500830E 4398757N */
  function utmText(lat, lon) {
    const u = utm(lat, lon);
    if (!u) return null;
    return `${u.zone}${u.band} ${Math.floor(u.easting)}E ${Math.floor(u.northing)}N`;
  }

  /** 13S DE 00830 98757 (1 m). */
  function mgrs(lat, lon) {
    const u = utm(lat, lon);
    if (!u) return null;
    const set = ((u.zone - 1) % 6) + 1;
    const cols = ['ABCDEFGH', 'JKLMNPQR', 'STUVWXYZ'][(set - 1) % 3];
    const rows = 'ABCDEFGHJKLMNPQRSTUV';
    const e100 = Math.floor(u.easting / 100000), n100 = Math.floor(u.northing / 100000);
    const col = cols[e100 - 1];
    const row = rows[(n100 + (set % 2 === 0 ? 5 : 0)) % 20];
    const e = pad(Math.floor(u.easting) % 100000, 5), n = pad(Math.floor(u.northing) % 100000, 5);
    return `${u.zone}${u.band} ${col}${row} ${e} ${n}`;
  }

  /** Open Location Code, 10 digits (about 14 m): 85FPQXGV+XX */
  function plusCode(lat, lon) {
    const ALPHA = '23456789CFGHJMPQRVWX';
    let la = Math.min(Math.max(lat, -90), 90), lo = normalize(lon + 180) - 180;
    // As the current reference does: to whole units of the 15-digit grid first (rounding away float
    // noise, so 60.39 stays 60.39), then down to 10 digits.
    let latI = Math.floor(Math.floor(Math.round((la + 90) * 2.5e7 * 1e6) / 1e6) / 3125);
    let lonI = Math.floor(Math.floor(Math.round((lo + 180) * 8192000 * 1e6) / 1e6) / 1024);
    latI = Math.min(latI, 180 * 8000 - 1);
    let code = '';
    for (let i = 0; i < 5; i++) {
      code = ALPHA[latI % 20] + ALPHA[lonI % 20] + code;
      latI = Math.floor(latI / 20); lonI = Math.floor(lonI / 20);
    }
    return code.slice(0, 8) + '+' + code.slice(8);
  }

  const FORMATS = [
    { id: 'dd', name: 'Decimal Degrees', short: 'Degrees' },
    { id: 'dms', name: 'Degrees, Minutes, Seconds', short: 'DMS' },
    { id: 'ddm', name: 'Degrees, Decimal Minutes', short: 'DDM' },
    { id: 'utm', name: 'UTM', short: 'UTM' },
    { id: 'mgrs', name: 'MGRS', short: 'MGRS' },
    { id: 'plus', name: 'Plus Code', short: 'Plus Code' },
  ];

  /** {lat, lon} strings for the paired formats, or {single} for the grid formats. */
  function format(id, lat, lon) {
    switch (id) {
      case 'dms': return { lat: dms(lat, true), lon: dms(lon, false) };
      case 'ddm': return { lat: ddm(lat, true), lon: ddm(lon, false) };
      case 'utm': return { single: utmText(lat, lon) || 'Outside UTM (polar)' };
      case 'mgrs': return { single: mgrs(lat, lon) || 'Outside MGRS (polar)' };
      case 'plus': return { single: plusCode(lat, lon) };
      default: return { lat: dd(lat, true), lon: dd(lon, false) };
    }
  }

  /** What Copy puts on the clipboard. */
  function copyText(id, lat, lon) {
    const f = format(id, lat, lon);
    return f.single || `${f.lat}, ${f.lon}`;
  }

  // ---------- Units ----------
  const FT = 0.3048;
  function group(n) { return Math.round(n).toLocaleString('en-US'); }
  /** {ft, m} as display strings: "5,280 ft", "1,609 m". */
  function elevation(m) { return { ft: `${group(m / FT)} ft`, m: `${group(m)} m` }; }
  /** ±12 m or ±39 ft. */
  function accuracy(m, feet) { return feet ? `±${group(m / FT)} ft` : `±${group(m)} m`; }
  /** Countries that use feet for elevation. */
  function prefersFeet(locale) { return /[-_](US|LR|MM)\b/i.test(locale || ''); }

  /** Where Open-Meteo is asked about: rounded to 3 decimals (about 100 m), enough for 90 m terrain data. */
  function rounded(v) { return Math.round(v * 1000) / 1000; }


  // ---------- Sun and moon (after SunCalc by Vladimir Agafonkin, BSD-2-Clause) ----------
  // Positions to a fraction of a degree and rise/set times to about a minute: plenty for a compass.
  const RAD = Math.PI / 180, DAY_MS = 86400000, J1970 = 2440588, J2000 = 2451545, OBLIQ = RAD * 23.4397;
  const toDays = (ms) => ms / DAY_MS - 0.5 + J1970 - J2000;
  const fromJulian = (j) => (j + 0.5 - J1970) * DAY_MS;
  const rightAscension = (l, b) => Math.atan2(Math.sin(l) * Math.cos(OBLIQ) - Math.tan(b) * Math.sin(OBLIQ), Math.cos(l));
  const declination = (l, b) => Math.asin(Math.sin(b) * Math.cos(OBLIQ) + Math.cos(b) * Math.sin(OBLIQ) * Math.sin(l));
  const azimuthOf = (H, phi, dec) => Math.atan2(Math.sin(H), Math.cos(H) * Math.sin(phi) - Math.tan(dec) * Math.cos(phi));
  const altitudeOf = (H, phi, dec) => Math.asin(Math.sin(phi) * Math.sin(dec) + Math.cos(phi) * Math.cos(dec) * Math.cos(H));
  const siderealTime = (d, lw) => RAD * (280.16 + 360.9856235 * d) - lw;
  const solarMeanAnomaly = (d) => RAD * (357.5291 + 0.98560028 * d);
  function eclipticLongitude(M) {
    const C = RAD * (1.9148 * Math.sin(M) + 0.02 * Math.sin(2 * M) + 0.0003 * Math.sin(3 * M));
    return M + C + RAD * 102.9372 + Math.PI;
  }
  function sunCoords(d) { const L = eclipticLongitude(solarMeanAnomaly(d)); return { dec: declination(L, 0), ra: rightAscension(L, 0) }; }
  function astroRefraction(h) { if (h < 0) h = 0; return 0.0002967 / Math.tan(h + 0.00312536 / (h + 0.08901179)); }

  /** The sun's direction: {azimuth (degrees from north, clockwise), altitude (degrees above the horizon)}. */
  function sunPosition(ms, lat, lon) {
    const lw = RAD * -lon, phi = RAD * lat, d = toDays(ms), c = sunCoords(d), H = siderealTime(d, lw) - c.ra;
    return { azimuth: normalize(azimuthOf(H, phi, c.dec) / RAD + 180), altitude: altitudeOf(H, phi, c.dec) / RAD };
  }

  /** Sunrise, sunset and solar noon for the day containing `ms` (UTC milliseconds; null rise/set when the
      sun doesn't rise or set that day). Also golden hour's start (sun 6° up) in the evening. */
  function sunTimes(ms, lat, lon) {
    const J0 = 0.0009, lw = RAD * -lon, phi = RAD * lat, d = toDays(ms);
    const n = Math.round(d - J0 - lw / (2 * Math.PI));
    const ds = J0 + (0 + lw) / (2 * Math.PI) + n;
    const M = solarMeanAnomaly(ds), L = eclipticLongitude(M), dec = declination(L, 0);
    const transit = (a) => J2000 + a + 0.0053 * Math.sin(M) - 0.0069 * Math.sin(2 * L);
    const Jnoon = transit(ds);
    const setFor = (h) => {
      const w = Math.acos((Math.sin(h) - Math.sin(phi) * Math.sin(dec)) / (Math.cos(phi) * Math.cos(dec)));
      if (Number.isNaN(w)) return null;
      return transit(J0 + (w + lw) / (2 * Math.PI) + n);
    };
    const out = { noon: fromJulian(Jnoon), sunrise: null, sunset: null, goldenHour: null };
    const set = setFor(-0.833 * RAD);
    if (set !== null) { out.sunset = fromJulian(set); out.sunrise = fromJulian(Jnoon - (set - Jnoon)); }
    const golden = setFor(6 * RAD);
    if (golden !== null) out.goldenHour = fromJulian(golden);
    // Midnight sun or polar night: which one, from the sun at noon.
    if (set === null) out.polar = altitudeOf(0, phi, dec) > 0 ? 'day' : 'night';
    return out;
  }

  function moonCoords(d) {
    const L = RAD * (218.316 + 13.176396 * d), M = RAD * (134.963 + 13.064993 * d), F = RAD * (93.272 + 13.229350 * d);
    const l = L + RAD * 6.289 * Math.sin(M), b = RAD * 5.128 * Math.sin(F), dist = 385001 - 20905 * Math.cos(M);
    return { ra: rightAscension(l, b), dec: declination(l, b), dist };
  }

  /** The moon's direction, like sunPosition (altitude corrected for refraction). */
  function moonPosition(ms, lat, lon) {
    const lw = RAD * -lon, phi = RAD * lat, d = toDays(ms), c = moonCoords(d), H = siderealTime(d, lw) - c.ra;
    let h = altitudeOf(H, phi, c.dec);
    h += astroRefraction(h);
    return { azimuth: normalize(azimuthOf(H, phi, c.dec) / RAD + 180), altitude: h / RAD };
  }

  const PHASES = ['New Moon', 'Waxing Crescent', 'First Quarter', 'Waxing Gibbous', 'Full Moon', 'Waning Gibbous', 'Last Quarter', 'Waning Crescent'];
  /** {fraction lit (0–1), phase (0 new, 0.25 first quarter, 0.5 full, 0.75 last quarter), name}. */
  function moonPhase(ms) {
    const d = toDays(ms), s = sunCoords(d), m = moonCoords(d), sdist = 149598000;
    const phi = Math.acos(Math.sin(s.dec) * Math.sin(m.dec) + Math.cos(s.dec) * Math.cos(m.dec) * Math.cos(s.ra - m.ra));
    const inc = Math.atan2(sdist * Math.sin(phi), m.dist - sdist * Math.cos(phi));
    const angle = Math.atan2(Math.cos(s.dec) * Math.sin(s.ra - m.ra), Math.sin(s.dec) * Math.cos(m.dec) - Math.cos(s.dec) * Math.sin(m.dec) * Math.cos(s.ra - m.ra));
    const fraction = (1 + Math.cos(inc)) / 2, phase = 0.5 + 0.5 * inc * (angle < 0 ? -1 : 1) / Math.PI;
    return { fraction, phase, name: PHASES[Math.round(phase * 8) % 8] };
  }

  // ---------- Distance and bearing (a marked spot) ----------
  const EARTH_R = 6371008.8;
  /** Great-circle distance in metres. */
  function distance(lat1, lon1, lat2, lon2) {
    const p1 = lat1 * RAD, p2 = lat2 * RAD, dp = (lat2 - lat1) * RAD, dl = (lon2 - lon1) * RAD;
    const a = Math.sin(dp / 2) ** 2 + Math.cos(p1) * Math.cos(p2) * Math.sin(dl / 2) ** 2;
    return 2 * EARTH_R * Math.asin(Math.min(1, Math.sqrt(a)));
  }
  /** Initial bearing from the first point to the second, degrees from true north. */
  function bearing(lat1, lon1, lat2, lon2) {
    const p1 = lat1 * RAD, p2 = lat2 * RAD, dl = (lon2 - lon1) * RAD;
    return normalize(Math.atan2(Math.sin(dl) * Math.cos(p2), Math.cos(p1) * Math.sin(p2) - Math.sin(p1) * Math.cos(p2) * Math.cos(dl)) / RAD);
  }
  /** "350 ft", "0.4 mi", "12 mi" or "120 m", "1.3 km", "12 km". */
  function distanceText(m, feet) {
    if (feet) {
      const ft = m / FT;
      if (ft < 1000) return `${group(Math.round(ft / 10) * 10)} ft`;
      const mi = m / 1609.344;
      return mi < 9.95 ? `${mi.toFixed(1)} mi` : `${group(mi)} mi`;
    }
    if (m < 1000) return `${group(Math.round(m / 5) * 5)} m`;
    const km = m / 1000;
    return km < 9.95 ? `${km.toFixed(1)} km` : `${group(km)} km`;
  }

  // ---------- Speed and pressure ----------
  /** "3.2 mph" or "5.1 km/h" (metres per second in). */
  function speedText(mps, feet) { const v = feet ? mps * 2.2369363 : mps * 3.6; return `${v < 9.95 ? v.toFixed(1) : group(v)} ${feet ? 'mph' : 'km/h'}`; }
  /** "29.92 inHg" or "1,013 hPa" (hectopascals in). */
  function pressureText(hpa, feet) { return feet ? `${(hpa * 0.0295299830714).toFixed(2)} inHg` : `${group(hpa)} hPa`; }

  // ---------- The nearest place (offline naming, from the bundled GeoNames list) ----------
  /** Parses Resources/Cities.tsv lines: name, ASCII name, region, country code, latitude, longitude. */
  function parseCities(text) {
    const out = [];
    for (const line of text.split('\n')) {
      const c = line.split('\t');
      if (c.length < 6) continue;
      const lat = Number(c[4]), lon = Number(c[5]);
      if (Number.isFinite(lat) && Number.isFinite(lon)) out.push({ name: c[0], region: c[2], country: c[3], lat, lon });
    }
    return out;
  }
  /** The listed place nearest a point, within 200 km: {name, region, country, km, from} where `from` is the
      bearing from the place to the point. */
  function nearestPlace(lat, lon, list) {
    const k = Math.cos(lat * RAD);
    let best = null, bestD = Infinity;
    for (const e of list) {
      const dy = e.lat - lat; let dx = Math.abs(e.lon - lon); if (dx > 180) dx = 360 - dx;
      const d = dy * dy + (dx * k) * (dx * k);
      if (d < bestD) { bestD = d; best = e; }
    }
    if (!best) return null;
    const km = distance(lat, lon, best.lat, best.lon) / 1000;
    return km <= 200 ? { name: best.name, region: best.region, country: best.country, km, from: bearing(best.lat, best.lon, lat, lon) } : null;
  }
  /** "Denver, Colorado" within 5 km; otherwise "28 mi SW of Glenwood Springs, Colorado". */
  function placeText(p, feet) {
    if (!p) return null;
    const where = [p.name, p.region].filter(Boolean).join(', ');
    if (p.km <= 5) return where;
    const km = p.km;
    const dist = feet ? `${group(km / 1.609344)} mi` : `${group(km)} km`;
    return `${dist} ${point(p.from)} of ${where}`;
  }


  // ---------- Magnetic declination (World Magnetic Model 2025, NOAA/NCEI and BGS, public domain) ----------
  // The web has only magnetic headings, while the sun, moon and a marked spot are true bearings; this
  // turns one into the other. Valid 2025–2030; within about half a degree almost everywhere.
  const WMM = { epoch: 2025,
    g: [0,-29351.8,-1410.8,-2556.6,2951.1,1649.3,1361,-2404.1,1243.8,453.6,895,799.5,55.7,-281.1,12.1,-233.2,368.9,187.2,-138.7,-142,20.9,64.4,63.8,76.9,-115.7,-40.9,14.9,-60.7,79.5,-77,-8.8,59.3,15.8,2.5,-11.1,14.2,23.2,10.8,-17.5,2,-21.7,16.9,15,-16.8,0.9,4.6,7.8,3,-0.2,-2.5,-13.1,2.4,8.6,-8.7,-12.9,-1.3,-6.4,0.2,2,-1,-0.6,-0.9,1.5,0.9,-2.7,-3.9,2.9,-1.5,-2.5,2.4,-0.6,-0.1,-0.6,-0.1,1.1,-1,-0.2,2.6,-2,-0.2,0.3,1.2,-1.3,0.6,0.6,0.5,-0.1,-0.4,-0.2,-1.3,-0.7],
    h: [0,0,4545.4,0,-3133.6,-815.1,0,-56.6,237.5,-549.5,0,278.6,-133.9,212,-375.6,0,45.4,220.2,-122.9,43,106.1,0,-18.4,16.8,48.8,-59.8,10.9,72.7,0,-48.9,-14.4,-1,23.4,-7.4,-25.1,-2.3,0,7.1,-12.6,11.4,-9.7,12.7,0.7,-5.2,3.9,0,-24.8,12.2,8.3,-3.3,-5.2,7.2,-0.6,0.8,10,0,3.3,0,2.4,5.3,-9.1,0.4,-4.2,-3.8,0.9,-9.1,0,0,2.9,-0.6,0.2,0.5,-0.3,-1.2,-1.7,-2.9,-1.8,-2.3,0,-1.3,0.7,1,-1.4,0,0.6,-0.1,0.8,0.1,-1,0.1,0.2],
    gd: [0,12,9.7,-11.6,-5.2,-8,-1.3,-4.2,0.4,-15.6,-1.6,-2.4,-6,5.6,-7,0.6,1.4,0,0.6,2.2,0.9,-0.2,-0.4,0.9,1.2,-0.9,0.3,0.9,0,-0.1,-0.1,0.5,-0.1,-0.8,-0.8,0.8,-0.1,0.2,0,0.5,-0.1,0.3,0.2,0,0.2,0,-0.1,0.1,0.3,-0.3,0,0.3,-0.1,0.1,-0.1,0.1,0,0.1,0.1,0,-0.3,0,-0.1,-0.1,0,0,0,0,0,0,0,-0.1,0,0,-0.1,-0.1,-0.1,-0.1,0,0,0,0,0,0,0.1,0,0,0,-0.1,0,-0.1],
    hd: [0,0,-21.5,0,-27.7,-12.1,0,4,-0.3,-4.1,0,-1.1,4.1,1.6,-4.4,0,-0.5,2.2,0.4,1.7,1.9,0,0.3,-1.6,-0.4,0.9,0.7,0.9,0,0.6,0.5,-0.8,0,-1,0.6,-0.2,0,-0.2,0.5,-0.4,0.4,-0.5,-0.6,0.3,0.2,0,-0.3,0.3,-0.3,0.3,0.2,-0.1,-0.2,0.4,0.1,0,0,0,-0.2,0.1,-0.1,0.1,0,-0.1,0.2,0,0,0,0.1,0,0.1,0,0,0.1,0,0,0,0,0,0,0,-0.1,0.1,0,0,0,0,0,0,0,-0.1] };

  /** Degrees east of true north that a compass points, at a place, height (metres) and time (UTC ms). */
  function magneticDeclination(lat, lon, heightM, ms) {
    const t = 2025 + (ms - Date.UTC(2025, 0, 1)) / (365.25 * DAY_MS) - WMM.epoch;
    const A = 6378.137, F = 1 / 298.257223563, e2 = F * (2 - F), h = (heightM || 0) / 1000;
    const phi = lat * RAD, lam = lon * RAD;
    const Rc = A / Math.sqrt(1 - e2 * Math.sin(phi) ** 2);
    const p = (Rc + h) * Math.cos(phi), z = (Rc * (1 - e2) + h) * Math.sin(phi);
    const r = Math.hypot(p, z), phiC = Math.asin(z / r);
    const x = Math.sin(phiC), s = Math.max(Math.cos(phiC), 1e-12);   // cos and sin of the colatitude
    const N = 12, P = [], dP = [];
    for (let n = 0; n <= N; n++) { P.push(new Array(N + 1).fill(0)); dP.push(new Array(N + 1).fill(0)); }
    P[0][0] = 1;
    for (let n = 1; n <= N; n++) {
      for (let m = 0; m <= n; m++) {
        if (n === m) {
          const k = n === 1 ? 1 : Math.sqrt((2 * n - 1) / (2 * n));
          P[n][n] = k * s * P[n - 1][n - 1];
          dP[n][n] = k * (s * dP[n - 1][n - 1] + x * P[n - 1][n - 1]);
        } else {
          const a1 = 2 * n - 1, a2 = n >= 2 ? Math.sqrt((n - 1) ** 2 - m * m) : 0, b = Math.sqrt(n * n - m * m);
          const p2 = n - 2 >= m ? P[n - 2][m] : 0, d2 = n - 2 >= m ? dP[n - 2][m] : 0;
          P[n][m] = (a1 * x * P[n - 1][m] - a2 * p2) / b;
          dP[n][m] = (a1 * (x * dP[n - 1][m] - s * P[n - 1][m]) - a2 * d2) / b;
        }
      }
    }
    let X = 0, Y = 0, Z = 0;
    for (let n = 1; n <= N; n++) {
      const ar = (6371.2 / r) ** (n + 2);
      for (let m = 0; m <= n; m++) {
        const i = n * (n + 1) / 2 + m;
        const g = WMM.g[i] + t * WMM.gd[i], hh = WMM.h[i] + t * WMM.hd[i];
        const c = Math.cos(m * lam), sn = Math.sin(m * lam);
        X += ar * (g * c + hh * sn) * dP[n][m];
        Y += ar * m * (g * sn - hh * c) * P[n][m] / s;
        Z -= ar * (n + 1) * (g * c + hh * sn) * P[n][m];
      }
    }
    const psi = phiC - phi;
    const Xg = X * Math.cos(psi) - Z * Math.sin(psi);
    return Math.atan2(Y, Xg) / RAD;
  }

  const api = { normalize, delta, point, pointName, smoother, dd, dms, ddm, utm, utmText, mgrs, plusCode, FORMATS, format, copyText,
    elevation, accuracy, prefersFeet, rounded, FT,
    sunPosition, sunTimes, moonPosition, moonPhase, distance, bearing, distanceText, speedText, pressureText, parseCities, nearestPlace, placeText, group, magneticDeclination };
  if (typeof module === 'object' && module.exports) module.exports = api; else root.TN = api;
})(typeof self !== 'undefined' ? self : this);
