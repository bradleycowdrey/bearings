# Research: what the leading compass apps do

A survey of the most-used compass, coordinates and altimeter apps, made before building Bearings (November 2026).
It records what Bearings borrows and what it avoids. Two sources (the OSM tile policy and the Open-Meteo pages)
were read through secondary pages, so check the primary pages before relying on them.

## The apps

| App | Main screen | Loved | Complaints |
|---|---|---|---|
| Apple Compass (iOS) | Large dial, heading in degrees and a direction; coordinates and elevation below; a level | Clean, no ads; tap the coordinates to open Maps | Few coordinate formats; no map |
| Google Maps / Samsung Compass | Heading cone on the map | Built in | Repeated figure-8 calibration prompts |
| Commander Compass | Military dial, map, GPS details, speed, altitude, converter | Huge feature set | Closed to new users in 2024; map styles behind a subscription |
| Spyglass | Heads-up display over the camera; rose over a map when flat | Many coordinate formats | Moved to a subscription; steep learning curve |
| Compass 55 | Dial and map, six coordinate formats, altitude | Offline declination (World Magnetic Model) | Map layers behind a Pro pack |
| Compass Galaxy, Digital Compass | Big dial | Simple | Ads; drift near magnets; nagging calibration |
| My Altitude | Coordinates, altitude, pressure | Sea-level height from terrain data | Upsells |
| Theodolite | Camera overlay with position and angles | Geotagged photos | Paid; not survey grade |
| GPS Status & Toolbox | Satellites, accuracy, compass, level | Detailed | Ads and upsell |
| Gaia GPS | Topo map first | Maps | About $60 a year |

Open source: [Trail Sense](https://github.com/kylecorry31/Trail-Sense) (smoothing, sensor status, barometer anchored
to GPS), [Kr0oked/Compass](https://github.com/Kr0oked/Compass) (true or magnetic north, no trackers),
[GPSTest](https://github.com/barbeau/gpstest) (accuracy guide). There is no mature open-source SwiftUI compass for
iPhone, which Bearings fills.

## What Bearings adopts

- One screen: the dial and a digital heading on top, then a 2 × 2 grid (latitude, longitude, elevation with its
  source, accuracy), then a small map.
- Tap the coordinates to switch format: decimal degrees, degrees minutes seconds, degrees and decimal minutes, UTM,
  MGRS and Plus Code. A Copy button for each.
- True or magnetic north, with the declination shown.
- Tap the dial to lock a bearing (Apple's pattern); the bezel shows how far you've turned from it.
- A bubble level in the middle of the dial.
- A calibration hint only when the compass reports low accuracy, never on every launch.
- Honest accuracy: ± metres for position and elevation, ± degrees for heading; stale values are greyed.
- Works offline: compass and coordinates need no network; the map and terrain elevation say when they can't load.

## Pitfalls avoided

- Wrap-around: headings are smoothed as vectors (sin/cos) and the dial turns the short way past north.
- Screen rotation and tilt: Android uses the rotation-vector sensor remapped to the display; iPhone and iPad set
  `headingOrientation` to the interface orientation.
- GPS altitude is not sea level on Android (it's above the WGS84 ellipsoid, up to ±100 m off). Bearings converts
  it with `AltitudeConverter` (Android 14+) and otherwise uses terrain elevation. iPhone's `CLLocation.altitude`
  is already above sea level.
- No ads, no trackers, no Google Play services.
- No direct use of `tile.openstreetmap.org`: its policy forbids that for distributed apps. Android and the web use
  MapLibre with OpenFreeMap's free, keyless OpenStreetMap tiles; Apple platforms use MapKit.

## Data sources

- **Open-Meteo Elevation API** (Copernicus DEM GLO-90, 90 m): free for non-commercial use, no key; credit
  Open-Meteo and the Copernicus programme. Used for ground elevation, with the position rounded to about 100 m.
- **OpenFreeMap** (OpenMapTiles schema, OpenStreetMap data, ODbL): free, no key; attribution shown on the map.
- **Apple MapKit**: included with the Apple Developer Program; Apple's legal label stays visible.
