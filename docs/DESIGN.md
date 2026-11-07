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

The "Instrument panel" of [REFINE.md](REFINE.md) §3: one fixed screen where every fact appears once,
nothing is cut off and nothing is left empty. Sizes, the planner, the four layouts and their numbers are
in [LAYOUTS.md](LAYOUTS.md), which wins over this page for layout.

The apps look like Two Degrees: a black screen with white type, a sky-coloured header and frosted tiles
with small uppercase captions, the same tile as the widgets. The exact colours, sizes and tokens are in
[LOOK.md](LOOK.md). Inside the app the highlights are white, and pink means north only. The warm
near-black, cream and crimson stay on the widgets, the Terms screen and the app mark.

Spacing uses the tokens 4 / 8 / 12 / 16 / 24, frozen: spare height goes to the dial, the map card and
Medium's tiles, never into wider gaps ([REFINE.md](REFINE.md) C3.3). Screen margins are 16; on iPad the
column is min(W − 48, 720), centred. Tiles have radius 16 and insets 10 (14 on iPad). Every control is at
least 44 × 44 (48 dp on Android).

1. **Header bar** (48 high, pinned 8 under the safe area in every layout and state): the full place
   ("Maroon Bells, Colorado", 17 semibold; the state is never dropped: the date shortens first, then the
   title wraps) over the date and time ("Sun, Nov 1 · 9:41 AM", 13, the device's 12- or
   24-hour setting, updated each minute), on a sky that follows the sun's altitude where you are: deep navy
   at night, steel blue around sunrise and sunset, clear blue by day (grey before a fix). At the trailing
   end: the sun, sunrise, sunset or moon symbol, the map button (Large and Extra Large), and the ⋯ menu,
   always in the same place. The time is never cut off: the date shortens to "Nov 1" first. The Sample pill
   always trails the date line. While finding the place: "Finding where you are…".
   With no location: "Bearings". With no place within 200 km: "Far from any town". There is no
   "Bearings" title on the screen; it stays the accessibility title.
2. **Dial**: sized by the chosen **Layout**'s rule (Small, Medium, Large, Extra Large; [LAYOUTS.md](LAYOUTS.md)
   §4), 12 above the readout's digits. On a faint white disc are ticks every 2°, numbers every 30°, the points in
   white and N in pink. Also on the card:
   - **Sun**: an amber disc with eight short rays at the sun's azimuth, radius 118 (inside the numbers);
     at 35% opacity when it's below the horizon.
   - **Moon**: a cream crescent (drawn for its phase) at the moon's azimuth, same radius; 35% below the horizon.
   - **Marked spot**: a white teardrop pin on the outer ring at the spot's bearing.
   - **Locked bearing**: the white notch and arc.
   Fixed on top: the white lubber triangle. In the middle, the level (green when within 2° of flat).
   With no compass the whole rose drops to 40%, the lubber, lock arc and map cone are hidden, and a 28 pt
   "no compass" glyph (`location.slash`) sits in the middle.
3. **Readout**: "228°" (56 light, tabular; 70 at Extra Large; 96 on iPad) and "SW" (half size, medium,
   white at 60%), on one baseline. With no compass: a dash **drawn as a bar** (0.5 em × 0.08 em, white at
   40%) on the digits' cap-height midline, with "°" where it sits after "228"; no separate caption.
   VoiceOver and TalkBack say "Heading unavailable".
4. **Status line** (13, white at 60%, centred, one line): "True north · 8° E declination · ±8° accuracy".
   A warning replaces it in amber semibold: "Magnet or metal nearby: move away" (field outside 20–70 µT),
   or "Low accuracy: move your phone in a figure 8". With no compass: "No compass · position, sun and
   map still work" (two lines allowed, wrapping at the "·").
5. **Lock row** (only when a bearing is locked): one component on every port, 52 high on a maroon fill:
   "Locked 240°" leading, "turn 12° right" trailing in semibold, ✕ to unlock. Values never break inside.
6. **Spot row** (only when a spot is marked): the same two-column row on the tile fill, "Marked spot" and
   "9.2 mi · 46° NE", ✕; tapping it offers Lock to Spot and Clear Marked Spot.
7. **Tiles**, one labelled grid (caption, value, secondary line), frosted white at 8% with a faint edge.
   Captions are text only, at the top; every value's last line sits 10 from the bottom. The grid depends
   on the layout: three columns with the Map tile (Medium), 2 × 2 (Large), or one row (Small, Extra Large):
   - **Position** (two units wide, captioned with the format, "POSITION · DD"): latitude over longitude in
     the current format, never cut off (it scales down a little, then wraps). Tap to switch format;
     long-press to copy or open the details. Dims when the fix is stale.
   - **Elevation**: "9,587 ft" over "2,922 m", metres first if chosen.
   - **Sun**: "↑ 6:36 AM" over "↓ 5:08 PM" (one time formatter on every platform); polar day or night:
     "Up all day" / "Down all day". In the one-row grid (Small, Extra Large) the moon rides in its caption,
     "SUN · ◐ 53%", and the times may wrap to "6:36" over "AM", never "6:36…".
   - **Moon**: the phase glyph and "53%" over "Last quarter".
   - **Map** (Medium only): a thumbnail with your position (on Apple a still snapshot when under 160
     wide), "MAP" on a bottom scrim; tap for the map sheet.
   A grown tile keeps its caption at the top and its value at the bottom, so it is never half empty.
   Elevation, Sun and Moon open the **Details** sheet: accuracy ("±16 ft · Just now"), the source ("GPS
   ±4 m" or "Terrain data"), pressure ("29.92 inHg" or "1,013 hPa") with a barometer, the format's name,
   the moon's phase name and the sun's and moon's rise and set directions. Before the first fix the tiles
   show "—" and "Finding position…".
8. **Map**: shown whole or not at all, as the Map tile (Medium), a full-width card where at least 140
   fits (Small; Medium with 160 or more to spare; no compass; landscape), or the header's map button (Large
   and Extra Large, on every device);
   each opens the full-height **map sheet** (full-bleed, a "Map" bar with Done). Controls in one vertical
   stack at the top right in 36 frosted circles, on every platform: +, −, the heading button (north up ↔
   follow heading), and open in Maps (on a card under 192 tall: +, − and ⋯ for the other two). A chip with the speed at the top left when moving faster than
   0.5 m/s ("3.2 mph"). Attribution stays visible. Your position is a white dot with a white heading cone.

On iPad the same column (at most 720 wide) with a larger type ramp; on the Mac the same column. Wide
windows and phones on their side use two panes, the dial and readout centred on the left, the rows and map
card on the right ([LAYOUTS.md](LAYOUTS.md) §5). "Made by Bradley Cowdrey" is in the ⋯ menu on every layout
and platform. The Mac window hides its title bar and keeps 24 from every edge. The web page keeps its
current look for now.

**The menu**: Layout (Small "Compass + big map", Medium "Balanced · map tile", Large "Bigger compass ·
map in header", Extra Large "Biggest compass · one row") · Coordinates (the six formats) · Units: Feet First, Metres First · North: True North,
Magnetic North · Map: Follow Heading, Open in Maps, and on Apple Standard / Satellite · Night Mode · Mark
This Spot (or Clear Marked Spot) · Lock This Bearing (or Clear) · Copy Coordinates · Share My Location… ·
Share Bearings… · Terms & Privacy · About Bearings · Made by Bradley Cowdrey.

**Night mode** turns everything red: the whole screen through a red multiply (the header's blues become
dark reds), secondary text at least `#E03020` (4.5:1 on black), and the map tinted red and dimmed so it is
never the brightest thing on screen.

**Accessibility**: VoiceOver/TalkBack read the dial as "Heading 228 degrees, southwest" (with Lock,
Larger Compass and Smaller Compass actions), every tile as one element ("Elevation, 9,587 feet, 2,922
metres"), and announce the heading at most every few seconds. Text scales with the system's text size:
values wrap rather than truncate; at larger sizes the dial shrinks so Position and Elevation stay above the
fold, and at accessibility sizes the whole screen becomes one scrolling list with a Targets card and 64-high
rows ([LAYOUTS.md](LAYOUTS.md) §7); reduce motion turns off the card's easing.

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
the warm greys, and thin dividers. Captions use the app's style (11 semibold caps, tracking 0.6): SUN, RISE
and SET with ↑ / ↓, as in the app's Sun tile. The place stays on one line (scaling to 0.8), with 16 of inset
on all four edges.

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
