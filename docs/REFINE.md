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
