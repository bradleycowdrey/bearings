# Bearings: the Two Degrees look

Bearings is restyled to look like Two Degrees, the same way Meridian was. This page holds the exact
numbers, so the iPhone and iPad, Mac, Android and widget work all build the same thing. DESIGN.md still
covers what the app does. This page covers how it looks. Features, wording, accessibility labels,
Dynamic Type and font-scale behaviour, the 44-point targets, night mode, the self-tests and the CI
launch arguments (`--sample`, `--format`, `--layout`, `--map-sheet`, `--no-compass`, `--show-terms`,
`--selftest`) stay as they are. Layout (sizes, gaps, the planner and the four layouts) is in LAYOUTS.md,
which follows REFINE.md Cycle 2.

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
- **The warm brand colours stay outside the app's main screen**: on the widgets (`#1A1816` with the
  crimson `#990F3D` rule), on the Terms screen, and in the app mark.
- **Shapes**: tiles, the sky card and the map are rounded 16 with continuous corners (`Look.radius`), on
  every platform. Tiles are flat white at 8% with a 1-point edge of white at 12% (`frostedTile()`). They
  aren't a blur material, so they draw the same in the self-tests' ImageRenderer and on Android. The
  only material is behind the map's buttons on Apple devices (`.ultraThinMaterial`, dark). Android uses
  black at 60% there (`Palette.mapControl`).
- **Type**: SF Pro on Apple devices, Inter on Android (as now; Inter has no Light, so where this page
  says light, Android uses Normal). Sizes below are at the default text size and scale with the
  column's `k` (DESIGN.md) as they do now.
- **Captions**: 12 semibold, uppercase, tracking 0.3, white at 60%, with a symbol 11 semibold, 5 apart
  (`CardCaption`). Captions are stored in normal case ("Latitude") and only shown in capitals, so
  VoiceOver and TalkBack still read the tile's own label.
- **Buttons**: a white capsule with black text (`LookButtonStyle`). The full-width primary is 50 high,
  17 semibold. The compact one is 14 semibold with padding 14 × 8 (44 target kept by its row). Switches,
  if any appear, use `Palette.switchOn` `#30D158`.

## The sky

The place card's sky follows the sun's real altitude where you are (`nav.sunPosition?.altitude` on
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
decorative and hidden from screen readers. It's 17 medium, white at 85%.

## Main screen, phone (top to bottom)

Background `Palette.screen` (black) edge to edge. Column margins 16 (20 on iPad). The gaps between
blocks are the planner's spacing tokens, 4 / 8 / 12 / 16 / 24 only (docs/LAYOUTS.md §3).

1. **Header bar** (replaces the title row, the sky card and the sky bar on every layout and platform;
   docs/REFINE.md §3.2): 48 high (52 on iPad) × k, radius 14 (`Look.headerRadius`), full column width,
   on the sky gradient (`skyCard(altitude:)`'s colours, unchanged). White type:
   - Line 1: the place (`nav.placeTitle`), 17 semibold, one line. When too long the state is dropped
     first ("Maroon Bells"), then it truncates.
   - Line 2: "Sun, Nov 1 · 9:41 AM", 13 regular, white at 75%, tabular figures, then the **Sample** pill
     (11 semibold, black on `Palette.notice`).
   - The time never truncates: the date shortens to "Nov 1" first, then line 2 wraps at the "·"; at
     k > 1.1, or with three trailing buttons, the Sample pill moves to line 1.
   - Trailing, fixed on every layout: the sky symbol (20, decorative), then the **map button** (Extra
     Large only; 44 × 44, 48 dp), then **⋯** (44 × 44, 48 dp; 8 apart). ⋯
     never moves. Apple uses `ellipsis.circle`; Android a 36 dp `Palette.chipOff` circle with
     `MoreHoriz`. The accessibility label stays "Settings and more".
   - There is no "Bearings" title on the main screen: iOS keeps it as the accessibility screen title,
     the Mac window's title says Bearings, and Android sets `paneTitle = "Bearings"`.
   - Accessibility text sizes: line 1 may wrap to two lines, line 2 moves under it.
   - The bar is one accessibility element with the header trait ("Aspen, Colorado, Sat, Nov 1 · 9:41 AM").
2. **Below the header**, the gaps are the planner's (docs/LAYOUTS.md §3): 4 above the header, 12 to the
   dial, **12 from the dial's bottom edge to the readout's cap height** (the line box trimmed), 6 to the
   status line. The lock row, spot row and tile grid are described in docs/LAYOUTS.md §2; their colours
   and glyphs are below.
3. **Dial**, on black, sized by the layout's rule. Restyled:
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
4. **Readout**: "228°", 56 (64 on iPad; × 1.25 at Extra Large), weight **light** (Android: Normal),
   tracking −2, white. The point "SW" is half that size, medium, white at 60%. With no compass: "—°" (U+2014,
   the degree on the same baseline) in white at 40%, and "NO HEADING" 4 below in the caption style.
5. **Status line**: 13 regular, white at 60%, centred. A warning is `Palette.notice` semibold. With no
   compass: "No compass · position, sun and map still work", same style, two lines allowed.
6. **Lock row and spot row**: full-width `frostedTile()` rows, 44 high, leading-aligned. Lock: `lock.fill`
   13, "Locked 240°" 15 semibold white, "turn 12° right" 15 white at 70%. Spot: `mappin` 17 white, "Marked
   spot" 15 medium white, "9.2 mi · 46° NE" 15 tabular white at 70%. The ✕ sits 8 after the text: on Apple
   13 semibold white at 60% in a 44 × 44 target; on Android an 18 dp `Icons.Rounded.Close` in
   `onSurfaceVariant` at 100% in a 48 dp `IconButton` (night: red at 4.5:1 or more).
7. **Tiles**, each `frostedTile()`, radius 16, padding 12 × 10, gutters 8. The caption is pinned to the top
   and the value block to the bottom (a spacer between), so grown tiles are never half empty.
   - Caption: 11 semibold caps, tracking 0.6, white at 60% (widgets keep 10). Value: 17 medium tabular,
     white (15 in the compact row; white at 60% when stale). Secondary: 13 regular, white at 60%.
   - Sun on both ports: ↑ / ↓ before the times, with a 13 pt sun glyph in the caption; in the compact row
     the caption is `SUN · ◐ 53%` and the times are 15 semibold, scaling to 0.85, then "6:36" over an 11 pt
     "AM". Nothing ever ends in "…".
   - The tap, long-press, copy and context-menu behaviours are unchanged. Before location is allowed, the
     ask-for-location tile takes the grid's place, `frostedTile()`, text 13 white at 85%, and "Use My
     Location" / "Settings" as a compact `LookButtonStyle`.
8. **Map** (tile, card and sheet), clipped to radius 16 with a 1-point `Palette.tileStroke` edge;
   `Palette.tileFill` before it loads.
   - The MAP caption sits bottom-leading on a 40% black scrim on both ports; the attribution bottom-trailing.
   - Controls: one vertical stack top-trailing on every layout and port: 36 circles in 44 pt / 48 dp
     targets, 8 apart, inset 12. Apple fill `.ultraThinMaterial` (dark), Android `Palette.mapControl`.
     White glyph, 15 semibold; Follow Heading on is a **white** circle with a black glyph.
   - Android's map style is dark (land about `#0F3B3A`, roads `#5A6470`, water `#22348A`), with a visible
     "© OpenStreetMap" 10–11 sp bottom-leading, 8 dp in, 4.5:1 or more, and (i) as a 48 dp target.
   - The speed chip uses the same fill: white 13 semibold, a capsule 10 × 5, inset 12 top-leading.
   - Your position: a white dot 16 with a 3-wide black-at-35% ring and a soft shadow. The heading cone is
     white, 45% at the dot to 0. The accuracy circle is white at 10% fill with a 1-wide white-at-40% edge.
9. **Toast** ("Coordinates copied"): a white capsule, black text 14 semibold, padding 16 × 9, 28 above
   the bottom.

## iPad and Mac

The same panel in one centred column (C = min(W − 2 × margin, 640): W − 40 on iPad, W − 32 or W − 48 on a Mac), or two panes in wide windows (docs/LAYOUTS.md
§5), with the header full width across the top.

- **Mac**: `.windowStyle(.hiddenTitleBar)`; the content keeps 16 from every window edge (24 at widths of
  600 or more). The minimum window (380 × 740) and the self-test's 420 × 840 drawing fit without scrolling.
  The update banner ("Bearings 0.2.0 is available."): `frostedTile()`, 44 high, 13 medium white, with
  "Download" as a compact `LookButtonStyle`, under the header.
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
  `Palette.bg` text (Two Degrees' terms button). "Read the Terms" is 17 medium white, 44 high. The content
  block is centred in the space above the buttons (at least the safe area + 48 from the top); on iPad the
  column is at most 480 and the buttons sit 32 below the text. The rows wrap rather than run to the edge.
  iOS styles the terms link underlined in the accent with a 44 pt hit height; Android's row icons are
  24 dp outlined `WarningAmber`, `NearMe` and `Map`. The Mac's terms prompt stays as it is.

## Widgets (Apple devices)

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
- **Medium**: the small block 128 wide | 0.5 divider | on the right, Two Degrees' hours row with three
  columns of equal width. Each column has a label 10 (the first semibold cream, like Two Degrees'
  "Now", the others medium `textMuted`), a symbol in an 18-high frame, a value 13 semibold white and a
  sub 10 `textMuted`:
  - **Sun**: the `SunRose` 34, the sun's direction "228° SW", and "23° up" or "Below".
  - **Sunrise**: `sunrise.fill` 14 in `SkyMarks.sun`, the time without AM/PM (as `MainView.shortTime`
    does, but in WidgetViews.swift, because MainView isn't in the widget target), and the AM/PM or
    nothing in 24-hour time.
  - **Sunset**: the same, with `sunset.fill`.
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
