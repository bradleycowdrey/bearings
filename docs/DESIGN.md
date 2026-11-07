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

The "Instrument panel" (Concept A, Option 1; [REFINE.md](REFINE.md) "Concept A"): one fixed screen where
every fact appears once, nothing is cut off and nothing is left empty. The compass comes first, at the top,
and is always at least 40% of the screen height in portrait. Sizes, the planner, the four layouts and their
numbers are in [LAYOUTS.md](LAYOUTS.md), which wins over this page for layout.

The apps look like Two Degrees: a black screen with white type, a sky-coloured location card and frosted
tiles with small uppercase captions, the same tile as the widgets. The exact colours, sizes and tokens are
in [LOOK.md](LOOK.md). Inside the app the highlights are white, and pink means north only. The warm
near-black, cream and crimson stay on the widgets, the Terms screen and the app mark.

Spacing uses frozen tokens: spare height goes to each layout's tiles or map card, then the dial, never into
wider gaps ([REFINE.md](REFINE.md) A.1). Screen margins are 16; on iPad the column is min(W − 48, 720),
centred; on the Mac 24. Tiles have radius 16. Every control is at least 44 × 44 (48 dp on Android).

The order, top to bottom: **dial → readout → status line → location card → Targets card → the layout's
tiles or map.** Nothing is pinned to the status bar: the dial's top is 18 below the safe area (iPhone 16
Pro: 80).

1. **Dial**: sized by the chosen **Layout**'s rule (Small, Medium, Large, Extra Large; [LAYOUTS.md](LAYOUTS.md)
   §2), never under 40% of the screen height in portrait, 12 above the readout's digits. On a faint white
   disc are ticks every 2°, numbers every 30°, the points in white and N in pink. Also on the card:
   - **Sun**: an amber disc with eight short rays at the sun's azimuth, radius 118 (inside the numbers);
     at 35% opacity when it's below the horizon.
   - **Moon**: a cream crescent (drawn for its phase) at the moon's azimuth, same radius; 35% below the horizon.
   - **Marked spot**: a white teardrop pin on the outer ring at the spot's bearing.
   - **Locked bearing**: the white notch and arc.
   Fixed on top: the white lubber triangle. In the middle, the level (green when within 2° of flat).
   With no compass the whole rose drops to 40%, the lubber, lock arc and map cone are hidden, and a 28 pt
   "no compass" glyph (`location.slash`) sits in the middle. The dial drawing is unchanged by Concept A.
2. **Readout**: "228°" (56 light, tabular; 70 at Extra Large; 96 on iPad) and "SW" (half size, medium,
   white at 60%), on one baseline. Unchanged. With no compass the words **"No heading"** (34 semibold,
   white at 55%) take its slot, which keeps its height so nothing below moves. VoiceOver and TalkBack say
   "Heading unavailable", once.
3. **Status line** (13, white at 60%, centred, one line): "True north · 8° E declination · ±8° accuracy".
   A warning replaces it in amber semibold: "Magnet or metal nearby: move away" (field outside 20–70 µT),
   or "Low accuracy: move your phone in a figure 8". With no compass: "Position, sun and map still work".
4. **Location card** (48 high, radius 14, 12 under the status line; the sky card, formerly the header): the
   full place ("Maroon Bells, Colorado", 17 semibold, never truncated; it may wrap at large text) over the
   date and time ("Sun, Nov 1 · 9:41 AM", 13, white at 75%, the device's 12- or 24-hour setting, updated
   each minute), on a sky that follows the sun's altitude where you are: deep navy at night, steel blue
   around sunrise and sunset, clear blue by day (grey before a fix). The Sample pill trails the date line.
   At the trailing end, in fixed order: the sun, sunrise, sunset or moon symbol, the map button (Large and
   Extra Large), and the **⋯** menu. While finding the place: "Finding where you are…". With no location:
   "Bearings". With no place within 200 km: "Far from any town". There is no "Bearings" title on the
   screen; it stays the accessibility title.
5. **Targets card** (only when a bearing is locked or a spot is marked, 8 under the location card): one
   card with only the rows that exist, 44 high each (52 at Extra Large and on iPad), a hairline between.
   - **Lock row** (always first), on a maroon tint: the lock glyph, "Locked 240°" leading, "turn 12° right"
     trailing in semibold, ✕ to unlock.
   - **Spot row**: the pin glyph, "Marked spot" and "9.2 mi · 46° NE", ✕; tapping it offers Lock to Spot
     and Clear Marked Spot.
   Values never break inside or end in "…".
6. **Tiles**, frosted white at 8% with a faint edge, a caption at the top (text only) and the value's last
   line at the bottom inset. The grid depends on the layout:
   - **Small**: no tiles; a big map card runs to the bottom with a frosted band along its foot:
     `POSITION · DD` | `ELEVATION` | `SUN · ◐ 53%`.
   - **Medium** (the default): 2 × 2: Position | Elevation ("9,587 ft" over "2,922 m · 21.04 inHg"),
     Sun ("↑ 6:36 AM" over "↓ 5:08 PM") | the Map tile.
   - **Large**: 3 × 2 compact tiles: Latitude | Longitude | Elevation, then Sunrise ("Sets 5:08 PM") |
     Moon ("53%", "Last quarter") | **Pressure** ("21.04 inHg") when still or **Speed** ("3.2 mph") when
     moving at 0.5 m/s or more. In DMS, DDM, UTM, MGRS and Plus Code, Latitude and Longitude become one
     Position tile two columns wide.
   - **Extra Large**: one summary strip, Position | Elevation | Sun.
   Position (captioned with the format, "POSITION · DD") is latitude over longitude in the current format,
   never cut off. Tap to switch format; long-press to copy or open the details. Dims when the fix is stale.
   Sun: polar day or night reads "Up all day" / "Down all day". Moon: the phase glyph and "53%" over "Last
   quarter". Times use non-breaking spaces and never break. With nothing locked or marked, the Targets
   card's height goes to the tiles (Medium's Sun tile then gains a Moon section) or the map card.
   Elevation, Sun and Moon open the **Details** sheet: accuracy ("±16 ft · Just now"), the source ("GPS
   ±4 m" or "Terrain data"), pressure ("29.92 inHg" or "1,013 hPa") with a barometer, the format's name,
   the moon's phase name and the sun's and moon's rise and set directions. Before the first fix the tiles
   show "—" and "Finding position…".
7. **Map**: shown whole or not at all, as the Map tile (Medium), a map card (Small, iPad portrait Medium,
   two panes), or the location card's map button (Large and Extra Large); each opens the full-height
   **map sheet** (full-bleed, a "Map" bar with Done). On a map card: a chip with the speed at the top left
   when moving at 0.5 m/s or more ("3.2 mph"), and locate and north/compass in 36 frosted circles at the
   top right (a card under 200 high shows only the chip and one expand button). The sheet's controls, in
   one vertical stack: +, −, the heading button (north up ↔ follow heading), and open in Maps. Attribution
   stays visible. Your position is a white dot with a white heading cone.

On iPad the same column (at most 720 wide) with a regular-width type ramp (tiles 96, captions 13, values
22); the Mac uses it too. Wide windows and phones on their side use two panes with no full-width header:
the dial, readout and status on the left, top-aligned; on the right, the location card with ⋯, the Targets
card, the grid and a map card ([LAYOUTS.md](LAYOUTS.md) §5). "Made by Bradley Cowdrey" is in the ⋯ menu on
every layout and platform. The Mac window hides its title bar; the dial starts 18 under its 28 title-bar
band and the content keeps 24 from the other edges. The web page keeps its current look for now.

**The menu**: Layout (Small "Compass + big map", Medium "Balanced · map tile", Large "Bigger compass ·
map in header", Extra Large "Biggest compass · one row") · Coordinates (the six formats) · Units: Feet First, Metres First · North: True North,
Magnetic North · Map: Follow Heading, Open in Maps, and on Apple Standard / Satellite · Night Mode · Mark
This Spot (or Clear Marked Spot) · Lock This Bearing (or Clear) · Copy Coordinates · Share My Location… ·
Share Bearings… · Terms & Privacy · About Bearings · Made by Bradley Cowdrey.

**Night mode** turns everything red: the whole screen through a red multiply (the location card's blues
become dark reds), secondary text at least `#E03020` (4.5:1 on black), and the map tinted red and dimmed so
it is never the brightest thing on screen.

**Accessibility**: VoiceOver/TalkBack read the dial as "Heading 228 degrees, southwest" (with Lock,
Larger Compass and Smaller Compass actions), every tile as one element ("Elevation, 9,587 feet, 2,922
metres"), each Targets row as one element with ✕ as a named action ("Clear lock", "Clear marked spot"),
and announce the heading at most every few seconds. Text scales with the system's text size: values never
end in "…"; at larger sizes (k ≥ 1.3) three-column rows become two rows (Position full width; Elevation |
Sun) while the dial stays at least 40% of the screen, and at accessibility sizes the whole screen becomes
one scrolling list in the same order, with 96-high tile rows ([LAYOUTS.md](LAYOUTS.md) §4); reduce motion
turns off the card's easing.

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
