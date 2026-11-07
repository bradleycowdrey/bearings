# Bearings: design and features (0.2)

One spec for every platform: iPhone and iPad, Mac, Android and the web. Each platform follows its own
conventions (SF Pro and sheets on Apple, Material ripples and Back on Android), but the screen, the
wording and the numbers are the same everywhere. The numbers come from one core written three times
(`web/core.js`, `Sources/Bearings/Core/*.swift`, `android/.../Core.kt`) and checked against one fixture,
`Tests/fixtures/geo.json`, which `scripts/make-fixtures.js` writes from the web core.

## The top features

From the survey in [RESEARCH.md](RESEARCH.md) (Apple Compass, Commander Compass, Spyglass, Compass 55,
My Altitude, GPS Status, Gaia GPS, Trail Sense…), the features people use most, all in Bearings:

1. **Compass**: heading in degrees and points (228° SW), true north by default with the declination,
   or magnetic north. Smooth, turns the short way past north; a light haptic tick at N, E, S and W.
2. **Where you are, in words, and when**: the place ("Aspen, Colorado") with today's date and the time.
3. **Coordinates in six formats**: decimal degrees, DMS, DDM, UTM, MGRS, Plus Code. Tap to switch; copy
   and share.
4. **Elevation in feet and metres at once**, from GPS when it's accurate, otherwise terrain data; with
   barometric pressure where the device has a barometer.
5. **A map** with your position, accuracy circle and heading cone; north up or following your heading.
   Satellite view on Apple devices.
6. **Sun and moon on the dial**, with sunrise, sunset and the moon's phase.
7. **Mark a spot and find it again** ("where did I park?"): its direction on the dial and its distance.
8. **Lock a bearing** and see how far you've turned from it.
9. **A bubble level** in the middle of the dial.
10. **Honest accuracy and warnings**: ± for position and heading, a figure-8 hint only when needed, and
    a warning when a magnet or metal is throwing the compass off. Speed while you're moving.

Plus **night mode** (all red, to keep your night vision), **widgets** on every platform, and it all
works **offline** except the map and the terrain elevation.

## The one screen (phone, top to bottom)

How large each part is, what scrolls, and the four layouts are in [LAYOUTS.md](LAYOUTS.md), which wins
over this page for layout.

The apps look like Two Degrees: a black screen with white type, a large title, a sky card, and frosted
tiles with small uppercase captions. The exact colours, sizes and tokens are in [LOOK.md](LOOK.md).
Inside the app the highlights are white, and pink means north only. The warm near-black, cream and
crimson stay on the widgets, the Terms screen and the app mark.

Spacing is on a 4-point grid. Screen margins are 16, gaps between blocks 12, and tile padding 14 × 12.
The corner radius is 16 (continuous) for tiles, the sky card and the map, and 28 for the panel on the
web. Every control is at least 44 × 44.

1. **Title** (48 high): "Bearings", 34 bold, with the ⋯ menu on the right (`ellipsis.circle` on Apple
   devices; a faint white circle on Android). The title row is dropped first when space is short ([LAYOUTS.md](LAYOUTS.md) §4), and the
   menu sits in the sky card's corner.
2. **Sky card**: the place name (20 semibold, one line, ends with … if long) over the date and time
   ("Sat, Nov 1 · 9:41 AM", 14, the device's 12- or 24-hour setting, updated each minute). Both are
   white on a sky that follows the sun's altitude where you are: deep navy at night, steel blue around
   sunrise and sunset, clear blue by day (grey before a fix). A small sun, sunrise, sunset or moon
   symbol sits in the corner. While finding the place: "Finding where you are…". With no location:
   "Bearings". With no place within 200 km, the coordinates' region is skipped and the line reads
   "Far from any town".
3. **Dial**: sized first, as a share of the screen's height set by the **Layout** setting (Small, Medium,
   Large, Extra Large; never under 40% of the height in a portrait column): see [LAYOUTS.md](LAYOUTS.md),
   which replaces the old "36% of the height and 360" rule. On a faint white disc are
   ticks every 2°, numbers every 30°, the points in white and N in pink. Also on the card:
   - **Sun**: an amber disc with eight short rays at the sun's azimuth, radius 118 (inside the numbers);
     at 35% opacity when it's below the horizon.
   - **Moon**: a cream crescent (drawn for its phase) at the moon's azimuth, same radius; 35% below the horizon.
   - **Marked spot**: a white teardrop pin on the outer ring at the spot's bearing.
   - **Locked bearing**: the white notch and arc.
   Fixed on top: the white lubber triangle. In the middle, the level (green when within 2° of flat).
4. **Readout**: "228°" (56 light, tabular) and "SW" (28 medium, white at 60%), on one baseline.
5. **Subline** (13, white at 60%, centred, one line): "True north · 8° E · ±8°". When there's a warning,
   it replaces the subline in amber semibold: "Magnet or metal nearby: move away" (field outside
   20–70 µT), or "Low accuracy: move your phone in a figure 8". The locked bearing adds "· Locked 240°
   · turn 12° right" in white semibold.
6. **Marked spot** (only when one is marked): one line, "📍 Marked spot · 0.4 mi · 245° SW", with a ✕ to
   clear; tapping the line offers Lock to Spot and Clear Marked Spot. Its size and place:
   [LAYOUTS.md](LAYOUTS.md) §3.1.
7. **Tiles**, 2 × 2, frosted, in the scrolling **Details** under the head, after a one-row summary strip
   (coordinates, elevation, sun) and the map: the order and heights are in [LAYOUTS.md](LAYOUTS.md) §3.2.
   The tiles are white at 8%, with a faint edge. Each has a small uppercase caption with a
   symbol (LATITUDE, LONGITUDE, ELEVATION, SUN):
   - **Latitude** / **Longitude**: the value (20 medium); details "±16 ft · Just now" (latitude) and the
     format's name (longitude). Tap either to switch format; long-press to copy. UTM, MGRS and Plus Code
     take one wide tile titled with the format's name.
   - **Elevation**: "9,587 ft" with "2,922 m" beside it (smaller, muted), metres first if chosen; detail
     "GPS ±4 m", or "Terrain data", plus " · 29.92 inHg" (or "1,013 hPa") with a barometer.
   - **Sun**: "6:42 AM – 5:01 PM" (sunrise–sunset); detail "Waxing Gibbous · 82%" with the moon glyph.
     Polar day or night: "Sun up all day" / "Sun down all day".
8. **Map**: a rounded card in Details, between the summary strip and the tiles; how tall it is and whether
   it shows on the first screen depend on the layout ([LAYOUTS.md](LAYOUTS.md) §3.2). Controls top right in 32 frosted circles: +, −, the heading button
   (north up ↔ follow heading), and open in Maps. A chip with the speed (top left on Apple devices, clear of the Apple Maps label; bottom left elsewhere) when moving faster
   than 0.5 m/s ("3.2 mph"). Attribution stays visible. Your position is a white dot with a white heading
   cone.

On a Mac and on the web (wider than a phone), the same column (at most 760 wide; wide windows put Details
in a column beside the dial, [LAYOUTS.md](LAYOUTS.md) §7), with the footer
"Made by Bradley Cowdrey · bradcowdrey.com ↗" at the end of Details. On a phone the footer is in About. The
Mac window hides its title bar, so the large title isn't doubled. The web page keeps its current look
for now.

**The menu**: Layout (Small, Medium, Large, Extra Large) · Coordinates (the six formats) · Units: Feet First, Metres First · North: True North, Magnetic
North · Map: Follow Heading, Open in Maps, and on Apple Standard / Satellite · Night Mode · Mark This Spot (or Clear
Marked Spot) · Lock This Bearing (or Clear) · Copy Coordinates · Share My Location… · Share Bearings… ·
Terms & Privacy · About Bearings.

**Night mode** turns everything red: the whole screen through a red multiply (the sky card's blues
become dark reds), the map dimmed.

**Accessibility**: VoiceOver/TalkBack read the dial as "Heading 228 degrees, southwest", every tile as one
element ("Elevation, 9,587 feet, 2,922 metres, from GPS"), and announce the heading at most every few
seconds. Text scales with the system's text size; the layout gives things up in a fixed order and Details scrolls
rather than squeezing the dial ([LAYOUTS.md](LAYOUTS.md) §4 and §8, which also lists the dial's spoken
value and actions); reduce motion turns off the card's easing.

## Where the place name comes from

The device's own geocoder first (Apple's on iPhone, iPad and Mac; Android's `Geocoder` where the phone
has one): locality, then administrative area ("Aspen, Colorado"). If there isn't one, or it fails
(offline), the nearest place in `Resources/Cities.tsv` (GeoNames, 15,000+ people): its name within 5 km,
otherwise "66 mi NE of Montrose, Colorado" up to 200 km (`placeText`). The web uses the list only.
Asked again after moving 500 m.

## Widgets

Widgets can't run the compass, so they show where you are, and the sky. The app saves its last fix
(latitude, longitude, accuracy, elevation and its source, the place name, the time) to shared storage
(an App Group on Apple; the app's preferences on Android); widgets refresh every 30 minutes, ask for a
fresh location themselves where the system allows it (Apple's `NSWidgetWantsLocation`; Android's last
known location with the permission), look up the elevation if needed, and work out the sun and moon for
the time of each entry.

They follow Two Degrees' widgets: warm near-black with the crimson rule along the top, white type and
the warm greys, and thin dividers.

- **Small**: the place (two lines at most) with a sun or moon symbol, the elevation large ("9,587 ft")
  with metres under it, the coordinates small.
- **Medium**: the small widget on the left. On the right are three columns, as Two Degrees' hours: the
  sun's direction on a small compass rose, sunrise, and sunset. The moon's phase is under them.
- **Large**: a map of where you are (Apple: a MapKit snapshot; Android: the info grid instead) with all
  of the above, and the marked spot's distance and direction if there is one.
- **Lock Screen (iPhone)**: inline "⛰ 9,587 ft · Aspen", rectangular (place, elevation, coordinates),
  circular (elevation, "9.6k ft").
- Every widget says when its data is from ("9:41 AM"), opens the app when tapped, and follows the app's
  units and coordinate format. Before the app has a location: "Open Bearings to find where you are."

Mac: small, medium and large desktop and Notification Center widgets. iPhone and iPad: Home Screen
small, medium, large; Lock Screen inline, rectangular, circular. Android: one widget that resizes (2×2,
4×2, 4×4).
