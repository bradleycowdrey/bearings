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

**Owner's rule: dial ≥ 40% of H.** "The compass takes up at least 40% of the screen" is a hard rule, and it overrides every floor above. In one column (phones, iPad portrait, Mac windows taller than wide), at Text Size 1.0 to 1.3, every layout's dial is at least min(0.40 H, C − 16) (C the column; 8 from each edge), with H the full screen or window height. Small sits at that floor; Medium is at or over it; Large is over Medium (16 over where the height allows); Extra Large is the largest. When height runs short, the planner gives things up in this order and never shrinks the dial below the floor: tile growth, then spare gaps, then Small's map card (it shrinks to a map tile under the compact row, then the map moves to the header button), then Medium's grid and Large's 2 × 2 (they become the compact row, Medium's map in the header), then the lock and spot rows (they merge into one 44 row), and only then the scrolling list, which also keeps 0.40 H where the width allows. While a layout is giving way it may match its neighbour's grid. The golden tables and self-tests fail any portrait dial under 0.40 H. Accessibility text sizes and two-pane landscape are exempt.

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
| 6 | A and D, large text and AX (iphone-5, -9, -12; android-6, -10, -13) | Dial stays about 380 pt / 360 dp. First screen ends mid-Position under the fade. iPhone large-text and AX1 render identically | At k ≥ 1.3: dial = min(C − 48, 0.36 H) (about 300 pt / 280 dp); in one portrait column now lifted to the owner's floor, min(0.40 H, C − 16). Position and Elevation fully above the fold, which lands ≥ 24 below a whole block. At AX: lock + spot merge into one two-line "Targets" card, tiles become a 1-column list of 64 pt rows (caption leading, value trailing). Test: first tile row bottom ≤ H − safe, and the fade never crosses a value | Flow, BP, Accuracy (+0.07) |
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
