# Bearings: Rate & Refine, Cycle 1 (UI layout)

The owner's verdict: the new colours are good, and the compass is great and should stay large. The
overall layout is terrible. The other tiles are needed, but not arranged the way they are now.

Four independent lenses rated the current build from the screenshots in `rr1/` (iOS, iPadOS, macOS,
Android, widgets, App Store) and from the code (`LayoutPlan.swift`/`.kt`, `MainView.swift`,
`MainScreen.kt`, `MapSnippet`, `WidgetViews.swift`). This file combines their findings, ranks the
weaknesses, and specifies one replacement structure for everything around the dial. **The dial
drawing, the colours, the night palette and the widgets stay as they are.**

---

## 1. Cycle 1 scorecard

| Metric | Weight | L1 | L2 | L3 | L4 | **Mean** | Confidence | Why (and what the next half-point looks like) |
|---|---|---|---|---|---|---|---|---|
| Best Practices | 16.25% | 3.1 | 3.0 | 3.2 | 3.3 | **3.2** (3.15) | High | The dial, night mode and targets meet HIG/Material. Content cut off by a fade, two stacked headers and unlabelled values do not. The next half-point needs one header and cards that are always complete. |
| Accuracy | 16.25% | 3.6 | 3.4 | 3.4 | 3.4 | **3.5** (3.45) | Medium-High | The numbers are correct (41/41 iOS and 29/29 Android checks pass), but how they are shown can mislead. "6:36–5:08" has no label or AM/PM, "53%" and "±8°" are unexplained, longitude is truncated with large text, and the no-compass rose looks live. The next half-point needs a label on every value and coordinates that never truncate. |
| Logic | 16.25% | 2.7 | 2.6 | 2.8 | 3.0 | **2.8** (2.78) | High | The layouts work backwards: a bigger compass hides information instead of moving it. The strip and the tiles repeat the same four facts, and in iPad landscape both copies are on screen. On iPhone, Medium and Large give the same dial. The next half-point needs each fact shown once in a fixed tile set, with layouts that only change proportions. |
| Flow | 16.25% | 3.0 | 2.9 | 3.1 | 3.2 | **3.1** (3.05) | Medium-High | Dial → readout reads well. After that the eye meets five text treatments, a centred spot line with a stranded ✕, an unlabelled strip, and then either a faded sliver of map or empty black. The next half-point needs one labelled tile group after the readout. |
| Spacing | 20% | 2.6 | 2.7 | 2.7 | 2.9 | **2.7** (2.73) | High | Large and XL leave 300–400 pt of black (15–20% of the screen). Medium cuts the map off mid-card. Gaps under the dial vary from 24 to 55 pt, and the strip's columns split about 50/25/25 and stretch to 1,250 pt on iPad. The next half-point needs a bottom-up planner that leaves nothing empty and nothing half-shown. |
| Form | 15% | 3.4 | 3.4 | 3.4 | 3.6 | **3.5** (3.45) | Medium | The dial, the colours and the widgets are polished. In the app, the strip, the bare spot line, a header that takes three forms and map controls that change by layout look like four design systems. The next half-point needs one tile component (caption, value, secondary) everywhere, like the widgets. |

**Weighted composite: 3.08** (from the unrounded means; 3.11 from the rounded ones). **Target 4.85. Gap 1.77.**

**Dissent (lenses 0.5 or more apart):** none. The widest ranges are Logic (2.6–3.0) and Form
(3.4–3.6). Lens 4 scored a little higher across the board because it weighted the accessibility
plumbing that already works (VoiceOver actions, 44 pt/48 dp targets, header traits) and the
correctness of the figures. All four lenses named the same top three problems on their own, so
confidence in the diagnosis is high.

**One correction to a lens:** lens 4 suggested the night secondary colour `#B33A2A` for 4.5:1.
On `#000` that colour is only about 3.6:1. Use `#E03020` (about 4.6:1) or brighter (§4.3).

---

## 2. Top 3 weaknesses (ranked by impact on the composite)

### W1. The planner leaves empty space and hides the tiles (Spacing 20%, Logic, Flow, Best Practices)

The planner sizes the dial first and keeps "calm space" under the strip at Large and Extra Large.
The dial reaches its width limit at about 361–377 pt on an iPhone, so the extra height has nowhere
to go and ends up as black. The map and the 2×2 tiles sit below a fold with no cue. This is App
Store screenshot 2.

- **Before:** iPhone 16 Pro, XL: header bar 44, dial 377, readout, subline, spot line, strip 64,
  then **about 330 pt of empty black**. Map and tiles are below the fold. Medium and Large have the
  same 361 pt dial.
- **After:** a bottom-up planner (§3.3). Every element on the first screen is placed and complete.
  Once the dial reaches its width limit, any spare height first grows the tiles (72 → 88 pt), then
  becomes a full map card if 160 pt or more is left, then is spread over three gaps (at most +12
  each). **No more than 24 pt is ever left empty at the bottom.** A planner test fails if more is.

### W2. The map is cut off mid-card on the default screen (Best Practices, Spacing, Flow, Form)

- **Before:** Medium (the default) shows 60–110 pt of map under a 16 pt black fade. The "+" button
  is half clipped, the "−" button and the Apple Maps attribution are hidden, and a "3.2 mph" chip
  floats on the sliver. It reads as a rendering bug.
- **After:** the map is never partly shown. At Medium and Large it is a **Map tile** (one grid cell,
  118 × 72–88 pt on iPhone, a live thumbnail with the heading cone and a "MAP" caption). Tapping it
  opens a full-height sheet with all the controls and the attribution. At Small, or wherever 160 pt
  or more is spare, it is a **full-width map card** of at least 140 pt with every control visible.
  The bottom fade is removed.

### W3. The summary strip is unlabelled, repeats the tiles and truncates (Accuracy, Logic, Form)

- **Before:** a 64 pt borderless capsule with three cells and no labels ("39.09898° N / 106.94117° W
  | 9,587 ft 2,922 m | 6:36–5:08 ◐ 53%"). The columns split about 50/25/25 and stretch to 1,250 pt on
  iPad. Android caps the font scale at 1.15× and still cuts the longitude to "106.94117° …". The same
  four values appear again in the hidden DETAILS tiles, and both copies show together in iPad
  landscape.
- **After:** **the strip is deleted.** One labelled tile grid replaces both the strip and the old
  DETAILS tiles: POSITION, ELEVATION, SUN, MOON and MAP. Each tile has an 11 pt caps caption, a 17 pt
  tabular value and a 13 pt secondary line (§3.4). Sun reads "↑ 6:36 AM / ↓ 5:08 PM", and moon reads
  "53% / Last quarter". Coordinates scale down to no less than 0.85× and then wrap, and are never
  ellipsized. The 1.15× clamp is removed.

*(Number 4, close behind: the two stacked headers. That is fixed in §3.2 and gives back about 60–100
pt on the default screen, which pays for the tile grid.)*

---

## 3. The redesign: "Instrument panel"

### 3.1 The structure, and why this one

**One fixed, non-scrolling screen** (at normal text sizes). From top to bottom:
**header bar → dial (hero) → readout → status line (and lock chip) → spot row → tile grid → map card
(only where it fits whole).**

Why a fixed panel and not a scrolling page under a hero dial (the Apple Weather pattern):

- **The scrolling page caused the problem.** All four lenses traced the "terrible" verdict to the
  fold: tiles hidden below it, a map cut off at it, black above it. Weather scrolls because it has
  ten or more modules and a one-line hero. Bearings has five facts and a map, which fit on one screen
  if they are laid out compactly.
- **Instruments are glanced at, not read.** Apple Compass, the Apple Watch Compass, Garmin data
  pages and the compass views in Gaia GPS and onX all show a fixed panel. Every value is visible
  without a gesture, which matters with gloves on or with one hand on a trail.
- **Each fact appears once.** The strip goes. One tile component (the widgets' caption-over-value
  pattern, which every lens praised) carries everything, so the app and its widgets look like one
  product.
- **The map is either whole or a tile, never a sliver.** On a 6.1–6.3" phone a 360 pt dial, the
  readout, the tiles and a usable map (140 pt or more) do not all fit, so the map becomes a tile
  that opens a sheet. That is the pattern Apple Weather uses for its map module and that Material
  uses for an expanding card. Where there is room (Small, iPad, Mac, landscape) it is a full card.
- **The only exception is accessibility text sizes**, where the whole screen scrolls as one list
  (§3.6). That is the HIG/Material-endorsed behaviour, and nothing is cut off there either.

### 3.2 The elements (Apple in pt, Android in dp; same numbers)

**Header bar** (replaces the "Bearings" title row, the sky card and the sky bar on every layout and
platform):

- 48 high (52 on iPad, × the text multiplier k), radius 14, full column width. It uses the existing
  sky gradient unchanged, because the owner likes the colours. At 48 instead of 72 + 52 it no longer
  competes with the dial.
- Line 1: the place, "Maroon Bells, Colorado", 17 semibold, white, one line. When it is too long,
  the state is dropped first ("Maroon Bells"), then it truncates.
- Line 2: "Sun, Nov 1 · 9:41 AM", 13 regular at white 75%, plus the **Sample** pill (11 semibold,
  existing colours).
- Trailing, at a fixed position on every layout: the sky symbol (20 pt, decorative), then the
  **map button** (map symbol, 44×44 / 48×48 dp, only when the map is neither a tile nor a card,
  §3.3), then **⋯** (44×44 / 48×48 dp, 8 apart). ⋯ never moves.
- The "Bearings" large title is removed from the main screen. iOS keeps it as the accessibility
  screen title. Mac keeps `.hiddenTitleBar`, and the window title says Bearings. Android sets
  `paneTitle = "Bearings"` for TalkBack.
- With accessibility text sizes: line 1 can wrap to 2 lines, and line 2 moves under it.

**Dial:** unchanged drawing. Centred, with side margin e (16; 8 at Large).

**Readout:** "228° SW", unchanged style. Line height 1.1 × heading size on both platforms (it was
1.2 on Apple). Heading 56 (64 on iPad), × the layout's readout scale.

**Status line** (replaces the run-on subline): 13 regular, white 60%, one line, centred:
"True north · 8° E declination · ±8° accuracy". Amber warnings replace it in the same slot, as now.
It may wrap to 2 lines only at k > 1.1, at a "·" boundary. Its VoiceOver/TalkBack label spells the
whole thing out.

**Lock chip** (only when a bearing is locked): a capsule 28 high, 8 below the status line, centred.
It has an accent fill at 20% opacity, a `lock.fill` glyph at 13, and "Locked 240° · turn 12° right"
in 13 semibold white. A trailing ✕ (13 glyph, 44×44 hit area) unlocks. Instructions are never mixed
into the reference line again.

**Spot row** (only when a spot is marked; replaces the centred spot line): a full-width tile (same
style as the grid tiles), 44 high, 8 above the grid, aligned to the leading edge on both platforms.
It contains a pin glyph (17), "Marked spot" (15 medium), "9.2 mi · 46° NE" (15 tabular,
trailing-aligned) and a ✕ at the trailing edge in a 44×44 / 48×48 dp target, 8 after the text.
Tapping the row opens the existing menu (Lock to Spot, Clear Marked Spot).

**Tile grid** (replaces the summary strip and the DETAILS tiles):

- 3 columns at a unit width u = (C − 2 × 8) / 3. On iPhone 16 Pro, C = 370 and u ≈ 118. Gutters 8.
- **Row 1:** POSITION (2 units) | ELEVATION. **Row 2:** SUN | MOON | MAP.
- Tile height 72, growing to 88 when height is spare (§3.3). Rows are 8 apart.
- **Compact row** (Small, and Large under pressure): one row, POSITION (2u) | ELEVATION | SUN.
  Moon is still shown on the dial and in the Sun details sheet. Map becomes a card (Small) or the
  header map button (Large).

**Tile component** (one component on both platforms; matches the widgets):

- Fill `frostedTile()` / `surfaceContainer` as today. Radius 16, continuous corners.
- Padding 12 on the sides and 10 at top and bottom. All content is leading-aligned.
- Caption: 11 semibold, uppercase, tracking 0.6, white 60%.
- Value: 17 medium, tabular figures, white.
- Secondary: 13 regular, white 60%.

| Tile | Caption | Value | Secondary | Tap / long-press |
|---|---|---|---|---|
| Position (2u) | `POSITION · DD` (format short name: DD, DMS, DDM, UTM, MGRS, PLUS) | "39.09898° N" over "106.94117° W" | dims when the fix is stale | Tap cycles the format (as the strip did). Long-press opens a menu: Copy, Details… |
| Elevation | `ELEVATION` | "9,587 ft" | "2,922 m" (order follows the units setting) | Opens the Details sheet (accuracy, source, pressure) |
| Sun | `SUN` | "↑ 6:36 AM" over "↓ 5:08 PM" (`sunrise.fill`/`sunset.fill` 13 pt; the AM/PM follows the locale's 12/24-hour setting) | polar: "Up all day" / "Down all day" | Opens the Details sheet |
| Moon | `MOON` | phase glyph + "53%" | "Last quarter" | Opens the Details sheet |
| Map | `MAP` (bottom-leading on a 40% black scrim) | live thumbnail, north-up, with the heading cone, no controls, gestures off | the platform's attribution stays visible; if it can't fit at this size, use the platform's snapshot API with its required attribution overlay | Opens the **Map sheet** |

**Rule:** coordinates and other values never ellipsize. Text may scale to 0.85×, then wrap; a
tile grows taller before anything truncates.

**Details sheet:** iOS `.sheet` with `[.medium, .large]` detents and a grabber; Android
`ModalBottomSheet`. It holds what the old DETAILS tiles showed (accuracy, fix age, format name,
pressure, moon phase name, rise and set azimuths) as a grouped list.

**Map card** (Small, and anywhere at least 160 pt is spare): full column width, height = the spare
height (at least 140), radius 16. Controls sit in **one** cluster on every layout: a vertical stack
of 36 pt circles (44 pt / 48 dp hit areas), 8 apart, inset 12 from the top-trailing corner (+, −,
follow heading, open in Maps). The speed chip is inset 12 top-leading. At least 24 pt is kept clear
at the bottom for attribution. There is no fade over it.

**Map sheet:** a full-height sheet (`.large` + grabber + Done; Android `skipPartiallyExpanded`)
with the same control cluster and chip as the map card.

### 3.3 The planner: bottom-up, nothing empty, nothing cut

This replaces §3–§4 of `LAYOUTS.md` in both `LayoutPlan.swift` and `LayoutPlan.kt`, with the same
constants and order and with shared golden tests.

Spacing tokens are 4 / 8 / 12 / 16 / 24 only:

| Between | Gap |
|---|---|
| Top safe area → header | 4 |
| Header → dial | 12 |
| Dial → readout | 12 |
| Readout → status line | 6 |
| Status line → lock chip | 8 |
| Readout group → spot row or grid | 16 |
| Spot row → grid, and between rows | 8 |
| Grid → map card | 12 |
| Grid or map → bottom safe area | 8 |
| Side margins | 16 (20 on iPad) |

The column is C = min(W − 2 × margin, 640).

Algorithm (S = the safe height):

1. Place the fixed blocks: header, readout group, lock chip (if locked), spot row (if marked), and
   the grid in the layout's default mode.
2. Dial = min(cap, S − fixed), where cap = C − 2e on phones and min(C − 2e, 0.48 H) on tablets.
3. If the dial would fall below the layout's **floor**, give things up in this order: (a) Large
   only: the grid collapses to its compact row and Map moves to the header button; (b) Small only:
   the map card shrinks toward 140, then the dial goes down to its floor; (c) otherwise, switch to
   the scrolling list (§3.6).
4. Spare height (the dial at its cap): (a) if spare ≥ 160 and the map is a tile, promote it to a
   full-width map card filling the spare; (b) otherwise grow the tiles 72 → 88; (c) then add up to
   +12 to each of three gaps (header → dial, dial → readout, readout group → grid); (d) split any
   remainder above the header and below the grid. **Spare at the bottom is never more than 24.**

### 3.4 The four layouts (owner's decision: keep Small, Medium, Large and Extra Large)

The panel suggested three choices. The owner asked for four, so there are four, each with a clearly
different result. The menu shows each with a one-line subtitle so the choice explains itself.

| | **Small**: "Compass and map" | **Medium** (default): "Balanced" | **Large**: "Bigger compass" | **Extra Large**: "Biggest compass" |
|---|---|---|---|---|
| Dial | 0.36 H, floor 0.30 H to keep the map card at 140 or more | fills to the cap (C − 32); floor 0.38 H | e = 12, cap C − 24; floor 0.42 H | e = 8, cap C − 16; never shrinks while the grid can collapse |
| Readout scale | 1.0 | 1.0 | 1.08 | 1.15 |
| Grid | compact row (Position 2u, Elevation, Sun) | full 2-row grid with the Map tile | full grid; collapses to the compact row before the dial shrinks | compact row (Position 2u, Elevation, Sun) |
| Map | full-width card filling the rest (140 or more) | tile; promoted to a card when 160 or more is spare | tile, or the header map button when the grid is collapsed | the header map button (opens the map sheet) |

**Worked numbers: iPhone 16 Pro** (402 × 874, S = 778, C = 370). These replace LAYOUTS.md §3.3.
"Spare" is what step 4 spends on taller tiles and wider gaps.

| State | Small | Medium | Large |
|---|---|---|---|
| Nothing locked or marked | dial 315, map card 189 | dial **370** (today 361), tiles grow to 88, spare 38 spread | dial **386**, full grid, tiles grow to 88, spare 20 spread |
| Locked + marked (the sample) | dial 262 (floor), map card 154 | dial **352** (today 361), full grid | dial **386**, compact row, map button in the header |
| Bottom space left | ≤ 24 | ≤ 24 | ≤ 24 |

In the worst case, Medium's dial is 9 pt smaller than today. In every other case it is 9 pt larger,
and Large is 9–25 pt larger than today's XL. The compass stays the hero.

Android (for example the 914 dp test device): use the same rules in dp, with 48 dp targets and the
same gaps.

### 3.5 iPad, Mac and landscape

- **Portrait iPad, and Mac windows taller than wide:** a single column with C = min(W − 40, 640),
  centred. The same four layouts apply. On larger iPads, step 4a usually promotes the map to a card
  (iPad 13": dial about 656 and a map card of about 200). On iPad mini, Map stays a tile.
- **Two panes** (W > H and W ≥ 700, or a phone in landscape):
  - One **full-width header bar** across the top. Its title is not split between panes.
  - **Leading pane** (W − trailing): dial, readout, status line and lock chip, centred as one group
    vertically and horizontally. The dial is min(pane − 32, the height left for the group).
  - **Trailing pane** = clamp(share × W, 320, 480), where the share is 0.48 (Small), 0.42 (Medium)
    or 0.36 (Large). It is top-aligned with the dial's top and contains the spot row, the grid
    (3 columns if the pane is at least 360 wide, otherwise 2 columns with Map spanning 2), then the
    **map card** filling the rest (at least 160; otherwise Map stays a tile).
  - The Mac and iPad footer ("Made by Bradley Cowdrey · bradcowdrey.com ↗", 13 secondary) is the
    last line of the trailing pane.
  - **No strip, and nothing shown twice.**
- **Mac update banner:** 44 high, between the header and the content, full width, using the tile
  style.

### 3.6 Text size

- **k up to 1.3** (Apple) / **fontScale up to 1.3** (Android): the planner runs with k-scaled
  heights. Tiles grow before anything truncates, and coordinates scale to 0.85× and then wrap.
  **Remove the 1.15× clamp** in `MainScreen.kt`, and raise iOS `minimumScaleFactor` from 0.6 to
  0.85.
- **Accessibility sizes** (iOS AX1+; Android fontScale ≥ 1.5): the whole screen becomes one
  `ScrollView`/`LazyColumn` with the scroll indicator flashed on appear:
  - the header (wraps)
  - the dial at min(C − 32, 0.40 H)
  - the readout
  - the status line and lock chip (stacked)
  - the spot row (wraps)
  - the tiles as **full-width rows** (caption above the value, values wrap)
  - the map card at 200
  - the footer

  Every block is complete. The list just continues below the fold, as a list should.

### 3.7 Widgets

No structural change; the widgets are the reference pattern. Two alignment changes:

- Share the caption, value and secondary tokens with the app tile through one `Look` constant.
  Widgets keep 10 pt captions because of their size.
- Use the same Sun wording ("↑ 6:36 AM ↓ 5:08 PM") and Moon wording ("53% · Last quarter") in both
  the app and the widgets.

---

## 4. Smaller fixes by screen

### 4.1 Terms (first run)

- Top-align the content at the safe-area top + 48 (it is centred low today). Column max 480 on
  iPad, centred.
- App mark 80, centred. Title 28 bold.
- Replace the 9-line paragraph with 3 rows, each with a 17 pt symbol and 17 pt body text at 1.35
  line height:
  - "Not a navigation instrument"
  - "Your location stays on this device"
  - "Map from Apple Maps / Google Maps"
- Legal sentence: 15 pt at 4.5:1 contrast or better, with the terms URL as an inline link.
- New line: "Next, Bearings asks for your location."
- Buttons pinned 16 above the home indicator: **I Agree**, filled, 50 high, full width. **Read the
  Terms**, bordered or tonal, 44 / 48 dp, same width, 12 above it.

### 4.2 No compass / live

- The rose drops to 40% opacity. Hide the lubber triangle, the lock arc and the map cone. Put a
  28 pt "no compass" glyph (`location.slash`) in the centre, and a small "N ↑ fixed" label inside
  the top of the ring so the sun and moon marks read as relative to north.
- Readout: "—°" in the readout style at white 40%.
- Status-line slot (2 lines allowed): "No compass on this device · position, sun and map still
  work".
- Tiles and map are unchanged. Announce the state once through a polite live region.
- Before the first fix, tiles show "—" with the secondary "Finding position…", never blank.

### 4.3 Night

- Secondary text must be **at least `#E03020` on `#000` (about 4.6:1)**. Today's dim red is about
  2.5:1, and lens 4's `#B33A2A` is only about 3.6:1.
- The map tile, card and sheet are tinted red at 15% brightness or less, so the map is never the
  brightest thing on screen.
- Lock-chip fill: night accent at 25%.

### 4.4 Menus

- ⋯ is fixed at the trailing end of the header (44×44 / 48×48 dp) on every layout.
- "Layout" submenu: four items (Small, Medium, Large, Extra Large), each with a symbol, a one-line subtitle and a checkmark on
  the current choice (Android: `DropdownMenuItem` with supporting text).
- When the layout changes, the change animates and focus stays in place. There is no scroll
  position to reset any more.

### 4.5 Spot and lock

- Covered in §3.2: the spot row is aligned to the leading edge on both platforms, and the ✕ sits
  8 after the text, never at the far margin.

### 4.6 Consistency between ports

- Both samples show 9:41 (Android shows 9:00 today).
- The spot glyph is the same on both platforms.
- The map control cluster is identical on both platforms.
- iOS and Android XL no longer disagree, because XL no longer exists.

### 4.7 Tests (both ports, run in CI)

- Golden table: device × layout × state (none, locked, marked, both) gives the dial size, grid
  mode, map mode and bottom spare. The test fails if the bottom spare is more than 24, any block is
  partly visible, or the dial falls below its floor.
- A rendering test fails on any "…" in a coordinate string at every text size.
- A contrast test of the night palette fails below 4.5:1 for secondary text.

### 4.8 Docs and marketing

- Rewrite `LAYOUTS.md` §2–§7 and §12 for this design. Update the header section of `LOOK.md`.
  Regenerate the App Store screenshots: iphone-02 must not show empty space.

---

## 5. Projection

If §3–§4 are built as specified:

| Metric | Now | Projected |
|---|---|---|
| Best Practices | 3.2 | 4.3 |
| Accuracy | 3.5 | 4.4 |
| Logic | 2.8 | 4.4 |
| Flow | 3.1 | 4.3 |
| Spacing | 2.7 | 4.3 |
| Form | 3.5 | 4.3 |
| **Composite** | **3.08** | **≈ 4.33** |

The remaining gap to 4.85 can only be closed by checking on real devices:

- the planner's numbers on the smallest phones (iPhone SE, compact Android)
- the Map-tile thumbnail's legibility and attribution
- night-map luminance
- VoiceOver/TalkBack order through the tiles

Cycle 2 should re-shoot the same scenario set and score again.

## Cycle 2

Cycle 2 scores the screens rebuilt to the instrument-panel spec above (§3): iPhone, iPad, Mac, Android, the widgets, and the new map sheets. Four lenses scored on their own; the table gives their mean.

### C2.1 Scorecard

| Metric (weight) | L1 | L2 | L3 | L4 | **Mean** | Δ vs cycle 1 | Confidence | Why, and what the next half-point needs |
|---|---|---|---|---|---|---|---|---|
| Best Practices (16.25%) | 3.9 | 3.7 | 3.6 | 3.6 | **3.7** | +0.55 | High | One header, sheets with a grabber and Done, 44 pt / 48 dp targets, and accessibility sizes that scroll. Still lost: Android tiles run off the screen, values get an ellipsis, and the Android map is light on a dark UI. |
| Accuracy (16.25%) | 3.9 | 3.8 | 3.6 | 3.8 | **3.8** | +0.33 | Medium-High | Every value is now labelled. Sun reads `6:36…` on iPhone S/L/XL and Mac, Android cuts the coordinates off, the header time truncates, and the no-compass readout draws as `_ °`. |
| Logic (16.25%) | 3.6 | 3.6 | 3.4 | 3.6 | **3.6** (3.55) | +0.77 | Medium-High | Each fact appears once and the panel order is right. The four layouts don't give four results: iPhone L ≈ XL, Android L = M, iPad XL shows more map than M, and the compact row drops Moon. |
| Flow (16.25%) | 4.0 | 4.0 | 3.8 | 3.9 | **3.9** | +0.88 | Medium | The scan runs header → dial → readout → status → chip → spot → tiles. It is slowed by a 40–60 pt gap between dial and readout, a ragged three-line centred stack, the map hidden in a thumbnail, and controls that change shape. |
| Spacing (20%) | 3.5 | 3.2 | 2.9 | 3.2 | **3.2** | +0.47 | High | Medium is tidy. The compact row is 4u + 3 gaps inside a 3u + 2 gap column: 126 dp of overflow on Android, off-grid squeezing on Apple. Grown tiles are 30–50% empty, the Mac window has no bottom margin, and Terms has an empty middle band. |
| Form (15%) | 3.9 | 3.8 | 3.6 | 3.8 | **3.8** | +0.33 | Medium | One tile component, and the widgets match the app. The ports drift: map controls in three shapes, the MAP caption in different corners, sun glyphs vs arrows, a light Android map, faint 9–10 dp ✕ glyphs on Android, and the `—°` glyph is broken. |
| **Composite** | | | | | **3.64** | **+0.56** (3.08 → 3.64) | | Target 4.85; gap 1.21. |

The composite uses the unrounded means: 0.1625 × (3.700 + 3.775 + 3.550 + 3.925) + 0.20 × 3.200 + 0.15 × 3.775 = 3.64.

**Dissent (spread of 0.5 or more).** Only Spacing splits, from 3.5 (L1) to 2.9 (L3). L1 scored Medium on iPhone and iPad as "complete, with little empty space" and counted the overflow as one bug. L3 also counted the off-grid widths of Apple's squeezed compact row (about 1.55u / 1.0u / 0.9u), the 40–60 pt gap between dial and readout, and the Mac's missing edge margins as separate rhythm faults. Both agree the compact row is the largest single Spacing defect. The other metrics spread by 0.3 or less, so the panel agrees.

**What improved.** Logic +0.77 and Flow +0.88: one header, one map surface per layout, no duplicated facts, and a clear vertical scan. The owner's complaint ("the overall layout is terrible") is now mostly about the four layouts and the compact row, not the Medium default.

### C2.2 Top 3 weaknesses (ranked by impact on the composite)

**1. The compact row doesn't fit its column, so values overflow on Android and get an ellipsis on Apple.** This costs about 0.4 of composite across Spacing, Accuracy, Best Practices and Form. All four lenses raised it, and all four rated it Critical or High.
- *Cause:* §3.2 defines the row as Position 2u + gap | Elevation u | Sun u = 4u + 3 gaps, inside a column of 3u + 2 gaps.
  - Android lays it out at full width and centres it (`MainScreen.kt:818`), so it overflows by about 126 dp at C = 380. The screen shows `ION · DD`, `9898° N` and `SUN ↑ 6:36`.
  - Apple squeezes the row to 44 / 28 / 28 % of C − 16 (`LayoutPlan.swift:163`). Sun gets about 99 pt, so the times read `6:36…` / `5:08…`, and Mac shows `6:36 A…`.
- *Before:* `[2u+8 | u | u]` = C + u + 8. Moon is dropped.
- *After:* widths come from C, not from grid units. With **w = max(104, round(0.27 C))**, Elevation = Sun = w and Position = C − 2·8 − 2w.
  - At C = 370 that gives 338 → 146 | 104 | 104. At C = 380 it gives 156 | 104 | 104. At iPad C = 700 it gives 306 | 189 | 189.
  - Sun value: 15 pt semibold tabular, `.minimumScaleFactor(0.85)`, then wrap to `6:36` over an 11 pt `AM`. Never set `lineLimit(1)` with truncation.
  - Moon stays in the row through the Sun caption: `SUN · ◐ 53%`.
  - The Position value drops to 15 pt in this row only.
  - New test on both ports, for every layout × device class: `sum(widths) + gaps == C`, and no `…` in any tile or in the header time.

**2. The four layouts don't give four distinct results, and the map moves with no visible rule.** This costs about 0.25 (Logic, Flow, and the owner's explicit requirement).
- *Before:*
  - iPhone Large (dial 378) and XL (386) share the compact row and the header map button.
  - Android Large renders the same as Medium.
  - iPad and Mac XL ("Biggest compass") show a 1,130 × 270 map card, while Medium ("Balanced") shows a 360 × 150 thumbnail.
- *After:* one rule per layout, the same on every port and device.

  | Layout | Grid | Tiles | Map | Dial | Readout |
  |---|---|---|---|---|---|
  | **Small** | compact row | 72 | card of 140 or more | 0.36 H | 1.0 |
  | **Medium** | full 2-row grid | 72–88 | tile, or card when 160 or more is spare | cap | 1.0 |
  | **Large** | full grid | fixed 72 | tile | gets the saved height | 1.0 |
  | **XL** | compact row | 72 | header button, on every device | C − 16 | 1.25 (64 → 80) |

  - Planner golden test: dial(L) − dial(M) ≥ 24 **or** the grid mode differs, and the same for XL against L.
  - The layout menu subtitle states the result, for example "Dial 386 · map in header".

**3. Grown tiles and loose vertical rhythm leave the grid looking unfinished.** This costs about 0.2 (Spacing, Form, Flow).
- *Before:*
  - Tiles grow from 72 to 88 (iPad about 150, iPad landscape about 380) with content stuck to the top, leaving 30–50% empty.
  - There is 40–60 pt between the dial and `228°`.
  - Status → chip runs from 8 to about 45 pt at large text.
  - Mac tiles sit flush on the window's bottom edge.
- *After:*
  - Caption pinned top at a 10 pt inset, and the value block bottom-aligned at a 10 pt inset (Spacer between them), as the widgets do.
  - Tile growth capped at 88 on phones and 96 on iPad. Spare height goes to the dial, then to the map card.
  - Dial → readout = 12, measured from the dial's bottom edge to the digits' cap height. Trim the line box (`.firstTextBaseline`, `includeFontPadding=false`).
  - Gap tokens are fixed and multiplied only by k: status → chip 8 × k, chip → spot 16 × k.
  - Mac: 16 pt inset on all four edges (24 at widths of 600 or more), subtracted before the map card is sized.

### C2.3 Prioritized fix list (cycle 2 → cycle 3)

The instrument-panel structure and the four layouts stay; no lens gave a structural reason to drop either. Items are ranked by estimated composite gain. Platforms: **A** = Apple (iPhone, iPad, Mac), **D** = Android.

| # | Platform / screen | Before | After | Metrics (est. composite gain) |
|---|---|---|---|---|
| 1 | D Small, XL, XL + large text (`MainScreen.kt:818`); spec §3.2 | Compact row `[2u+8, u, u]`, about 126 dp wider than C. Position clipped left, Sun clipped right | Widths `[C−16−2w, w, w]` with w = max(104, 0.27C). `TileRow` asserts the sum equals C. Rewrite spec §3.2 to match | Spacing, Accuracy, BP (+0.20) |
| 2 | A iPhone S/L/XL, Mac Small, XL-min (`LayoutPlan.swift:163`) | 44 / 28 / 28 split. Sun about 99 pt: `6:36…`, `6:36 A…` | Same w formula. Sun value 15 pt tabular, scale 0.85, then wrap with AM/PM in 11 pt. No truncation mode on times | Accuracy, Form (+0.12) |
| 3 | All ports, compact row | Moon disappears with no indication | Sun caption becomes `SUN · ◐ 53%` (11 pt caps). The Sun tile's tap opens the sky sheet with Moon in full | Logic (+0.04) |
| 4 | All ports, layout planner and menu | iPhone L ≈ XL (8 pt of dial), Android L = M, iPad and Mac XL map card larger than M's | The per-layout rules in C2.2 #2, a golden test on both ports for a 24 pt dial difference or a different grid mode, and a dial size in the menu subtitle | Logic, Flow (+0.15) |
| 5 | iPad portrait, Medium | Map is a 360 × 150 thumbnail with 160 or more spare | Promote the map to a card of 200 or more whenever 160 or more is spare (§3.4 step 4a). XL never shows a card | Logic, Flow (+0.05) |
| 6 | All ports, tile component | Content pinned to the top. 88 pt tiles 30–50% empty. POSITION · MGRS is one line in an 88 box | Caption top at inset 10, value block bottom at inset 10. Cap growth at 88 (phones) / 96 (iPad). Excess goes to the dial, then the map card | Spacing, Form (+0.08) |
| 7 | All ports, dial → readout | 40–60 pt gap vs 6–8 pt below | 12 pt, dial bottom to cap height, with the line box trimmed. The roughly 40 pt recovered goes to the dial or the map card | Flow, Spacing (+0.06) |
| 8 | iPad landscape two-pane | Sun and Moon tiles about 380 pt tall holding 3 lines, uneven split, and a footer that appears only here | Fixed 80 pt rows, Sun and Moon at (C − 8)/2 each, the rest to the map card. Footer moves into the ⋯ menu on every layout | Spacing, Logic (+0.04) |
| 9 | D map tile, card and sheet | Light OpenFreeMap style, the brightest object on a dark screen. Only an (i) for attribution | Dark style (background about #0F3B3A, roads #5A6470, water #22348A), red-tinted at night at ≤15% luminance. Visible `© OpenStreetMap` at 10–11 sp, bottom-leading, 8 dp inset, ≥4.5:1, with (i) as a 48 dp target | Form, BP, Accuracy (+0.06) |
| 10 | A and D, map controls | Horizontal row of 4 (iPhone Small, iPad XL, landscape), 2×2 (D Small), vertical (sheets). `+` collides with labels | One vertical stack everywhere: 36 pt circles with 44 pt / 48 dp hit areas, 8 apart, inset 12 top-trailing. Cards under 192 tall show + / − / ⋯ (follow and open-in-Maps go in the overflow) | Form, BP (+0.05) |
| 11 | A and D, map sheet (iphone-10, ipad-10, android-11) | Rounded inset card inside the sheet: double frame, 16 pt gutters. iPad form sheet covers half the dial. D sheet under the status bar, title and Done on different baselines, no heading cone or speed chip | Full-bleed map under a translucent bar (`Map` title, Done trailing, one baseline; D: 64 dp top bar, 20 sp / 16 sp, `contentWindowInsets` for the status bars, `skipPartiallyExpanded`). iPad uses `.presentationSizing(.page)`. Add the heading cone and the `3.2 mph` chip to D. Attribution in the bottom safe area | BP, Form (+0.05) |
| 12 | A and D, MAP caption | Top-leading on iOS, bottom-leading on D | Bottom-leading on a 40% scrim on both, attribution bottom-trailing | Form (+0.02) |
| 13 | A and D, no compass (iphone-4-live) | Readout `_ °` / `__°`, about 90 pt extra gap below it, rose barely dimmed, status line edge to edge | `—°` (U+2014) at readout size, white 40%, degree baseline-matched. 11 pt caps `NO HEADING` beneath. Whole rose at 40% opacity with a 28 pt `location.slash` centre. Readout → status 6. Status reads `No compass · position, sun and map still work`, wrapping at `·` within C − 32. VoiceOver/TalkBack: "Heading unavailable". Tiles stay 72 and the spare goes to a 160 map card | Accuracy, Form (+0.05) |
| 14 | D XL + large text header; Mac XL-min header | Time truncated to `9:41 …` | Never ellipsize the time. First shorten the date to `Nov 1`, then wrap line 2 at `·`. When k > 1.1 or there are 3 trailing buttons, move the Sample pill to line 1 | Accuracy (+0.03) |
| 15 | A and D, large text (iphone-5, -9, android-6) | First screen ends mid-tile (Elevation sliced at the fold) with no scroll cue | Choose the AX dial min(C − 32, 0.40H) so the fold falls 24 or more below a whole block. Flash the scroll indicator on appear. 24 pt bottom fade. Confirm VoiceOver/TalkBack swipe scrolls into the cut tile | Flow, BP (+0.04) |
| 16 | A and D, readout group | Three centred elements (status, chip, spot) form a ragged stack | Lock state uses the spot-row form: one full-width 44 pt leading-aligned row `Locked 240° · turn 12° right ✕` with the tile background. Status stays centred above | Flow, Form (+0.03) |
| 17 | Mac, all layouts | Header about 8 from the top edge, last row flush on the bottom edge | 16 pt inset on all edges (24 at widths of 600 or more). Window minimum height = header + dial + grid + insets. Mac added to the bottom-spare test | Spacing (+0.03) |
| 18 | D lock chip and spot row ✕ | Glyph about 9–13 dp, white 60%, floating about 30 dp from the edge, nearly invisible red at night | 18 dp `Icons.Rounded.Close` in onSurfaceVariant at 100% (night: red at ≥4.5:1), centred in a 48 dp IconButton at a 4 dp trailing inset | Form, BP (+0.02) |
| 19 | A vs D, Sun rows | Sunrise and sunset glyphs on Apple, ↑ / ↓ on Android. `6:36 AM` on iPhone, `6:36AM` on iPad and Mac | One treatment on both ports: ↑ / ↓ plus a 13 pt sun glyph in the caption. One formatter (`.hour().minute()` with a narrow no-break space before AM/PM) on every Apple platform, matching Android | Form, Accuracy (+0.02) |
| 20 | Terms (iphone-1, ipad-1, android-1) | Content pinned to the top with a 500–1,000 px empty middle (iPad worst). D uses a compass glyph for "Not a navigation instrument". Third row runs to the edge. iOS link not styled. Red sliver on the D icon | Centre the content block in the space above the buttons, with a minimum of safe area + 48. On iPad, cap the column at 480 and group the buttons 32 below the text. D: 24 dp outlined `WarningAmber` / `NearMe` / `Map`, and allow wrapping. iOS: underlined accent `Link` with a 44 pt hit height. Re-export the D icon without the edge artifact | Spacing, Form (+0.03) |

**Tests added this cycle (both ports):**
- The compact and full row widths plus gaps equal C, for every layout × device class.
- No `…` in any tile value or in the header time, at text scales 1.0 / 1.3 / AX1.
- Adjacent layouts differ by at least 24 pt of dial or by grid mode.
- The Mac window has margins of 16 or more on all edges.
- The no-compass readout string is `—°`.

### C2.4 Projection

Items 1–7 are the compact row, the layout rules, the tiles and the gap between dial and readout. Fixing them should lift Spacing to about 4.0, Accuracy to 4.3, Logic to 4.2 and Flow to 4.3, for a composite of about 4.2. Items 8–20 bring parity and polish and add about 0.15–0.2, so about **4.35–4.4** after cycle 3. Reaching 4.85 will take a cycle 4 that re-shoots every scenario and confirms there are no clipped strings, matching ports, and the four layouts visibly distinct on every device.

## Cycle 3

Cycle 3 scores the screens rebuilt after the cycle-2 fix list (C2.3): iPhone, iPad (portrait and landscape), Mac, Android, the widgets, the map sheets, the no-compass and live states, night mode and the large-text sizes. Four lenses scored on their own; the table gives their mean.

### C3.1 Scorecard

| Metric (weight) | L1 | L2 | L3 | L4 | **Mean** | Δ vs cycle 2 | Confidence | Why, and what the next half-point needs |
|---|---|---|---|---|---|---|---|---|
| Best Practices (16.25%) | 4.0 | 3.9 | 3.9 | 3.8 | **3.9** | +0.20 | Medium | One header, full-bleed sheets with Done, 44 pt / 48 dp targets, and scrolling at accessibility sizes. Still lost: the Android map labels ignore Material dark-surface rules, the dial does not shrink at large text, and the lock row differs between ports. |
| Accuracy (16.25%) | 3.9 | 3.9 | 3.8 | 3.8 | **3.9** (3.85) | +0.08 | High | No ellipses and every value labelled. The no-compass readout still draws as `_ °` on iPhone, iPad and Android (the test checks the string, not the pixels), and the Mac XL-min Position lines render at two sizes. XL drops `, Colorado` from the title. |
| Logic (16.25%) | 3.8 | 3.8 | 3.7 | 3.7 | **3.8** (3.75) | +0.20 | Medium | Each fact appears once, Moon survives as `SUN · ◐ 53%`, and Small and XL are distinct. Large still looks like Medium on phones (24 pt of dial, tiles 84 → 72), iPad landscape Small = Medium pixel for pixel, and iPad no-compass switches to a grid no layout uses. |
| Flow (16.25%) | 4.1 | 4.0 | 3.9 | 3.9 | **4.0** (3.98) | +0.05 | Medium | Header → dial → `228° SW` → status → lock → spot → tiles runs cleanly and the dial-to-readout gap is gone. The header jumps 20–50 pt between layouts and states, large text ends the first screen mid-Position, and iPad landscape strands the readout in the bottom-left corner. |
| Spacing (20%) | 3.6 | 3.6 | 3.4 | 3.4 | **3.5** | +0.30 | High | The compact row now sums to C and Medium is tidy. Spare height still goes into gaps (Android XL lock → spot about 27 dp vs 8), iPad landscape tiles are 190–530 pt tall holding 2–3 lines, iPad gutters jump 92 → 36, and XL ends on a 50–110 pt dead band. |
| Form (15%) | 3.9 | 3.8 | 3.7 | 3.8 | **3.8** | +0.03 | Medium | The tile component, palette, night mode and widgets hold together on Apple. Android drifts: neutral run-on lock row, cyan italic map labels, three pills in the tile's bottom strip. The `—°` glyph is broken everywhere, and iPad uses phone type inside tablet-sized tiles. |
| **Composite** | | | | | **3.78** | **+0.14** (3.64 → 3.78) | | Target 4.85; gap 1.07. |

The composite uses the unrounded means: 0.1625 × (3.900 + 3.850 + 3.750 + 3.975) + 0.20 × 3.500 + 0.15 × 3.800 = 2.515 + 0.700 + 0.570 = 3.78.

**Dissent (spread of 0.5 or more): none.** The widest spreads are 0.2: Flow (4.1 to 3.9) and Form (3.9 to 3.7). L1 gave Flow credit for the phone-portrait scan. L3 and L4 docked it for the large-text fold and the iPad landscape readout. Spacing splits 3.6 / 3.4 on the same evidence: L3 and L4 counted each loose gap (header inset, lock → spot, XL foot, iPad gutters) as a separate rhythm fault. The panel agrees on the defects and differs only in how much each costs.

**What improved, and what did not.** Spacing (+0.30), Logic (+0.20) and Best Practices (+0.20) moved the most, because C2.3 #1–3, #6, #7 and #11 landed: the compact row fits, tiles bottom-align, the readout sits 12 below the dial, and the sheets are full-bleed. Five cycle-2 items did not land or landed only partly:
- #4: Large is still not visibly distinct from Medium.
- #8: iPad landscape tiles are still stretched.
- #9: the Android map is dark now, but its labels are cyan italic.
- #13: the `—°` glyph still draws as `_ °`.
- #16: the lock row was built differently on Apple and Android.

Those five account for most of the gap to the cycle-2 projection of 4.35.

**The planners diverge.** The two ports do not follow the same rules:
- **Medium:** Apple derives Medium's dial as Large − 24 (`LayoutPlan.swift:469`). Android gives Medium its own cap of W − 40 (`LayoutPlan.kt:235`).
- **Large:** Apple promotes Large's map to a card when 160 or more is spare. Android always keeps it a tile.
- **Spare height:** Apple still widens gaps with spare height (`gapGrow`, `LayoutPlan.swift:279/506–511`). Android widens two other gaps.

C3.3 replaces both with one rule set.

### C3.2 Top 3 weaknesses (ranked by impact on the composite)

**1. Spare height is spent on gaps and the header moves, so the vertical rhythm differs by layout, state and port.** This costs about 0.20 of composite (Spacing 20%, Flow, Form). All four lenses raised it.
- *Before:*
  - Android XL lock → spot is about 27 dp (66 px); other layouts use 8.
  - The header top is at y ≈ 151 on iPhone Medium, 170 on XL and 197 on live. On Android it is 123 on Medium and 175 on XL and live.
  - iPhone XL ends 60–110 pt above the home indicator.
  - iPad gutters are 92 on Medium and 36 on XL.
  - iPad landscape tiles stretch to 190–530 pt.
- *After:* the gaps are frozen and spare height has a fixed order.
  - The header is pinned at safe-area top + 8 (status bar + 8 dp) in every layout and state.
  - Gaps are fixed tokens × k and never grow: header → dial 12, dial → readout 12, readout → status 6, status → lock 8, lock → spot 8, readout group (or spot) → grid 8, row gaps 8, grid → map card 12, bottom 16 (24 on iPad and Mac).
  - Spare height goes, in order:
    1. To the dial, up to its cap.
    2. To the map card, for Small and Medium only.
    3. To tile growth, Medium only, 72 → 88 (96 on iPad).
    4. Split between header → dial and the bottom, each at most 24.
  - Delete `gapGrow`.
  - New planner test on both ports, for every device × layout × state (sample, live, no-compass, locked or not): every inter-row gap equals its token × k, the header top equals safe top + 8, and bottom spare ≤ 24.

**2. Large is still "Medium plus 24 pt", so the owner's four layouts read as three.** This costs about 0.15 (Logic, Flow). It also fails the owner's explicit requirement.
- *Before:*
  - On iPhone, Medium is dial 352 with a 3-column grid (Position 2u | Elevation, Sun | Moon | Map tile at 84). Large is dial 376 with the same grid at 72.
  - On Android, Large and Medium differ by 24 dp.
  - iPad landscape Small and Medium are identical.
- *After:* the map surface shrinks as the compass grows, one step per layout, and each step changes the grid mode.
  - **Large** drops the Map tile. The map moves to the header button, as in XL, and the grid becomes 2 × 2 at (C − 8)/2 per tile: Position | Elevation, then Sun | Moon.
  - That saves the map tile's width and keeps two rows at fixed 72. The dial cap rises to C − 16.
  - On iPhone 16 Pro (sample state): Medium has dial 352 and a 3-column grid with the Map tile. Large has dial 370 (C), a 2 × 2 grid and the map in the header. XL has dial 370 at C, one compact row, readout 1.25, and the 80 pt of a row is saved for the readout and spare.
  - Golden test: adjacent layouts must differ in grid mode **and** map surface (card → tile → button), and dial(L) ≥ dial(M) + 16.
  - Menu subtitles say what changes: Small "Compass + big map", Medium "Balanced · map tile", Large "Bigger compass · map in header", Extra Large "Biggest compass · one row".

**3. The no-compass readout still renders as `_ °` on every port.** This costs about 0.10 (Accuracy, Form, Best Practices). It has been raised for three cycles.
- *Before:* the string is `—°`, but cap-height trimming sets the dash on the baseline. It renders at about 40% width with a ring floating about 20 pt to the right (iphone-4-live, iphone-11, ipad-11, android-12, mac no-compass). About 90 pt of dead space follows before the next row. The test compares strings.
- *After:*
  - Draw the dash as a shape, not a glyph: a rounded rect 0.5 em × 0.08 em at the readout size (28 × 4.5 pt at 56 pt), white at 40%. Centre it on the digits' cap-height midline. Place the `°` exactly where it sits after `228`, at the same size and weight.
  - Drop the separate 11 pt `NO HEADING` caption and fold it into the status line: `No compass · position, sun and map still work`.
  - Gaps: dial → readout 12, readout → status 6.
  - The stack is two lines. The roughly 56 pt freed goes to the dial, then to a 160 map card.
  - Replace the string test with a render test on both ports: the dash's vertical centre must be within ±4 pt of the digit centre-line of `228°` at the same scale.
  - Accessibility label: "Heading unavailable".

### C3.3 One planner rule set (Apple and Android, identical constants)

This replaces §3.3 step 4, §3.4 and C2.2 #2. `LayoutPlan.swift` and `LayoutPlan.kt` must hold the same constants, run the same steps in the same order, and pass one shared golden table (JSON in `docs/`, read by both test suites).

| | **Small** "Compass + big map" | **Medium** "Balanced · map tile" | **Large** "Bigger compass · map in header" | **Extra Large** "Biggest compass · one row" |
|---|---|---|---|---|
| Grid | compact row (Position C−16−2w, Elevation w, Sun w; w = max(104, 0.27C)) | 3-column, 2 rows: Position 2u, Elevation, then Sun, Moon, Map tile | 2 × 2 at (C − 8)/2: Position, Elevation, then Sun, Moon | compact row |
| Tiles | 72 | 72, grows to 88 (96 tablet) from spare only | fixed 72 | 72 |
| Map | card ≥ 140, takes all spare | tile; promoted to a card (≥ 200) when ≥ 160 is spare | header button | header button |
| Dial cap | 0.40 H (its floor) | C − 32 (tablet: min(C − 32, 0.48 H)) | C − 16 (tablet: min(C − 16, 0.54 H)) | C − 16 (tablet: min(C − 16, 0.64 H), column widens to the dial) |
| Dial floor | 0.40 H | 0.40 H | 0.40 H, and over Medium | 0.40 H, and the largest |
| Readout | 1.0 | 1.0 | 1.0 | 1.25 |
| Pressure order | map card → 140, then a map tile (≥ 72), then the header button; then one merged row | tiles → 72, then the compact row (map in the header); then one merged row | dial → floor + 16, then compact row; then one merged row | the lock and spot rows merge; then the list |

**Owner's rule: dial ≥ 40% of H.** "The compass takes up at least 40% of the screen" is a hard rule, and it overrides every floor above. In one column (phones, iPad portrait, Mac windows taller than wide), at Text Size 1.0 to 1.3, every layout's dial is at least min(0.40 H, C − 16) (C the column; 8 from each edge), with H the full screen or window height. Small sits at that floor; Medium is at or over it; Large is over Medium (16 over where the height allows: it gives up its 2 × 2 for the compact row rather than sit within 16 of the floor); Extra Large is the largest (it merges its rows rather than fall under Large, and Large never passes Extra Large's best dial; where Extra Large falls back to the list, Large stays at the floor with it). Text Size 1.3 follows the same rules as 1.0 in one column (no large-text cap there). Apple and Android take the same steps in the same order. When height runs short, the planner gives things up in this order and never shrinks the dial below the floor: tile growth, then spare gaps, then Small's map card (it shrinks to a map tile under the compact row, then the map moves to the header button), then Medium's grid and Large's 2 × 2 (they become the compact row, Medium's map in the header), then the lock and spot rows (they merge into one 44 row), and only then the scrolling list, which also keeps 0.40 H where the width allows. While a layout is giving way it may match its neighbour's grid. The golden tables and self-tests fail any portrait dial under 0.40 H. Accessibility text sizes and two-pane landscape are exempt.

**Shared steps:**
1. Pin the header at safe top + 8.
2. Place the fixed blocks with the frozen tokens from C3.2 #1.
3. Dial = min(cap, S − fixed).
4. Spend spare as in C3.2 #1: dial → map card → tile growth → (top and bottom each ≤ 24).

Both ports read `dial`, `grid`, `map`, `tile` and every gap from the plan and nowhere else.

**Shared tests:**
- The golden table, per device class (iPhone SE, iPhone 16 Pro, Pro Max, iPad mini, iPad 13", Mac 900 × 700, Android 360 × 640, 412 × 914, tablet), × layout × state (sample, live, no-compass), × text scale (1.0, 1.3, AX1).
- Adjacent layouts differ in grid mode and map surface.
- Row widths plus gaps equal C.
- Every gap is a token × k.
- Header top is safe + 8.
- Bottom spare ≤ 24.
- No tile is taller than its cap.
- In landscape, the four layouts produce four distinct plans.

### C3.4 Prioritized fix list (cycle 3 → cycle 4)

The instrument-panel structure and the four layouts stay; no lens gave a structural reason to drop either. Large changes its grid and map surface (C3.3), but it remains its own layout. Items are ranked by estimated composite gain. Platforms: **A** = Apple (iPhone, iPad, Mac), **D** = Android.

| # | Platform / screen | Before | After | Metrics (est. composite gain) |
|---|---|---|---|---|
| 1 | A and D planners (`LayoutPlan.swift:279/469/506–511`, `LayoutPlan.kt:235/294–319`) | Spare height widens gaps (`gapGrow`). Medium is derived differently on each port. Android Large/XL lock → spot about 27 dp vs 8. XL leaves a 60–110 pt foot | One rule set (C3.3). Frozen tokens × k. Spare goes dial → map card → tile growth → top/bottom ≤ 24 each. `gapGrow` deleted. Shared golden JSON | Spacing, Logic, Flow (+0.15) |
| 2 | A and D, Large on every device (iphone-7, android-8, ipad-7, mac-layout-large) | Same 3-column grid as Medium, dial +24, tiles 84 → 72 | 2 × 2 grid at (C − 8)/2 (Position, Elevation, Sun, Moon), Map moves to the header button, dial cap C − 16. Menu subtitles state the result. Golden test: grid mode and map surface differ between neighbours, dial(L) ≥ dial(M) + 16 | Logic, Flow (+0.10) |
| 3 | A and D, no compass and live without heading (iphone-4, -11, ipad-11, android-12, mac) | `_ °`: dash on the baseline, ring adrift. Separate `NO HEADING` line. About 90 pt dead band | Vector dash 0.5 em × 0.08 em at the cap-height midline, white 40%, `°` placed as in `228°`. `NO HEADING` folded into the status line. Freed height → dial, then a 160 map card. Render test (±4 pt), not a string test | Accuracy, Form, BP (+0.08) |
| 4 | A and D, header position and content (iphone-8 XL y≈170 vs 151, iphone-4 live 197; android-9/-2 at 175 vs 123) | Header top moves 20–50 pt between layouts and states. XL drops `, Colorado`. Sample pill in three positions | Pinned at safe top + 8 / status bar + 8 dp everywhere. Full place name always; shorten the date line first (`Sun, Nov 1` → `Nov 1`), then wrap the title. Sample pill always trails line 2 (13 pt semibold in a 20 pt capsule); only at AX sizes, line 1 trailing | Flow, Form, Accuracy (+0.06) |
| 5 | iPad landscape, all layouts (ipad-9, -12, -13) | Small = Medium. Tiles 190–530 pt tall with 2–3 lines at the top, Sun:Moon about 2:1. XL right pane half empty. Readout in the bottom-left corner, about 12 from the edge | Left pane: dial + readout, vertically centred, readout 12 below the dial, ≥ 24 bottom. Right pane: lock 52, spot 52, tile rows fixed 80 (Sun and Moon at (C − 8)/2), the rest goes to the map card (≥ 240). Small: map card ≥ 60% of the pane, compact row. Large: 2 × 2, map in header, pane stack centred vertically. XL: left pane 60% wide, compact row, stack centred. Add landscape to the tile-cap test | Spacing, Logic, Flow (+0.07) |
| 6 | A and D, large text and AX (iphone-5, -9, -12; android-6, -10, -13) | Dial stays about 380 pt / 360 dp. First screen ends mid-Position under the fade. iPhone large-text and AX1 render identically | At k ≥ 1.3: dial = min(C − 48, 0.36 H) (about 300 pt / 280 dp); in one portrait column this cap is dropped: the dials follow the 1.0 rules, never under the owner's floor, min(0.40 H, C − 16). Position and Elevation fully above the fold, which lands ≥ 24 below a whole block. At AX: lock + spot merge into one two-line "Targets" card, tiles become a 1-column list of 64 pt rows (caption leading, value trailing). Test: first tile row bottom ≤ H − safe, and the fade never crosses a value | Flow, BP, Accuracy (+0.07) |
| 7 | D lock row (android-3, -7, -8, -9, -13) vs A (iphone-2, mac-main) | D: neutral tile, `Locked 240° · turn 12° right` as one run, wraps to `turn 12° / right` at AX. A: maroon tint, split | One component on both: 52 pt / dp tall, fill #3D2128 (night: red at 15% luminance), 1 pt border #5A2C38. `Locked 240°` leading at 17 regular, `turn 12° right` trailing at 17 semibold, 12 min gap, non-breaking spaces inside values. ✕ 18 dp in a 48 dp IconButton at 4 trailing inset. At k ≥ 1.5 the cue drops to line 2 at 15. The spot row uses the same two-column rule on the neutral tile fill | Form, Logic, Flow (+0.05) |
| 8 | D map tile, card and sheet (android-3, -7, -8, -11, -12, live) | Cyan bold italic place labels (about #00E5FF), the most saturated element on screen. `Maroon Bells Amphitheatre` under the `3.2 mph` chip. Tile strip packs MAP pill + road shield + © OSM pill. (i) floats 40 dp from the attribution | Symbol layers: #C9D3D6 regular, not italic, 11–12 sp, 1.5 dp #0F3B3A halo, 70% opacity in the tile. POI labels hidden below 160 dp map height; road shields hidden below 200 dp wide. 48 dp collision padding around the speed chip and the control stack. Tile: one 24 dp bottom scrim band with `MAP` (11 sp caps, inset 10) and `© OSM` trailing at 10 sp. Card and sheet: `© OpenStreetMap ⓘ` in one pill bottom-leading at 8 dp, ⓘ with a 48 dp hit area. Night: red-tinted map at 35% luminance, not near-black | Form, BP (+0.05) |
| 9 | A map tile (iphone-2, -7, -11, ipad-2, mac-main) | 130 × 90 pt live map with Apple's `Legal` in the middle over the cone and lake. MAP caption covers the bottom third | Below 160 pt wide: a static `MKMapSnapshotter` image with the user dot, a 24 pt bottom scrim with `MAP` (11 pt caps) + a 12 pt expand glyph leading, and `Maps` attribution trailing at 9 pt. Tap opens the sheet, which carries full Legal. One accessibility element: "Map, opens full map" | Form, Flow, BP (+0.04) |
| 10 | iPad portrait, all layouts (ipad-2, -6, -7, -8) | Phone type ramp on a 1,024 pt canvas: about 9 pt captions and 17 pt values in 360–740 pt tiles. Side margin 92 (M) vs 36 (XL). Map thumbnail in Medium with room to spare | Regular-width ramp: header title 22 / sub 15, tile caption 13 caps, value 22 semibold tabular, secondary 15, readout 96, tile height 96, insets 14. Column min(W − 48, 720) centred, so the margin is the same in every layout. Medium promotes the map to a ≥ 200 card when ≥ 160 is spare | Form, Spacing, Logic (+0.04) |
| 11 | iPad no-compass (ipad-11) | Switches to a 2-column Sun/Moon row and a map card that no normal layout uses | Same grid as that layout's normal state. Freed readout height → dial, then the map card per C3.3 | Logic (+0.02) |
| 12 | Position tile (mac-layout-extraLarge-min; iphone-3-mgrs) | Mac XL-min: `39.09898° N` about 20 pt, `106.94117° W` about 16 pt (each line scaled on its own). MGRS: one line at the bottom of an 88 box with a 40 pt empty band | One shared size for the value block (compute the size from the longer line, or one `minimumScaleFactor` on the VStack inside `ViewThatFits`). One-line formats (MGRS, Plus Code) set the value at 20 pt, and the tile stays 72 (never grows) | Accuracy, Form (+0.03) |
| 13 | A and D, tile internals (Medium grid) | SUN carries a glyph and MOON does not, so captions start at different x and baselines shift 2–3 pt. Sun's value is about 7 pt higher than Moon's `53%`. The map caption is at the bottom, every other caption at the top | All captions text-only, 11 pt caps +0.6 tracking, inset 10 top/leading. The last baseline of every value block sits at inset 10 bottom (including MGRS and Moon). The map tile keeps its bottom scrim caption (#8, #9) as the one deliberate exception, because it labels an image | Form, Spacing (+0.03) |
| 14 | Phones, live / no-compass without a lock (iphone-4, -11, android-2, -12) | Three-line centred stack, then a 40–60 pt dead band before the spot row or tiles. Header pushed about 25 dp lower on D | The lock's 52 + 8 goes to the dial (up to its cap), then to a map card. Status → first row stays 8. Header pinned (#4) | Flow, Spacing (+0.03) |
| 15 | D night (android-5) | Sample pill red on red. Map tile nearly black | Night Sample pill: red outline, red text, black fill. Map per #8 | Form, Accuracy (+0.02) |
| 16 | D map sheet (android-11) | No grabber, covers the dimmed status bar | 32 × 4 dp grabber, status bar visible with `contentWindowInsets`, Done on the title baseline (as Apple) | BP, Form (+0.02) |
| 17 | Mac, all layouts (mac-main, mac-layout-*) | Header has 32 at the top, tiles about 16 from the bottom edge. Header inset changes in XL | Equal 24 pt insets on all four edges. Header pinned (#4). Mac in the golden table | Spacing (+0.02) |
| 18 | Terms (iphone-1, android-1) | Content in the top half, 170–300 pt empty band above the buttons. `Next, Bearings asks for your location.` floats alone | Content block centred in the space above the buttons (min safe top + 48). Note at 13 pt secondary, 16 above the primary button. Buttons 12 apart, 24 below the note, pinned to the bottom safe area + 16 | Spacing, Flow (+0.02) |
| 19 | Widgets vs app (widget-*) | Sentence-case captions (`Sun`, `Sunrise`). Sunrise/sunset glyphs vs the app's ↑ / ↓. Medium widget place wraps to 2 lines, pushing content to 12 from the bottom | App caption style (11 pt semibold caps, +0.6 tracking, secondary): SUN / RISE / SET with ↑ / ↓. Place on 1 line with scale 0.8. 16 pt content inset on all four edges | Form (+0.02) |
| 20 | A and D, scroll cue at large text | Fade only | Keep the 24 pt fade, flash the scroll indicator once on appear, and confirm the VoiceOver/TalkBack swipe scrolls into the cut tile | BP (+0.01) |

**Tests added this cycle (both ports, one shared golden JSON):**
- Gap tokens × k.
- Header top is safe + 8.
- Bottom spare ≤ 24.
- Tile ≤ cap, in portrait and landscape.
- Adjacent layouts differ in grid mode and map surface, in portrait and landscape.
- Rendered no-heading dash centre within ±4 pt of the digit centre-line.
- Both Position lines at the same point size.
- At k ≥ 1.3, Position and Elevation fully above the fold.
- Lock row: label and cue never split within a value.
- Android map label colour and italics checked against the style JSON.

### C3.5 Projection

Items 1–3 are the frozen rhythm with one planner, a distinct Large, and the dash. Fixing them should lift Spacing to about 4.0, Logic to 4.2 and Accuracy to 4.2, for a composite of about 4.1. Items 4–9 add header stability, iPad landscape, large text, port parity on the lock row and maps, and the Apple map tile. They take Flow and Form to about 4.3 and the composite to about **4.3–4.35** after cycle 4.

Reaching 4.85 needs every cell of the golden table (device × layout × state × text scale × orientation) re-shot and judged, with:
- no rhythm exceptions;
- identical components on both ports;
- iPad with its own type ramp;
- widgets in the app's caption language.

Expect two more cycles. The remaining risk is structural: if the four layouts still look alike to the owner after the C3.3 Large rule, the panel recommends a menu preview (a thumbnail of each plan) rather than a fifth rule.

## Cycle 4

Cycle 4 scores the screens rebuilt after the cycle-3 fix list (C3.4), with the owner's hard rule now in force: **the dial is at least 40% of the screen height in portrait, in every layout.** Nothing below breaks that rule. Four lenses scored independently; the table gives their mean.

### C4.1 Scorecard

| Metric (weight) | L1 | L2 | L3 | L4 | **Mean** | Δ vs cycle 3 | Confidence | Why, and what the next half-point needs |
|---|---|---|---|---|---|---|---|---|
| Best Practices (16.25%) | 3.9 | 3.7 | 3.9 | 3.8 | **3.8** (3.825) | −0.08 | Medium | Pinned header, full-bleed sheets with Done, 44 pt / 48 dp targets and a real night mode all hold. Costs: Android map controls are clipped by their own card, large-text rows run under the Android gesture bar, header buttons mix three styles on Android, and iPad still uses the phone type ramp. |
| Accuracy (16.25%) | 3.8 | 3.6 | 3.6 | 3.6 | **3.7** (3.65) | −0.20 | High | Values and units are right. But the no-heading readout still draws as `_  °` on every port for a fourth cycle, the Android map sheet renders place labels as solid white bars, large text breaks `6:36 / AM`, and the half-width spot chip drops its `Marked spot` label. All three render tests pass on pixels that are wrong. |
| Logic (16.25%) | 3.5 | 3.4 | 3.4 | 3.6 | **3.5** (3.475) | −0.28 | High | Android, Mac and iPad show four distinct plans. On iPhone, the default sample state (lock + spot) renders Small, Medium, Large and XL as one plan: compact row, map in the header, only the dial changes. Small (`Compass + big map`) has no map, and Moon shrinks to `◐ 53%`. |
| Flow (16.25%) | 3.9 | 3.9 | 3.9 | 3.9 | **3.9** | −0.08 | Medium | Header → dial → `228° SW` → status → lock → spot → tiles scans cleanly on phones and Mac. It breaks in no-compass (a 60–120 pt dead band around the broken dash), at large text (rows end under the gesture bar, Sun wraps word by word) and in iPad landscape (right stack floats mid-pane). |
| Spacing (20%) | 3.5 | 3.6 | 3.5 | 3.4 | **3.5** | 0.00 | High | The gap tokens hold on phones and the compact row sums to C. Dead bands remain (iPhone sample foot 58–80 pt, Android XL foot about 60 dp, iPad landscape 200+ pt above and below the stack), and there is real clipping: Android Small map controls, the iOS large-text Sun tile overhanging the gutter, and Android rows under the nav bar. |
| Form (15%) | 3.8 | 3.7 | 3.7 | 3.6 | **3.7** | −0.10 | Medium | Palette, dial, maroon lock row, tile component, night mode and widgets are coherent. The dash glyph looks broken, the lock/spot half-chips wrap `Locked 240° · / turn 12° right`, Android header buttons mix bare and filled styles, and iPad sets 13–17 pt type in 700–1,200 pt rows. |
| **Composite** | | | | | **3.67** | **−0.11** (3.78 → 3.67) | | Target 4.85; gap 1.18. |

The composite uses the unrounded means: 0.1625 × (3.825 + 3.650 + 3.475 + 3.900) + 0.20 × 3.500 + 0.15 × 3.700 = 2.413 + 0.700 + 0.555 = **3.67**.

**Dissent (spread of 0.5 or more): none.** The widest spreads are 0.2:
- **Best Practices (3.9 to 3.7).** L2 weighted the broken Android map labels and clipped map controls as shipping defects. L1 and L3 credited the sheets and AX list.
- **Accuracy (3.8 to 3.6).** L1 counted only the dash. L2–L4 also counted the white-bar map labels, the split times and the dropped spot label.
- **Logic (3.6 to 3.4).** All four saw the same iPhone collapse. L4 gave more credit for Android, Mac and iPad having four distinct plans.
- **Spacing (3.6 to 3.4).** L4 treated the clipping (Android Small map, iOS Sun tile, Android nav bar) as spacing failures. L2 scored them under Best Practices.
- **Form (3.8 to 3.6).** Same split on the header button styles and the large-text Sun tile.

Flow is unanimous at 3.9. The panel agrees on the defects and differs only in which metric each one costs.

**Why the score fell.** This is the first cycle where the composite went down. There are three causes.

1. **The 40% rule collides with the target rows.** On iPhone 16 Pro (874 pt) in the sample state, the dial now takes at least 350 pt. The planner's pressure order then gives up the map card, the 3-column grid and the 2 × 2 grid before it touches the two 58 pt full-width lock and spot rows. As a result, all four layouts land on `compact row + map in header` (dial 341–386; Large = XL). This is the screen every reviewer sees first, so Logic took the biggest drop (−0.28). The rule itself is right. What needs to change is the pressure order (C4.3 #1).
2. **Three render tests pass on wrong pixels.** They cover the no-heading dash, the Android map labels and the iOS large-text tile bounds. The C3.4 tests check strings, style JSON or layout frames, not the drawn bitmap. Accuracy fell 0.20 because the lenses now treat a fourth-cycle `_ °` as a known-broken glyph, not a polish item.
3. **New screens were in scope.** These were the Android map sheet, the AX sizes and the no-compass dial centre. They exposed defects that cycle 3 had not seen.

**What landed from C3.4:**
- the gap tokens on phones;
- the compact row summing to C;
- four distinct plans on Android, Mac and iPad portrait;
- the maroon lock row on both ports;
- the full place name in the title;
- night mode on all ports.

**What did not land, or landed partly:**
- C3.4 #1 (no spare in gaps; bottom spare ≤ 24): iPhone sample feet are still 58–80 pt.
- #2 (a distinct Large): it holds on Android, but iPhone sample collapses.
- #3 (the dash): `_ °` everywhere.
- iPad landscape: the stack is still centred, not top-aligned.
- Android large text: tiles wrap and run under the nav bar.

### C4.2 Top 3 weaknesses (ranked by impact on the composite)

**1. On iPhone, the four layouts collapse into one in the default sample state (lock + spot).** This costs about 0.15 of composite (Logic, Flow, Spacing). All four lenses raised it, and it is the owner's core complaint.
- *Before (iPhone 16 Pro, 402 × 874, sample, lock + spot):* every layout is header (map button) → dial → readout → status → Locked row 58 → Spot row 58 → compact row (Position | Elevation | `SUN · ◐ 53%`). The dial is 341 / 361 / 377 / 377 (lens readings range 341–386). Small has no map. Medium has no 3-column grid or map tile. Large = XL. The foot is a 58–80 pt dead band.
- *After:* when a lock and a spot both exist, they always render as **one Targets card, 60 tall**, before any grid or map surface is given up:
  - Two 28 pt lines with a hairline (1 px, white 12%) between them, 12 insets.
  - Line 1: `LOCKED 240°` (11 pt caps caption run-in) + `turn 12° right` (17 semibold), ✕ trailing in a 44 pt target.
  - Line 2: `SPOT` + `9.2 mi · 46° NE`, ✕ trailing.
  - Labels never drop. On Mac XL-min and at large text, the card stays full width and stacks; it never splits into side-by-side half-chips.

  This frees 116 + 8 − 60 = **64 pt**. Add the 58–80 pt foot, and the plans become:

  | Layout | Dial | Below the Targets card | Map surface |
  |---|---|---|---|
  | Small | 350 (0.40 H) | compact row 72 | map card ≥ 140 |
  | Medium | ≈ 360 | 3-column grid (Position · Elevation · Sun / Moon · Map tile at 72) | Map tile |
  | Large | 370 | 2 × 2 at 72 | map in header |
  | XL | C (≥ 378) | compact row, readout × 1.25 | map in header |

  In the pressure order on both ports, *merge target rows* moves to step 1, ahead of *map card → tile*, *grid → compact row* and *map → header*.
- *Test:* golden cases for iPhone SE, 16 and 16 Pro, and Pixel 8, in the sample state with lock + spot. Assert that adjacent layouts differ in (grid mode, map surface); that Small has a map card ≥ 140; that dial(L) ≥ dial(M) + 10 and dial(XL) > dial(L); that every dial is ≥ 0.40 H; and that the bottom spare is ≤ 24.

**2. The no-heading readout still draws as `_  °` on every port, and its test passes.** This costs about 0.08 (Accuracy, Form, Flow). All four lenses raised it, for the fourth cycle.
- *Before:* a 28 pt dash on or near the baseline, with the degree ring floating 25–100 pt to the right and 10–25 pt above it (iphone-4/-11/-14, ipad-11/-14/-16, android-12/-14, mac-nocompass). A 60–120 pt dead band follows before the status line.
- *After:* replace the composed glyphs with words. The readout is **`No heading`**, 34 pt semibold, white 55% (night: night-red 55%), centred 12 below the dial. The status line `Position, sun and map still work` sits 6 below it, at 15 pt. There is no degree ring and no dash. The height freed (the readout drops from the 56–96 pt digit box to a 41 pt line) goes to the map surface: a map card ≥ 140 on Small and Medium, tile growth elsewhere. If a numeric placeholder is ever required, it must be a single `Text("––°")` in the same font run as `228°` (tabular figures, no separate layers).
- *Test:* a bitmap snapshot of the no-compass readout on every port. Assert that the readout's text layer equals `No heading`, that no glyph sits outside the line box, and that the gap from the readout to the status line is 6 ± 2 pt.

**3. Large text 1.3× overflows, wraps inside values and runs under the system bars.** This costs about 0.07 (Spacing, Form, Best Practices, Flow).
- *Before:*
  - iPhone (iphone-5, -9): the Sun tile is about 17 pt taller than its neighbours, its top sits 6–10 pt higher, and it overhangs the right gutter by 6–12 pt.
  - Android (android-6, -10): Sun wraps into six lines (`SUN · ◐` / `53%` / `↑ 6:36` / `AM` / `↓ 5:08` / `PM`), and Position and Elevation bottom-align their values under 80–100 dp empty bands.
  - Android: the row runs under the gesture bar.
  - Both: the lock and spot chips wrap `Locked 240° ·` / `turn 12° right`, and the spot chip loses its label.
- *After:* at k ≥ 1.3, the compact row becomes **two rows on both ports**:
  - Row 1: Position at full width C, 64 tall, with both lines at one shared size.
  - Row 2: Elevation | Sun at (C − 8)/2 ≈ 181.

  Inside the tiles:
  - Values are top-aligned 6 below the caption, and every tile in a row is equal to the tallest.
  - Times use a non-breaking space (`6:36 AM`), shrink to 0.85 before wrapping, and then drop AM/PM in 24 h locales.
  - The Sun caption is `SUN` only. Moon moves to its own tile when there is room, or to the header sub-line (`Nov 1 · 9:41 AM · ◐ Last qtr`).

  The Targets card from #1 stays full width. Android bottom padding is `WindowInsets.navigationBars` + 16 dp, and the column scrolls instead of running under the bar.
- *Test:* at k = 1.0, 1.3 and 2.0, every tile frame lies inside C; tiles in a row share minY and maxY; no line breaks inside a time; and the last row's bottom is ≤ H − safe-bottom − 16.

### C4.3 Prioritized fix list (cycle 4 → cycle 5)

The list is ranked by estimated composite impact. All sizes are in pt (Apple) and dp (Android), with the same numbers on both ports unless noted. Every item keeps the dial at ≥ 0.40 H in portrait.

| # | Platform / screen | Before → after | Metrics (≈ composite) |
|---|---|---|---|
| 1 | **iPhone (SE, 16, 16 Pro), sample, lock + spot; Android parity; Mac XL-min** | Four layouts render one plan (compact row + map in header, dial 341–386, Large = XL, Small with no map, 58–80 pt foot). Mac XL-min splits into wrapped half-chips. → One full-width **Targets card, 60 tall**, two 28 pt lines with a hairline, never split and never label-less, merged first in the pressure order on both ports. Small = dial 350 + compact row + map card ≥ 140. Medium = dial ≈ 360 + 3-column grid + Moon + Map tile 72. Large = dial 370 + 2 × 2 at 72 + map in header. XL = dial C + compact row + readout × 1.25. Golden distinctness test in the lock + spot state. | Logic +0.4, Flow +0.1, Spacing +0.05 (≈ +0.15) |
| 2 | **No-compass / no-heading readout, all ports** (iphone-4/-11/-14, ipad-11/-14/-16, android-12/-14, mac-nocompass) | `_  °`, with the ring 25–100 pt off and a 60–120 pt dead band → the text `No heading`, 34 semibold, white 55%, 12 below the dial. Status 6 below at 15 pt. Freed height goes to the map card or tiles. Bitmap snapshot test replaces the string test. | Accuracy +0.15, Form +0.1, Flow +0.05 (≈ +0.08) |
| 3 | **Large text 1.3×, iPhone + Android** (iphone-5/-9, android-6/-10) | Sun tile overhangs the gutter by 6–12 pt and is 17 pt taller; `6:36 / AM` wraps; values bottom-align under 80–100 dp gaps; rows run under the gesture bar → two-row compact layout (Position full width 64; Elevation \| Sun at (C − 8)/2). Values top-aligned, 6 below the caption. Rows equal-height. Non-breaking times at 0.85 min scale. Caption `SUN` only. Nav-bar inset + 16 and a scrolling column. | Spacing +0.15, Form +0.1, BP +0.1, Flow +0.1 (≈ +0.07) |
| 4 | **Android map sheet** (android-11) and every Android map with symbol labels | Place labels draw as solid white rectangles (missing glyphs). The area above the sheet is pure black → bundle glyph PBF ranges 0–255 and 256–511 for the exact `text-font` stack (`Noto Sans Regular`) in the APK, with `glyphs` pointing at the asset URI. Labels #C9D3D6, 12 sp, 1.5 dp #0F3B3A halo. Hide symbol layers if the glyphs fail to load. 40% black scrim above the sheet. Pixel test: no label bbox more than 80% solid fill. | Accuracy +0.1, Form +0.1, BP +0.05 (≈ +0.05) |
| 5 | **Spare height, all ports** (iPhone sample foot 58–80; Android XL foot about 60; iPad portrait about 40; iPhone header → dial 25–35 vs 12) | Spare pools at the foot or splits around a centred stack → header → dial fixed at 12 ± 2. Spare is spent in order: map card (Small, Medium) → dial up to its cap → tiles 72 → 88. Foot ≤ 24. Rendered checks on every golden screenshot. | Spacing +0.15, Flow +0.05 (≈ +0.04) |
| 6 | **iPad landscape** (ipad-9, -12, -13, -15) and **Mac wide** (mac-wide-large) | Readout 12–20 pt from the bottom edge. Right stack vertically centred with 200–330 pt empty above and below. Tiles 170–400 pt tall holding 2 lines. Small and Medium look alike → two panes, 24 outer / 32 inner gutters. Left: dial + readout + status as one group, vertically centred below the header, readout 12 under the dial, ≥ 32 to the bottom. Right: **top-aligned** to the dial top, Targets card 60, tile rows fixed at 96, remaining height to a map card ≥ 240 (Small: map ≥ 60% of the pane; Medium: 3-column + map tile above the card; Large: 2 × 2 + card; XL: left pane 60% wide, compact row + card). Test: right-pane bottom spare ≤ 24. | Spacing +0.15, Flow +0.1, Logic +0.1 (≈ +0.04) |
| 7 | **iPad portrait and landscape, all layouts; iPad terms** | Phone ramp on a 1,024+ pt canvas: status about 9–10 pt, captions 9–13 pt, 13–17 pt target text in 700–1,200 pt rows (`Locked 240°` about 900 pt from `turn 12° right`) → regular-width ramp. Header title 22 / sub 15. Status 15, 12 below the digits' baseline. Targets card 2 × 32 at 17–20 pt. Tile caption 13 caps, value 24 semibold tabular, secondary 15, tile 96, insets 16. Readout 96–104. Readout, Targets and tiles sit in a centred column of min(W − 48, 720); the dial may stay wider. Terms: centred 480 column, body 17. | Form +0.15, BP +0.1, Flow +0.05 (≈ +0.04) |
| 8 | **Android map card under 200 dp** (android-7 Small, any short card on Android or iPad) | The 76–160 dp card carries +, −, follow and ⋯ (192 dp of controls): − is cut in half, ⋯ is clipped, and the attribution collides with the speed chip → cards under 200 show only the speed chip (top-leading, 8 inset) and one 40 dp expand button (top-trailing, 8 inset, 48 hit area). Zoom, follow and overflow live in the sheet. Attribution is `© OSM ⓘ`, 10 sp, bottom-leading at 8. Minimum card height 140, else fall back to a 72 map tile. Test: every control's frame lies inside the card. | BP +0.1, Spacing +0.1 (≈ +0.03) |
| 9 | **Sun / Moon tile, all phones** (iphone-2, android-3/-9) | `SUN · ◐ 53%` overloads an 11 pt caption, drops the phase name, and wraps at 1.3× → Sun tile caption `SUN`, values `↑ 6:36 AM` / `↓ 5:08 PM`. Moon gets its own tile in Medium and Large (`MOON`, `◐ Last quarter`, `53%`). In compact-row layouts, the Moon goes to the header sub-line (`Nov 1 · 9:41 AM · ◐ Last qtr`) and stays on the dial as a marker. | Accuracy +0.1, Logic +0.05, Form +0.05 (≈ +0.03) |
| 10 | **Header bar, both ports** (android-3/-5/-8/-9/-10/-14 vs Apple) | Android: sun is a bare glyph, while map and ⋯ sit in filled 48 dp circles (a red blob at night). Apple: bare glyphs, with the map slot only in Large/XL. At large text the title wraps with the Sample pill floating between the lines → one style on both ports: three 44 / 48 targets, 24 glyph, no container fill, 4 apart, trailing inset 8, fixed order (night, map, ⋯), map slot always reserved (hidden with opacity, not removed, when a map tile or card is on screen). Night: glyphs in night-red, no fills. Sample pill trails line 2 in every layout. At k ≥ 1.3 the title stays on one line (`Maroon Bells, CO`), with the full name in the accessibility label. | Form +0.05, BP +0.05, Spacing +0.03 (≈ +0.02) |
| 11 | **Accessibility sizes** (iphone-12-ax1, android-13-ax-text) | The dial shrinks to about 27% (iPhone) and about 18% (Android) of H, breaking the owner's 40% rule → at k ≥ 1.5, the dial stays at max(0.40 H, the Medium dial) and the readout scales with Dynamic Type. Everything below the readout scrolls, with a 24 pt fade. VoiceOver / TalkBack read the heading as one element: `Heading 228 degrees southwest, locked 240, turn 12 right`. Extend the 40%-rule test to k = 1.5, 2.0 and 3.1. | BP +0.05, Logic +0.05 (≈ +0.02) |
| 12 | **No-compass dial centre, both ports** (android-12/-14; Apple `location.slash`) | A crossed-out location pin suggests location is broken while position works → a compass-unavailable glyph: Material `explore_off` / SF `safari` with a slash overlay, 24, white 40%. Accessibility label: `Compass unavailable; north is fixed up`. | Accuracy +0.05 (≈ +0.01) |
| 13 | **Night map surfaces** (android-5 map tile, mac-night) | The map tile goes almost black with a faint glyph and reads as empty → a red monochrome map at about 35% luminance (roads and water at 30–45%), user dot in full night-red. Keep the 24 pt scrim caption. | Form +0.05, Accuracy +0.05 (≈ +0.01) |
| 14 | **Terms** (iphone-1, android-1, ipad-1) | Block in the top 59%, a 250–300 pt empty band, then a centred note above the buttons → icon + title + bullets + legal block vertically centred in the area above the buttons (≥ safe top + 48). The note is left-aligned with the bullets, 13 pt secondary, 16 above the primary button. Buttons pinned to safe bottom + 16. iPad: see #7. | Spacing +0.05, Flow +0.03 (≈ +0.01) |
| 15 | **Apple widgets** (widget-medium, widget-large) | Medium: left and right columns start on different baselines, and the moon line floats. Large: 9–10 pt captions, a 30 pt mini-compass, a 9 pt footer, and a sun azimuth the app never shows → one 16 inset on all edges, with caption baselines aligned at the top (`Aspen, Colorado` with `SUN  RISE  SET`) and the moon line on the baseline of `11:03 AM`. Large: elevation 34, map 45% of height, one Sun row at 13 pt (`SUN ↑ 6:43 AM ↓ 5:02 PM`), footer 12. Either add `166° SSE · 33° up` as the app's Sun tile secondary line in Large and XL, or drop it from the widget (panel prefers adding it to the app). | Form +0.03, Logic +0.02 (≈ +0.01) |

**Tests to add (both ports, CI):**
- Golden distinctness in the **lock + spot** sample state on iPhone SE, 16 and 16 Pro, and Pixel 8: adjacent layouts differ in (grid, map surface); Small has a map card ≥ 140; dial ≥ 0.40 H.
- Bitmap, not string, checks for the no-heading readout and the Android map labels.
- At k = 1.0, 1.3 and 2.0: tile frames inside C; equal minY and maxY per row; no break inside a time; last row ≥ 16 above the safe bottom.
- Bottom spare ≤ 24 and header → dial = 12 ± 2 in every portrait golden; right-pane spare ≤ 24 in landscape.
- Map controls inside the card bounds.
- The 40% rule at k = 1.5, 2.0 and 3.1.

### C4.4 Projection

Items 1–3 fix the collapse of the four iPhone layouts, the dash and large text. They should lift Logic to about 4.1, Accuracy to about 4.1 and Spacing to about 3.9, for a composite of about **3.98**. Items 4–8 fix the Android map labels, spare height, iPad landscape, the iPad ramp and map controls. They take BP, Flow and Form to about 4.2 and the composite to about **4.2–4.25** after cycle 5.

The cycle-4 regression has one lesson: **every fix must ship with a bitmap test in the state reviewers actually see** (sample, lock + spot, k = 1.3, no-compass). Three C3.4 items passed their tests and still failed on screen.

Reaching 4.85 still needs:
- the whole golden table re-shot and judged;
- identical header, Targets card and tile components on both ports;
- iPad with its own ramp;
- widgets in the app's caption language.

Expect at least two more cycles. If the iPhone layouts still read alike to the owner once #1 lands, the panel's fallback is unchanged from cycle 3: a thumbnail preview of each plan in the layout menu.

### C4.x Owner's decision for cycle 5

The composite fell 3.78 → 3.67. The owner chose: **keep the compass at ≥ 40% of H, new strategy**.
Cycle 5 applies, in this priority:
1. **Targets card first.** When both a lock and a spot are active, merge them into one stacked
   "Targets" card (two 28 pt lines, hairline between) *before* any layout gives up its grid or map
   surface, on both ports. Golden test: on iPhone 16 / 16 Pro, sample (lock + spot), the four layouts
   differ in grid mode and map surface, and every dial ≥ 0.40 H.
2. **"No heading" readout.** Replace the composed dash and ring with the words "No heading" (34 pt
   semibold, white 55 %), 12 below the dial, status line 6 below. Test the rendered bounding boxes.
3. **Large text (k ≥ 1.3):** the compact row becomes two rows (Position full width; Elevation | Sun),
   Moon as a line in the Sun tile, non-breaking spaces inside times, no half-width chips, last row above
   the safe bottom.
4. Spare height to content (map card, tile growth; iPad landscape right pane top-aligned with a map
   card), then the iPad regular-width type ramp, then the rest of the C4 list.
