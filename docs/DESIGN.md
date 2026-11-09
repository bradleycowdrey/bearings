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

The apps look like Two Degrees: a black screen with white type, a slim sky-coloured location bar at the top and frosted
tiles with small uppercase captions, the same tile as the widgets. The exact colours, sizes and tokens are
in [LOOK.md](LOOK.md). Inside the app the highlights are white, and pink means north only. The warm
near-black and cream stay on the Terms screen and the app mark; the widgets are black like the app, with
no crimson rule, and the icon has no crimson band.

Spacing uses frozen tokens: spare height goes to each layout's tiles or map card, then the dial, never into
wider gaps ([REFINE.md](REFINE.md) A.1). Screen margins are 16; on iPad the column is min(W − 48, 720),
centred; on the Mac 24. Tiles have radius 16. Every control is at least 44 × 44 (48 dp on Android).

The order, top to bottom: **location bar → dial → readout → status line → Targets card → the layout's
tiles or map.** The location bar is 8 below the safe area and the dial's top 12 under the bar (iPhone 16
Pro: 122).

1. **Location bar** (40 high × text size, radius 12, first on the screen; the sky card, slim): the
   place ("Maroon Bells, Colorado", 15 semibold) over the date and time ("Sun, Nov 1 · 9:41 AM", 12, white
   at 75%, the device's 12- or 24-hour setting, updated each minute), on a sky that follows the sun's
   altitude where you are: deep navy at night, steel blue around sunrise and sunset, clear blue by day
   (grey before a fix). The Sample pill sits on the date line (hidden in the App Store screenshots,
   `--store`). At the trailing end, in fixed order: the sun, sunrise, sunset or moon symbol, the map
   button (Large and Extra Large), and the **⋯** menu. While finding the place: "Finding where you
   are…". With no location: "Bearings". With no place within 200 km: "Far from any town". There is no
   "Bearings" title on the screen; it stays the accessibility title.

2. **Dial**: sized by the chosen **Layout**'s rule (Small, Medium, Large, Extra Large; [LAYOUTS.md](LAYOUTS.md)
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
3. **Readout**: "228°" (56 light, tabular; 70 at Extra Large; 96 on iPad) and "SW" (half size, medium,
   white at 60%), on one baseline. Unchanged. With no compass the words **"No heading"** (34 semibold,
   white at 55%) take its slot, sized to the words, with the status line right under them. VoiceOver and TalkBack say
   "Heading unavailable", once.
4. **Status line** (13, white at 60%, centred, one line): "True north · 8° E declination · ±8° accuracy".
   A warning replaces it in amber semibold: "Magnet or metal nearby: move away" (field outside 20–70 µT),
   or "Low accuracy: move your phone in a figure 8". With no compass: "Position, sun and map still work".
5. **Targets card** (only when a bearing is locked or a spot is marked, 12 under the status line): one
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
   two panes), or the location bar's map button (Large and Extra Large); each opens the full-height
   **map sheet** (full-bleed, a "Map" bar with Done). On a map card: a chip with the speed at the top left
   when moving at 0.5 m/s or more ("3.2 mph"), and locate and north/compass in 36 frosted circles at the
   top right (a card under 200 high shows only the chip and one expand button). The sheet's controls, in
   one vertical stack: +, −, the heading button (north up ↔ follow heading), and open in Maps. Attribution
   stays visible. Your position is a white dot with a white heading cone.

On iPad the same column (at most 720 wide) with a regular-width type ramp (tiles 96, captions 13, values
22); the Mac uses it too. Wide windows and phones on their side use two panes under the full-width
location bar: the dial, readout and status on the left; on the right, the Targets
card, the grid and a map card ([LAYOUTS.md](LAYOUTS.md) §5). "Made by Bradley Cowdrey" is in the ⋯ menu on
every layout and platform. The Mac window hides its title bar; the location bar starts 8 under its 28 title-bar
band and the content keeps 24 from the other edges. The web app follows the same order and look.

**The menu**: Layout (Small "Compass + big map", Medium "Balanced · map tile", Large "Bigger compass ·
map in header", Extra Large "Biggest compass · one row") · Coordinates (the six formats) · Units: Feet First, Metres First · North: True North,
Magnetic North · Map: Follow Heading, Open in Maps, and on Apple Standard / Satellite · Night Mode · Mark
This Spot (or Clear Marked Spot) · Lock This Bearing (or Clear) · Copy Coordinates · Share My Location… ·
Share Bearings… · Terms & Privacy · About Bearings · Made by Bradley Cowdrey.

**Night mode** turns everything red: the whole screen through a red multiply (the location bar's blues
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

Widgets can't read the compass, and a widget may be minutes old, so every Home Screen and desktop widget's
compass is **fixed north-up** and shows only bearings that are true wherever the phone points: the sun's azimuth, the moon's,
the marked spot and the locked bearing. There is no live heading and no "last heading". The app saves its
last fix (latitude, longitude, accuracy, elevation and its source, the place name, the time), the marked
spot and the locked bearing (as a true bearing: a magnetic lock has the declination added back) to shared
storage whenever they change (an App Group on Apple, `WidgetSnapshot.lockBearing`; the app's preferences on
Android). Widgets refresh every 30 minutes, ask for a fresh location themselves where the system allows it
(Apple's `NSWidgetWantsLocation`; Android's last known location with the permission), look up the elevation
if needed, and work out the sun and moon (azimuth, altitude, phase) for the time of each entry.

**Look** (mock W2, after W1): black, with the app's slim location header (40 high, the sky gradient for
the sun's altitude, the place at 15 semibold and the time of the reading at 12, 75% white) and the app's
frosted tiles (white 8% with a 12% edge, captions 11 semibold caps, tracking 0.6, 60% white). No crimson
rule. Header and tiles sit 8 inside the widget with 14 corners (the widget's 22 less 8; Android 24 dp
outer, 16 dp inner); Apple widgets turn off the system content margins to get this.

**The dial**: the app's dial language (dark #151515 disc with a 16% edge, white ticks, pink N), drawn as
vectors. Tick density follows its size:

| Dial | Ticks | Labels |
|---|---|---|
| 180 pt and more | 2° / 10° / 30° | N E S W and numbers every 30° |
| 100–180 pt | 10° / 30° | N E S W |
| under 100 pt | 10° / 30° | N only |

Marks: the **sun** an amber rayed disc at its azimuth, the **moon** a cream disc lit for its phase (both
faint below the horizon, as in the app); the **marked spot** a pink teardrop on the rim, point inward, with
a dashed line from you and its distance in a pill; the **locked bearing** a pink notch outside the rim and a
14° arc on it, only when a lock is set. On a half dial, a mark below the arc never moves onto it: it becomes
a small glyph beside the nearer end of the arc (east for 90–180°, west for 180–270°), 10.9 pt from the
widget's edge, with one small filled arrow under it pointing its true way; the sun and moon get no edge
mark while they are below the horizon.

- **Small** (170 × 170): the header (short place, time); the top half of the dial, W → N → E, 124 wide,
  with the spot's pin and its "9.2 mi" pill; the sun and moon as edge marks when up but off the arc; the
  elevation at 30 pt under it. No locked bearing at this size.
- **Medium** (364 × 170): a 120 pt full dial on the left with the sun, moon, pin and dashed line and the
  lock notch, the pin and "9.2 mi · 46° NE" under it; the header over the right column; ELEVATION (9,587 ft 2,922 m)
  and SUN (moon % in the caption, ↑ rise ↓ set) tiles.
- **Large** (364 × 382): the header; a 212 pt dial with the full scale and every mark on the left;
  ELEVATION, SUN (azimuth in the caption, rise and set) and MOON (% and phase) stacked on the right; a
  POSITION row and the Marked spot row (lock "240°" and "9.2 mi · 46° NE") full width below. No map.
  Without a spot or lock, that row and those marks drop out and the dial's row takes the room.
- **Lock Screen (iPhone)**: the **W1 elevation design**, no compass (a dial doesn't read at these sizes
  in one tint). iOS draws them in one tint (vibrant), so hierarchy is weight and opacity only (100 / 75 /
  65%), with no gradient, tiles, pink or amber.
  - *Inline*: the mountain glyph, "9,587 ft · Maroon Bells" (the short place); the place truncates first,
    never the number.
  - *Rectangular* (172 × 76): the short place with the mountain glyph, 15 semibold; "9,587 ft" 20 bold with
    "2,922 m" 15 at 65% beside it; the coordinates on one line, 12 at 75%, decimal degrees to 4 places
    (≈ 11 m) so both fit ("39.0990° N  106.9412° W"; the other formats as the app writes them).
  - *Circular* (76 × 76): a 270° gauge ring (6 wide, open at the bottom; the track at 28%, the fill in full,
    a dot at its end) on the accessory backdrop, filled 0 → 14,000 ft, clamped (metres fill the same);
    "9.6k" 20 bold in the middle and "ft" (or "2.9k" and "m" when metres come first) 11 semibold at 75% in
    the ring's gap.
  - Before a fix: inline "Open Bearings", circular the location glyph, rectangular "Open Bearings to find
    where you are."
- **Tinted, clear and desktop-in-background** (`widgetRenderingMode` not full colour; StandBy): one colour
  in steps of opacity, the header and tiles at 14% / 8%, pink and amber in the system's tint.
- **Mac**: the same Small, Medium and Large views on the desktop and in Notification Center; macOS
  desaturates them when an app is in front.
- **Android** (Jetpack Glance, one resizable widget): the same three layouts by size, under 250 × 180 dp
  the half dial, 250 dp wide and more the full dial and tiles, 250 × 300 dp and more Large. Glance can't
  draw vectors live, so the dial is drawn to a Bitmap (Canvas) for an ImageProvider.
- Every widget says when its data is from (the header's time), opens the app when tapped, and follows the
  app's units and coordinate format. Before the app has a location: "Open Bearings to find where you are."

Mac: small, medium and large desktop and Notification Center widgets. iPhone and iPad: Home Screen
small, medium, large; Lock Screen inline, rectangular, circular. Android: one widget that resizes (2×2,
4×2, 4×4).
