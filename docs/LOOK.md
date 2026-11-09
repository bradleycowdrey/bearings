# Bearings: the Two Degrees look

Bearings is restyled to look like Two Degrees, the same way Meridian was. This page holds the exact
numbers, so the iPhone and iPad, Mac, Android and widget work all build the same thing. DESIGN.md still
covers what the app does. This page covers how it looks. Features, wording, accessibility labels,
Dynamic Type and font-scale behaviour, the 44-point targets, night mode, the self-tests and the CI
launch arguments (`--sample`, `--format`, `--layout`, `--map-sheet`, `--no-compass`, `--store`,
`--show-terms`, `--selftest`) stay as they are. Layout (sizes, gaps, the planner and the four layouts) is in
LAYOUTS.md, which follows REFINE.md "Concept A" with the owner's change: the location card is a slim 40 pt
bar at the top. **Where this page and LAYOUTS.md differ on a size or a position, LAYOUTS.md wins.**

The tokens are in `Sources/Bearings/Views/Palette.swift` (Apple, shared with the widget extensions) and
`android/app/src/main/java/com/bradcowdrey/bearings/ui/Theme.kt` (Android). Use the tokens and don't
retype hex values. The existing names (`Palette.bg`, `tile`, `cream`, `accent`…) still compile. Inside
the app they are replaced by the new tokens below, except where this page says to keep them.

## The rules in one place

- **Black, white type.** The main screen is pure black (`Palette.screen`). Type is white, made quieter
  only by opacity, in fixed steps (`Palette.Op` / `Op`):

  | Step | Opacity | Used for |
  |---|---|---|
  | strong | 0.90 | – |
  | body | 0.85 | text in a card or tile body, the date on the sky card |
  | label | 0.80 | – |
  | sub | 0.70 | a value beside the main one (metres beside feet), the spot pill's details |
  | caption | 0.60 | captions, details, the subline, the dial's numbers, the heading's point (SW) |
  | noHeading | 0.55 | the "No heading" words in place of the readout (`Op.noHeading` / `NO_HEADING`) |
  | points | 0.45 | NE, SE, SW, NW on the dial |
  | faint | 0.35 | the dots between parts of a line, disabled text |
  | minor | 0.30 | the dial's 2° ticks |
  | track / stroke / fill | 0.15 / 0.12 / 0.12 | the dial's inner rings / tile edges / off chips and the ⋯ circle |
  | tile | 0.08 | tile and dial fill |

- **No accent colour inside the app. Highlights are white.** White capsules carry black text. The one
  exception is **north**: the N and its tick on the dial and the N on the widget's rose stay pink
  `#E04A7A` (`Palette.north`), because the app icon's needle is pink to the north. Pink means north and
  nothing else. The marked spot, the locked bearing and your position on the map are white.
- **Functional colours stay**: the sun `#F5B03C` (`SkyMarks.sun`), the moon cream `#FFF1E5`, the level's
  green `#8FC89A` (`Palette.level`), and warnings in amber `#F2A65A` (`Palette.notice`, the same as `warn`).
- **The warm brand colours stay outside the app's main screen**: on the Terms screen and in the app
  mark. Since 2.3.0 the Home Screen, desktop and Android widgets are black like the app, with no crimson
  rule, and the icon has no crimson band.
- **Shapes**: tiles, the Targets card and the map are rounded 16 (the location bar 12) with continuous corners (`Look.radius`), on
  every platform. Tiles are flat white at 8% with a 1-point edge of white at 12% (`frostedTile()`). They
  aren't a blur material, so they draw the same in the self-tests' ImageRenderer and on Android. The
  only material is behind the map's buttons on Apple devices (`.ultraThinMaterial`, dark). Android uses
  black at 60% there (`Palette.mapControl`).
- **Type**: SF Pro on Apple devices, Inter on Android (as now; Inter has no Light, so where this page
  says light, Android uses Normal). Sizes below are at the default text size and scale with the
  column's `k` (DESIGN.md) as they do now.
- **Captions**: 11 semibold, uppercase, tracking 0.6, white at 60%, **text only** (no symbol), in tiles,
  sheets and widgets alike (`CardCaption`). Captions are stored in normal case ("Latitude") and only shown in capitals, so
  VoiceOver and TalkBack still read the tile's own label.
- **Buttons**: a white capsule with black text (`LookButtonStyle`). The full-width primary is 50 high,
  17 semibold. The compact one is 14 semibold with padding 14 × 8 (44 target kept by its row). Switches,
  if any appear, use `Palette.switchOn` `#30D158`.

## The sky

The location card's sky follows the sun's real altitude where you are (`nav.sunPosition?.altitude` on
Apple devices, `Sky.sunPosition(...).altitude` on Android, in degrees). `SkyTone.colors(altitude:)` and
`SkyTone.brush(altitude)` interpolate the top and bottom colours, in sRGB, between these stops:

| Sun altitude | Top | Bottom | Two Degrees' name |
|---|---|---|---|
| −12° and below | `#141E3C` | `#0A0E1C` | clear night |
| −2° to 8° | `#4F78A3` | `#24384F` | partly cloudy day (used as twilight, as in Meridian) |
| 15° and above | `#3D74B0` | `#1C3A5E` | clear day |
| no location yet | `#262626` | `#262626` | card with no forecast |

The gradient runs top to bottom over the whole card. It changes as the minute ticks, with no animation of
its own. The card's corner symbol (`SkyTone.symbol(for:)` / `SkyTone.phase`) is `sun.max.fill` from 8° up,
`sunrise.fill` or `sunset.fill` from −6° to 8° (sunrise while the sun's azimuth is under 180°),
`moon.stars.fill` below −6°, and `location` before a fix. On Android the matching icons are `WbSunny`,
`WbTwilight`, `NightsStay` and `LocationOn` (material-icons-extended, already a dependency). It's
decorative and hidden from screen readers. It's 22, white at 85%, in a 32-wide slot.

## Main screen, phone (top to bottom)

Background `Palette.screen` (black) edge to edge. Column margins 16; on iPad the column is
min(W − 48, 720), centred; on the Mac 24. The order is **location bar → dial → readout → status line →
Targets card → tiles or map** (docs/LAYOUTS.md §1).
The gaps are the planner's frozen tokens × k, never widened by spare height (docs/REFINE.md A.1):

| From → to | pt / dp |
|---|---|
| safe top → location bar | 8; Mac: the 28 title-bar band + 8 |
| location bar → dial top | 12 (8 under pressure) |
| dial edge → the readout's cap top (line box trimmed) | 12 |
| readout → status line | 6 × k |
| status line → Targets card | 12 (8 under pressure) |
| Targets card (or status line) → tiles or map | 8 |
| between tiles | 8 |

1. **Dial**, on black, sized by the layout's rule, at least 40% of H in portrait. Unchanged by Concept A:
   - Disc: `Palette.tileFill` with a 1-point ring of `Palette.tileStroke`.
   - Ticks: 30° ticks white (2.4 wide), 10° ticks white at 60% (1.4), 2° ticks white at 30% (1).
     The 0° tick and the **N** (30 semibold) are `Palette.north` pink.
   - E, S, W: 26 semibold, white. NE, SE, SW, NW: 13 semibold, white at 45%. The numbers every 30°:
     15 medium, white at 60%.
   - Sun and moon marks: unchanged (amber, cream; 35% below the horizon).
   - Marked spot: the teardrop pin in **white**, with its hole and edge in black.
   - Locked bearing: the notch in white, the arc white at 85%, 6 wide.
   - Fixed parts: the lubber triangle **white**. Cross lines stay white at 7%. Both inner rings are
     white at 15%, 1.5 wide.
   - Level bubble: white, green `Palette.level` within 2° of flat.
2. **Readout** (unchanged): "228°", 56 (96 on iPad, 64 sp on Android tablets; × 1.25 at Extra Large),
   weight **light** (Android: Normal), tracking −2, white. The point "SW" is half that size, medium, white
   at 60%. **With no compass** the words **"No heading"** replace it (the drawn dash is gone): 34 semibold
   (34 sp), tracking −0.2, centred, white at 55% (`Palette.Op.noHeading` / `Op.NO_HEADING`). The
   slot is sized to the words, with the status line right under them (docs/LAYOUTS.md §1). Spoken "Heading
   unavailable", announced once, politely.
3. **Status line** (unchanged): 13 regular, white at 60%, centred. A warning is `Palette.notice` semibold.
   With no compass: "Position, sun and map still work", same style.
4. **Location bar** (the sky card, slim, and since 2.3.0 the first thing on the screen, above the dial;
   the sizes that follow are the older, taller card's where they differ from docs/LAYOUTS.md §1: 40 high,
   radius 12, place 15 semibold, date 12, pill 10, 28 circles): full column width, on the sky gradient
   (`skyCard(altitude:)`'s colours, unchanged), no shadow. Padding 14 leading (16 dp), 4 trailing. White type:
   - Line 1: the full place (`nav.placeTitle`), 17 semibold, line 20 (18 sp; 20 on iPad and Mac), never
     truncated; at k ≥ 1.3 it may wrap.
   - Line 2: "Sun, Nov 1 · 9:41 AM", 13 regular, line 18 (15 on iPad and Mac, at 85%), white at 75%,
     tabular figures, then the **Sample** pill trailing it: 12 semibold (13 on iPad and Mac) in a 17
     capsule (20 dp; 19 on iPad and Mac), padding 7, black on `Palette.notice`; at night an outline (black
     fill, 1.5 white inset, white text, which the night multiply turns red).
   - Trailing, fixed order on every layout: the sky symbol (22, white at 85%, decorative, in a 32-wide
     slot), then the **map button** (Large and Extra Large; a 24 glyph in a 44 × 44 target, 48 dp; in two
     panes it is hidden but keeps its slot, because a map card is on screen), then **⋯**: Apple
     `ellipsis.circle` 28 in 44 × 44; Android `more_vert` 24 dp in a 36 dp `Palette.chipOff` circle with a
     48 dp target. The accessibility label stays "Settings and more".
   - There is no "Bearings" title on the main screen: iOS keeps it as the accessibility screen title,
     the Mac window's title says Bearings, and Android sets `paneTitle = "Bearings"`.
   - One accessibility element ("Maroon Bells, Colorado, Sunday November 1, 9:41 AM, sample data"), with
     the buttons as separate elements after it.
5. **Targets card** (only when a lock or a spot exists; only the rows that exist): radius 16,
   `Palette.tileFill`, a 1-point `Palette.tileStroke` edge, clipped. Rows 44 (48 dp); Extra Large 52 (64 dp);
   iPad 52; compact under pressure 36 (40 dp). A 1-point white-at-8% hairline between rows.
   - **Lock row** (always first): fill `Palette.lockFill` `#3D2128` (night: red at about 15% luminance),
     1-point inset `Palette.lockBorder` `#5A2C38`; top corners 16, or all four if it is the only row. The
     lock glyph (14 × 16, white at 85%) in a 16 column (18 dp), "Locked 240°" 17 regular, a flexible space,
     "turn 12° right" 17 semibold, then ✕. Gap 8, padding 14 leading (16 dp), 4 trailing.
   - **Spot row**: the card's own fill; the pin glyph, "Marked spot" 17 regular, "9.2 mi · 46° NE" 17
     semibold tabular, ✕.
   - ✕: a 14 glyph, white at 60% (Android `Icons.Rounded.Close`), in a 40 frame with a 44 pt / 48 dp hit
     area, which may overlap the hairline. Night: ✕ and secondary text white at 90%.
   - Type by layout: Small 15 (16 sp); Medium and Large 17; Extra Large 17 (19 sp); iPad 19.
   - Values use non-breaking spaces and never split or end in "…": the leading text scales to 0.85 first;
     only under a 320 column does "Locked 240°" shorten to "240°".
6. **Tiles**, one component on both ports: `frostedTile()`, radius 16, gutters 8, padding 10 × 12
   (Large 10 × 10; iPad 12 × 16). The caption sits at the top; the **last baseline of the value block
   sits at the bottom inset** in every tile, so values line up across a row.
   - Caption: 11 semibold caps, tracking 0.6, line 13 (14 sp), white at 60% (90% at night), text only (13
     on iPad and Mac).
   - Value: medium, tabular, white (white at 60% when stale): Medium's Position and Sun 15 (line 19),
     Elevation 17; Large's compact tiles 16 (line 20, tracking −0.2), with "AM" at 12 and units at 12, white
     at 70%; iPad and Mac 22 (line 26). Secondary: 13, line 17 (13 sp, line 18), white at 60% (15 at 70% on
     iPad and Mac).
   - **Small's band** along the map card's foot: 68 high (72 dp), Apple `rgba(12,14,14,0.78)` with a 12
     blur, Android solid `#16191A`, a 1-point `tileStroke` top edge; padding 10 × 12; three columns
     1.15fr | 1fr | 1fr (1.2 | 1 | 1), gap 8; values 13 semibold, line 17, 3 under the caption.
   - **Extra Large's strip**: one tile, 88 high (104 dp) growing to 120; three columns 1.2fr | 1fr | 1fr
     (1.25 | 1 | 1), each with 12 × 14 padding, split by 1-point `tileStroke` dividers.
   - Sun on both ports: ↑ / ↓ before the times; the caption may carry the moon (`SUN · ◐ 53%`). Times use
     the shared formatter: a narrow no-break space before AM/PM, a no-break space after ↑ / ↓. Nothing ever
     ends in "…": text scales to 0.85, then the planner gives way.
   - The tap, long-press, copy and context-menu behaviours are unchanged. Before location is allowed, the
     ask-for-location tile takes the grid's place, `frostedTile()`, text 13 white at 85%, and "Use My
     Location" / "Settings" as a compact `LookButtonStyle`.
7. **Map** (tile, card and sheet), clipped to radius 16 with a 1-point `Palette.tileStroke` edge;
   `Palette.tileFill` before it loads.
   - The Map tile: the snapshot full bleed (Apple `MKMapSnapshotter` with the user dot; Android the dark
     style, labels at 70%), one 24 bottom scrim (a gradient to black 65%; Android solid black 60%) with an
     11 expand glyph, `MAP` in caption style (white), and "© OpenStreetMap" trailing at 9, white at 60%. One
     accessibility element: "Map, opens full map".
   - The map card (Small, iPad, two panes): tap anywhere for the sheet. The speed chip top-leading at 12:
     13 semibold tabular, padding 5 × 10, radius 14, black at 72% (Android `#2A2D30`). Controls top-trailing
     at 12: locate and north/compass, 36 circles (in 48 dp targets on Android), 8 apart, Apple
     `.ultraThinMaterial` (dark), Android `Palette.mapControl`; white glyph, 15 semibold; Follow Heading on
     is a **white** circle with a black glyph. A card under 200 high shows only the chip and one expand
     button. Attribution bottom-leading at 8: Apple "© OpenStreetMap" at 9–10; Android a
     `© OpenStreetMap ⓘ` pill, 24 dp, 10 sp, radius 12, above the band when there is one, ⓘ with a 48 dp
     hit area.
   - Android's map style is dark (land about `#0F3B3A`, roads `#5A6470`, water `#22348A`). Labels:
     `#C9D3D6` regular, never italic or cyan, 11–12 sp, a 1.5 dp `#0F3B3A` halo, 70% in the tile; POI labels
     hidden under 160 dp of map height, road shields under 200 dp of width, 48 dp collision padding around
     the speed chip and the controls. Night: red-tinted at 35% luminance, not near-black.
   - Your position: a white dot 16 with a 3-wide black-at-35% ring and a soft shadow. The heading cone is
     white, 45% at the dot to 0. The accuracy circle is white at 10% fill with a 1-wide white-at-40% edge.
   - The map sheet is unchanged.
8. **Toast** ("Coordinates copied"): a white capsule, black text 14 semibold, padding 16 × 9, 28 above
   the bottom.

## iPad and Mac

The same panel in one centred column, min(W − 48, 720), with the regular-width type ramp: location card 56
(place 20 semibold, date 15 at 85%, pill 13 in a 19 capsule, buttons 48), status 15, Targets rows 52 at 19,
tiles 96 (caption 13, value 22, secondary 15 at 70%), map card chip 15 and controls 40, readout unchanged
(96; 64 sp on Android). The dial may be wider than the column, up to its width cap. Wide windows and
phones on their side use two panes under the **full-width location bar** (docs/LAYOUTS.md §5): the dial,
readout and status centred in the left pane; on the right, from the panes' top, the Targets card, the grid and a map
card to the pane's bottom.

- **Mac**: `.windowStyle(.hiddenTitleBar)`; the traffic lights sit over the left pane's top band; the
  content keeps 24 from the sides and the bottom. The minimum window (420 × 780) and the default 440 × 860 window the self-test draws
  fit without scrolling. The Mac has no live compass, so it shows "No heading".
  The update banner ("Bearings 0.2.0 is available."): `frostedTile()`, 44 high, 13 medium white, with
  "Download" as a compact `LookButtonStyle`, 12 under the status line, above the Targets card.
- **Footer**: "Made by Bradley Cowdrey" is an item in the ⋯ menu on every layout and platform; there is no
  footer line on the screen.
- **Map sheet on iPad**: `.presentationSizing(.page)`, so it doesn't cover half the dial as a form sheet.

## The menu, About, and Terms

- **⋯ menu**: the system menu on Apple devices, with the same items, order and symbols. The app's tint
  is white (`.tint(.white)`). Android's `DropdownMenu`: container `Palette.menu` `#1E1E22` (via the
  MaterialTheme `surfaceContainer`), items 15 regular white, section titles 11 semibold uppercase in
  white at 35%, checks "✓" in **white** (not cream), dividers white at 12%. Everything goes through
  `.night()` in night mode, as now.
- **About**: the system alert on Apple devices, unchanged. On Android, the `AlertDialog` container is
  `Palette.menu`, with the text white and white at 70%, and the buttons white.
- **Terms** (iPhone and Android first launch, and changed terms): as Two Degrees' terms screen, which
  Bearings already follows. The background stays `Palette.bg` `#1A1816`. The app mark is 56. The title
  is 28 semibold, tracking −0.4. The summary is 17 in `Palette.textSecondary`. The agreement line is 15
  in `Palette.textMuted`. "I Agree" is a full-width cream capsule, 50 high, 17 semibold, with
  `Palette.bg` text (Two Degrees' terms button). "Read the Terms" is 17 medium white, 44 high; the buttons
  are 12 apart, pinned 16 above the bottom safe area, with the note ("Next, Bearings asks for your
  location.", 13 secondary) 16 above the primary and 24 below the content. The content
  block is centred in the space above the buttons (at least the safe area + 48 from the top); on iPad the
  column is at most 480 and the buttons sit 32 below the text. The rows wrap rather than run to the edge.
  iOS styles the terms link underlined in the accent with a 44 pt hit height; Android's row icons are
  24 dp outlined `WarningAmber`, `NearMe` and `Map`. The Mac's terms prompt stays as it is.

## Widgets (Apple devices)

**Since 2.3.0** the Home Screen and Mac desktop widgets are drawn as docs/DESIGN.md "Widgets" describes:
black, the slim location header, a north-up compass with the sun, moon, marked spot and locked bearing, and
the app's frosted tiles, with no crimson rule; the time reads "as of 9:41 AM". The notes below are the
earlier elevation design, which only the **Lock Screen** widgets still use; for the others DESIGN.md wins.

Same data and entries as now. They take Two Degrees' widget layout and type. The background is
`WidgetBackground` (`#1A1816` with the 3-point crimson rule on top, stepping aside in tinted and clear
modes), already in Two Degrees' form. Padding is 16 (the system's). Dividers are 0.5 `Palette.widgetRule`.
Type is white, `Palette.textSecondary` and `Palette.textMuted` (the warm greys stay on widgets, as in
Two Degrees).

- **Small**: Two Degrees' NowBlock.
  - Top row: the place, 13 semibold, **white** (was cream), up to 2 lines. At the top right is the sky
    symbol (`SkyTone.symbol(for: r.sun)`), 15, in `SkyMarks.sun` by day and twilight, cream at night.
  - The elevation directly under it: the number at 36 semibold, tracking −1, white, `widgetAccentable()`.
    Its unit ("ft") is at 0.45 size, medium, `textMuted`, on the same baseline (split the "9,587 ft"
    string at its last space). Under that, the other unit ("2,922 m") is 15 medium `textMuted`.
  - Then a spacer. At the foot, the coordinates (one or two lines), 12 semibold `textSecondary`, then
    the time ("9:41 AM"), 11 medium `textMuted`. All tabular figures, shrinking to 0.7 before cutting.
- **Medium**: the small block 128 wide (its place on one line, scaling to 0.8) | 0.5 divider | on the
  right, Two Degrees' hours row with three columns of equal width. Each column has a caption in the app's
  style (11 semibold caps, tracking 0.6, `textSecondary`): **SUN**, **RISE**, **SET**; a symbol in an
  18-high frame, a value 13 semibold white and a sub 10 `textMuted`. Content inset 16 on all four edges.
  - **Sun**: the `SunRose` 34, the sun's direction "228° SW", and "23° up" or "Below".
  - **Rise**: "↑" (as the app's Sun tile) and the time without AM/PM (in WidgetViews.swift, because
    MainView isn't in the widget target), and the AM/PM or nothing in 24-hour time.
  - **Set**: the same, with "↓".
  - Polar day or night: the Sunrise and Sunset columns become one wide column reading "Sun up all day"
    or "Sun down all day".
  - Under the row, across the right half: the moon glyph 12 and "Waxing Gibbous · 82%", 11 medium
    `textMuted`.
  - Spoken labels as now.
- **Large**: Two Degrees' large widget, top to bottom, 10 apart:
  1. A top row. On the left, the place 13 semibold white, then the elevation at 46 semibold (unit at
     0.45) with the other unit beside it on the baseline, 20 medium `textMuted`. On the right, the sky
     symbol 32 in a 40 frame, with the coordinates under it, 12 semibold `textSecondary`, trailing.
  2. A 0.5 divider.
  3. The map, 112 high (the 340 × 132 snapshot fills and crops), radius 12. Your position is a white
     dot 12 with a 2.5 black-at-35% ring.
  4. The medium widget's three-column sun row.
  5. A 0.5 divider.
  6. The moon line, then (if there is one) the marked spot: `mappin` white, "Marked spot" 12 semibold
     white and " · 0.4 mi · 245° SW" in `textSecondary`. The time is at the far right, 11 `textMuted`.
- **Empty (before a fix)**: Two Degrees' unavailable view. The app mark 28 is top left. Then a spacer,
  `location` 20 medium `textMuted`, and "Open Bearings to find where you are." 12 semibold
  `textSecondary`.
- **Lock Screen** (iPhone): one tint, no colours, as Two Degrees.
  - Inline: unchanged ("⛰ 9,587 ft · Aspen").
  - Circular: `AccessoryWidgetBackground`, `mountain.2.fill` 10, the number 20 semibold
    `widgetAccentable`, and the unit 10 at 75%.
  - Rectangular: the place with `mountain.2.fill`, 13 semibold. Then the elevation 22 semibold
    `widgetAccentable` with the other unit 14 medium at 75%. Then the coordinates 12 medium at 75%.

## Android widget (Glance, resizable)

**Since 2.3.0** the Android widgets show the compass design in docs/DESIGN.md "Widgets" (black, no crimson
rule); the notes below describe the earlier elevation widget and are kept for its type sizes only.

The same three layouts at the same breakpoints (2 × 2 small, 4 × 2 medium, 4 × 4 large).

- **Background**: a corner radius of 22, `Palette.bg`, and a 3 dp `Palette.crimson` rule across the top
  (a Box 3 dp high above the content). Padding 14. Dividers are 1 dp `Palette.widgetRule` (Glance has
  no 0.5).
- **Small**: the place 13 Medium white (2 lines). The elevation 30 Medium white, with the other unit and
  the time on one line under it, 12 `textMuted`. A spacer, then the coordinates 11 Medium
  `textSecondary`.
- **Medium**: the small block 124 wide | divider | three columns: Sun (the rose bitmap 34), Sunrise,
  Sunset. Each column has a label 10 `textMuted` (Sun's in cream), a value 13 Medium white and a sub 10
  `textMuted`. The moon row (bitmap 14 and the moon line 11 `textMuted`) sits under the columns.
- **Large**: the top row as the large Apple widget (the place 13 Medium white, the elevation 34 Medium
  with the other unit, and the rose 56 at the right). Then a divider, then the info grid (Glance can't
  draw a map), with titles as **captions**: 10 Medium uppercase in white at 60% (LATITUDE, LONGITUDE,
  SUNRISE, SUNSET, MOON) and values 13 Medium white. Then a divider, then the marked spot line 12
  Medium **white** (not pink).
- **Empty**: "Bearings" 15 Medium white, then a spacer, then "Open Bearings to find where you are." 13
  `textSecondary`.

## Night mode

The same as now: the whole screen is multiplied by `#FF2E1F` (`Palette.nightRed`; `MainView.nightTint`
on Apple devices) and the map is dimmed. The black background stays black. White type and the tiles
turn red. The sky card's blues become dark reds (the day sky's top `#3D74B0` comes out about `#3D1515`),
so the card keeps its shape without any blue light. The pink N turns red. Menus and dialogs (which the
multiply can't reach) take `.night()` on Android, as now. Widgets don't change.

## What doesn't change

The web page (`web/`) keeps its current look for now. The app icon, the app mark, Terms wording, every
string, every spoken label, the layout's fit on one screen without scrolling (except at accessibility text
sizes, where it is one list),
the 44-point targets, Dynamic Type and font scale, and the self-tests all stay.
