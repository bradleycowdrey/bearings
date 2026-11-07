# Bearings: layouts (the "Instrument panel")

Status: the layout spec for Apple (SwiftUI, iOS 17 / macOS 14) and Android (Compose). It follows
[REFINE.md](REFINE.md) §3–§4 (Rate & Refine, cycle 1), which wins wherever the two differ. Colours, type and
tokens stay in [LOOK.md](LOOK.md); features and wording in [DESIGN.md](DESIGN.md). The dial drawing, the
colours, the night palette and the widgets do not change.

The owner's brief: **the compass stays large and is the hero; the other tiles are needed, each fact
shown once, nothing cut off and no empty space; four layouts, Small, Medium, Large and Extra Large.**

---

## 1. The structure

**One fixed, non-scrolling screen** (at normal text sizes), top to bottom:

**header bar → dial → readout → status line (and lock chip) → spot row → tile grid → map card (only where
it fits whole).**

- Every fact appears **once**. The old summary strip, the DETAILS tiles, the "Bearings" title row, the sky
  card and the sky bar are gone.
- The map is **whole or a tile**, never a sliver: a Map tile in the grid, a full-width map card, or a map
  button in the header. All three open the same **map sheet**. There is no bottom fade.
- The planner works **bottom-up**: the fixed blocks are placed first, the dial takes what is left up to
  its cap, and spare height becomes a map card, taller tiles and wider gaps. **No more than 24 is ever left
  empty at the bottom.**
- The only scrolling screen is the accessibility-text list (§7).

---

## 2. The elements (Apple pt, Android dp; same numbers)

| Element | Size and content |
|---|---|
| **Header bar** | 48 high (52 on iPad) × k, radius 14, full column width, the existing sky gradient. Line 1: the place, 17 semibold (the state is dropped first, then it truncates). Line 2: "Sun, Nov 1 · 9:41 AM", 13 at white 75%, and the **Sample** pill. Trailing, fixed on every layout: the sky symbol (20, decorative), the **map button** (only when the map is neither a tile nor a card), then **⋯** (44×44 pt / 48×48 dp, 8 apart). ⋯ never moves. |
| **Dial** | Unchanged drawing. Centred, side margin e (§4). |
| **Readout** | "228° SW". Line height 1.1 × the heading size; heading 56 (64 on iPad) × the layout's readout scale. |
| **Status line** | 13, white 60%, one centred line: "True north · 8° E declination · ±8° accuracy". Amber warnings take the same slot. Wraps to 2 lines only at k > 1.1, at a "·". |
| **Lock chip** | Only when a bearing is locked: a 28-high capsule 8 below the status line, accent at 20% (night 25%), `lock.fill` 13, "Locked 240° · turn 12° right" 13 semibold, trailing ✕ (44×44 hit area) unlocks. |
| **Spot row** | Only when a spot is marked: a full-width tile, 44 high, 8 above the grid, leading-aligned. Pin 17, "Marked spot" 15 medium, "9.2 mi · 46° NE" 15 tabular, ✕ 8 after the text (44 / 48 dp target). Tap: Lock to Spot, Clear Marked Spot. |
| **Tile grid** | 3 columns, unit u = (C − 16) / 3, gutters 8. **Full:** POSITION (2u) \| ELEVATION, then SUN \| MOON \| MAP. **Compact row:** POSITION (2u) \| ELEVATION \| SUN (Moon stays on the dial and in the Details sheet). Tiles 72 high, growing to 88 when height is spare; rows 8 apart. |
| **Map card** | Full column width, height = the spare height (at least 140), radius 16. One control cluster on every layout: 36 circles (44 / 48 dp hit areas), 8 apart, inset 12 top-trailing (+, −, follow heading, open in Maps); speed chip inset 12 top-leading; 24 clear at the bottom for the attribution. |
| **Map sheet** | Full height (`.large` + grabber + Done; Android `skipPartiallyExpanded`), the same cluster and chip. |
| **Details sheet** | iOS `.sheet` with `[.medium, .large]` and a grabber; Android `ModalBottomSheet`. Accuracy, fix age, format name, pressure, moon phase name, rise and set azimuths, as a grouped list. |

**The tile** (one component on both platforms, matching the widgets): `frostedTile()` / `surfaceContainer`,
radius 16 continuous, padding 12 × 10, leading-aligned. Caption 11 semibold caps, tracking 0.6, white 60%;
value 17 medium tabular, white; secondary 13, white 60%. The tokens live in one `Look` constant shared
with the widgets (which keep 10 pt captions).

| Tile | Caption | Value | Secondary | Tap / long-press |
|---|---|---|---|---|
| Position (2u) | `POSITION · DD` (DD, DMS, DDM, UTM, MGRS, PLUS) | "39.09898° N" over "106.94117° W" | dims when the fix is stale | Tap: next format. Long-press: Copy, Details… |
| Elevation | `ELEVATION` | "9,587 ft" | "2,922 m" (order follows Units) | Details sheet |
| Sun | `SUN` | "↑ 6:36 AM" over "↓ 5:08 PM" (12/24-hour from the locale) | polar: "Up all day" / "Down all day" | Details sheet |
| Moon | `MOON` | phase glyph + "53%" | "Last quarter" | Details sheet |
| Map | `MAP` on a 40% black scrim | live thumbnail, north-up, heading cone, no controls or gestures, attribution visible | — | Map sheet |

**Values never ellipsize:** text scales down to 0.85×, then wraps; a tile grows taller before anything
truncates. Before the first fix tiles show "—" with "Finding position…".

---

## 3. The planner

`LayoutPlan.swift` (`Sources/Bearings/Views/`) and `ui/LayoutPlan.kt`: one pure function, the same
constants and order, no UI code.

**Gaps** (tokens 4 / 8 / 12 / 16 / 24 only): safe-area top → header 4 · header → dial 12 · dial → readout
12 · readout → status 6 · status → lock chip 8 · readout group → spot row or grid 16 · spot row → grid and
between rows 8 · grid → map card 12 · last block → safe-area bottom 8. Side margins 16 (20 on iPad).
Column **C = min(W − 2 × margin, 640)**.

With **S** the safe height and **H** the full height:

1. Place the fixed blocks: header, readout group, lock chip (if locked), spot row (if marked), and the
   grid in the layout's default mode.
2. **Dial = min(cap, S − fixed)**; cap = C + 2 × margin − 2e on phones (the screen width less the
   layout's margins), and also ≤ 0.48 H on tablets.
3. If the dial falls below the layout's **floor**: (a) Large: the grid collapses to the compact row and
   Map moves to the header button; (b) Small: the map card shrinks toward 140, then the dial goes down to
   its floor; (c) otherwise the screen becomes the scrolling list (§7).
4. Spare height (the dial at its cap): (a) 160 or more → the map becomes a full-width card filling it;
   (b) otherwise the tiles grow 72 → 88; (c) then up to +12 on each of three gaps (header → dial, dial →
   readout, readout group → grid); (d) the rest is split above the header and below the grid, **never more
   than 24 at the bottom** (nor above the header); anything still left widens the three gaps further.

Output: two panes or one column, dial, floor, readout scale, grid (full, compact, list), map (tile, card,
button) and its height, tile height, the three gaps, top and bottom spare, and the trailing pane's width.

---

## 4. The four layouts

| | **Small**: "Compass and map" | **Medium** (default): "Balanced" | **Large**: "Bigger compass" | **Extra Large**: "Biggest compass" |
|---|---|---|---|---|
| Dial | 0.36 H; floor 0.30 H, so the map card keeps 140 | fills to the cap (e = 16); floor 0.38 H | e = 12; floor 0.42 H | e = 8; floor 0.42 H |
| Readout scale | 1.0 | 1.0 | 1.08 | 1.15 |
| Grid | compact row | full grid with the Map tile | full grid; compact row before the dial shrinks | compact row |
| Map | full-width card filling the rest (≥ 140) | tile; a card when 160 or more is spare | tile, or the header button when the grid collapses | the header map button; a card when 160 or more is spare |

### 4.1 Planner results by device

From the planner at the default text size. Each cell: **dial · grid · map · empty at the bottom** (grid:
"grid" = full, "row" = compact; "list" = the scrolling list). Safe heights are the usual insets (Pixel 7:
915 − 52 − 24 = 839 dp).

**Nothing locked or marked:**

| Device (W×H) | Small | **Medium** | Large | Extra Large |
|---|---|---|---|---|
| iPhone SE (375×667) | 239 · row · card 140 · 0 | **311 · grid · tile · 0** | 306 · grid · tile · 0 | 359 · row · button · 0 |
| iPhone 16 (393×852) | 307 · row · card 185 · 0 | **361 · grid · tile · 0** | 369 · grid · tile · 0 | 377 · row · button · 24 |
| iPhone 16 Pro (402×874) | 315 · row · card 196 · 0 | **370 · grid · tile · 2** | 378 · grid · tile · 0 | 386 · row · button · 24 |
| iPhone 17 Pro Max (440×956) | 344 · row · card 250 · 0 | **408 · grid · tile · 24** | 416 · grid · tile · 19 | 424 · row · card 161 · 0 |
| Pixel 7 (412×915 dp) | 329 · row · card 242 · 0 | **380 · grid · tile · 24** | 388 · grid · tile · 21 | 396 · row · card 166 · 0 |
| Mac window (420×840) | 302 · row · card 270 · 0 | **388 · grid · tile · 24** | 396 · grid · tile · 18 | 404 · row · card 159 · 0 |
| Mac minimum (380×720) | 259 · row · card 193 · 0 | **348 · grid · tile · 0** | 356 · grid · tile · 0 | 364 · row · button · 20 |
| iPad 11" portrait (834×1210) | 436 · row · card 450 · 0 | **581 · grid · card 225 · 0** | 581 · grid · card 219 · 0 | 581 · row · card 294 · 0 |
| iPad 13" portrait (1032×1376) | 495 · row · card 556 · 0 | **648 · grid · card 324 · 0** | 656 · grid · card 310 · 0 | 660 · row · card 381 · 0 |

**Locked and marked (the sample):**

| Device (W×H) | Small | **Medium** | Large | Extra Large |
|---|---|---|---|---|
| iPhone SE (375×667) | list | **list** | 298 · row · button · 0 | 294 · row · button · 0 |
| iPhone 16 (393×852) | 263 · row · card 140 · 0 | **335 · grid · tile · 0** | 369 · row · button · 0 | 377 · row · button · 0 |
| iPhone 16 Pro (402×874) | 282 · row · card 140 · 0 | **354 · grid · tile · 0** | 378 · row · button · 0 | 386 · row · button · 0 |
| iPhone 17 Pro Max (440×956) | 344 · row · card 162 · 0 | **408 · grid · tile · 0** | 416 · grid · tile · 0 | 424 · row · button · 17 |
| Pixel 7 (412×915 dp) | 329 · row · card 154 · 0 | **380 · grid · tile · 0** | 388 · grid · tile · 0 | 396 · row · button · 19 |
| Mac window (420×840) | 302 · row · card 182 · 0 | **388 · grid · tile · 0** | 396 · grid · tile · 0 | 404 · row · button · 16 |
| Mac minimum (380×720) | 224 · row · card 140 · 0 | **296 · grid · tile · 0** | 356 · row · button · 0 | 364 · row · button · 0 |
| iPad 11" portrait (834×1210) | 436 · row · card 362 · 0 | **581 · grid · tile · 24** | 581 · grid · tile · 24 | 581 · row · card 206 · 0 |
| iPad 13" portrait (1032×1376) | 495 · row · card 468 · 0 | **648 · grid · card 236 · 0** | 656 · grid · card 222 · 0 | 660 · row · card 293 · 0 |

Where the bottom shows 0 with the map as a tile or button, the spare went into 88-high tiles and wider
gaps. The tests (§8) hold these to the rules, not to the exact numbers, except the iPhone 16 Pro worked
numbers of REFINE.md §3.4 (Medium 370 with 88 tiles; with the sample, about 352, full grid; Large with the
sample, the compact row and the header map button).

---

## 5. iPad, Mac and landscape

- **Portrait iPad, and Mac windows taller than wide:** one centred column, C = min(W − 40, 640), the same
  four layouts. Larger iPads usually promote the map to a card (step 4a); on iPad mini Map stays a tile.
- **Two panes** (W > H and W ≥ 700, or a phone in landscape):
  - one full-width header bar across the top;
  - **leading pane** (W − trailing): dial, readout, status line and lock chip, centred as one group; dial
    = min(pane − 2 × margin, the height left for the group);
  - **trailing pane** = clamp(share × W, 320, 480), share 0.48 / 0.42 / 0.36 / 0.36 (Small / Medium /
    Large / Extra Large), top-aligned with the dial: spot row, grid (3 columns at 360 wide or more,
    otherwise 2 with Map spanning both), then the map card filling the rest (at least 160; otherwise Map
    stays a tile);
  - the Mac and iPad footer ("Made by Bradley Cowdrey · bradcowdrey.com ↗", 13 secondary) is the last line
    of the trailing pane. No strip, nothing shown twice.
- **Mac update banner:** 44 high, tile style, full width between the header and the content.
- **Mac** has no live compass: the dial is static with the no-compass state (REFINE.md §4.2). The window
  keeps `.hiddenTitleBar`, minimum 380×720, ideal 420×840; the window title says Bearings.

---

## 6. The Layout setting and interactions

- **Menu:** the first group in ⋯, a "Layout" submenu with four items (Small, Medium, Large, Extra Large),
  each with a symbol, its one-line subtitle and a checkmark on the current choice (Android:
  `DropdownMenuItem` with supporting text).
- **Stored** under `"layout"` as `small`, `medium`, `large`, `extraLarge`; unknown or missing → `medium`.
  Medium is the default everywhere.
- **Mac:** View › Layout with the four options, **⌘=** larger, **⌘−** smaller, **⌘0** Medium.
- **Change:** animated (0.35 s spring; none with Reduce Motion / animator scale 0), focus stays put.
- **Dial accessibility actions:** Lock / Unlock Bearing, **Larger Compass**, **Smaller Compass** (step the
  layout; disabled at the ends).
- **Gestures:** tap the dial to lock/unlock; tap Position for the next format, long-press for Copy (Mac:
  right-click "Copy Coordinates"); Elevation, Sun and Moon open the Details sheet; Map (tile, card or
  header button) opens the map sheet; tap the spot row for its menu, ✕ to clear.

---

## 7. Text size and accessibility

- **k up to 1.3** (Dynamic Type; Android fontScale): heights are k-scaled; tiles grow before anything
  truncates; coordinates scale to 0.85× and then wrap. Android's 1.15× clamp is gone; iOS
  `minimumScaleFactor` is 0.85.
- **Accessibility sizes** (iOS AX1+; Android fontScale ≥ 1.5), or when nothing fits even at the floor: the
  whole screen is one `ScrollView` / `LazyColumn`, indicator flashed on appear: header (wraps), dial at
  min(C − 32, 0.40 H), readout, status line and lock chip, spot row, tiles as full-width rows, map card at
  200, footer. Every block is complete.
- **Reading order:** header, dial, readout + status line, lock chip, spot row, tiles (Position, Elevation,
  Sun, Moon, Map), map card. Each tile is one element with its caption, value and secondary spelled out;
  Position has the actions **Next Format** and **Copy**.
- **Targets:** 44×44 pt (iOS), 28×28 pt (macOS), 48×48 dp (Android). **Contrast:** 4.5:1 for every text that
  carries information; night secondary text at least `#E03020` on black.
- **Screen title:** iOS keeps "Bearings" as the accessibility title; Android sets `paneTitle`.

---

## 8. CI and tests

**Launch arguments** (applied for that launch only, never saved): Apple `--sample`, `--format <id>`,
`--layout small|medium|large|extraLarge`, `--map-sheet` (opens the map sheet), `--show-terms`,
`--selftest`. Android extras: `--ez sample true`, `--es format <id>`, `--es layout <id>`,
`--ez mapSheet true`, `--es show terms`, `--ez selftest true`, `--ez night true`.

**The golden table** (REFINE.md §4.7): devices {iPhone SE, 16, 16 Pro, 17 Pro Max, Pixel 7, iPad mini, 11"
and 13" in both orientations, Mac 380×720 and 420×840, a phone in landscape} × 4 layouts × {none, locked,
marked, both} × {k 1.0, 1.3, accessibility} × {no banner, banner}. It fails if more than 24 is left empty
at the bottom, the blocks add up to more than S (something partly visible), the dial falls below its floor
or above its cap, or a map card is under 140; and it checks the iPhone 16 Pro worked numbers.

- `LayoutPlan.tableFailures()` (Swift) and `LayoutPlan.tableFailures()` (Kotlin) run it; the Mac, iPhone and
  Android self-tests report it, with one line per layout for the sample screen.
- `Tests/BearingsTests/LayoutPlanTests.swift` (`swift test`, the Tests workflow) runs it plus the rules
  above per device, the layout ids, the accessibility list, two panes and night contrast.
- `android/app/src/test/.../LayoutPlanTest.kt` (`testDebugUnitTest`, the Android workflow) runs the Kotlin
  table and the layout ids.
- The self-tests also check night secondary contrast ≥ 4.5:1 and that no coordinate string contains "…".

**Screenshots:**

| Where | Files |
|---|---|
| iPhone and iPad (`ios.yml`, `$P` = iphone / ipad) | `$P-1-terms`, `$P-2-sample` (Medium), `$P-3-mgrs`, `$P-6-small`, `$P-7-large`, `$P-8-xl`, `$P-10-map-sheet`; `iphone-4-live`, `iphone-5-large-text`, `iphone-9-xl-large-text`; `ipad-9-landscape` when the Simulator can rotate |
| Android (`scripts/android-selftest.sh`) | `android-1-terms`, `-2-live`, `-3-sample` (Medium), `-4-mgrs`, `-5-night`, `-6-large-text`, `-7-small`, `-8-large`, `-9-xl`, `-10-xl-large-text`, `-11-map-sheet` |
| Mac (`mac.yml`, ImageRenderer) | `mac-main` (Medium), `mac-night`, `mac-layout-small`, `mac-layout-large`, `mac-layout-extraLarge` (420×840), `mac-layout-extraLarge-min` (380×720). ImageRenderer cannot draw sheets or MapKit, so there is no Mac map-sheet shot. |
| App Store (`app-store.yml`) | 3 per device, layouts named explicitly: Medium, Extra Large, Small (UTM). None may show empty space. |

---

## 9. Platform notes

- **Apple:** `MainView.swift` reads `LayoutPlan.plan(...)` from the root `GeometryReader` (H = size + the
  safe-area insets). The environment value `\.flatDetails` (set by `Mac/SelfTest.swift`) draws plain stacks
  instead of a `ScrollView` and the ⋯ symbol instead of a `Menu`, because ImageRenderer cannot draw those.
  `BearingsPhoneApp.swift` / `PhoneLaunch` and `BearingsMacApp.swift` read the launch arguments.
- **Android:** `MainScreen.kt` uses `BoxWithConstraints` and `LayoutPlan.plan(...)`; two panes at
  `maxWidth ≥ 700.dp && maxWidth > maxHeight`, or a height under 480 dp. `MainActivity.kt` reads the
  `layout` and `mapSheet` extras without saving them. No new dependencies.
- **Web** (`docs/app.html`) follows later with the same table, key and order.

---

## 10. Why a fixed panel

The old scrolling page under a hero dial caused every problem in REFINE.md §2: tiles below the fold, a map
cut at it, and black above it. Bearings has five facts and a map, which fit on one screen when laid out
compactly. Instruments are glanced at, not read: Apple Compass, the Apple Watch Compass, Garmin data pages
and the compass views in Gaia GPS and onX all show a fixed panel with every value visible without a
gesture. One tile component (the widgets' caption-over-value) carries everything, so the app and its
widgets look like one product. The map is a tile that opens a sheet where a usable map does not fit (the
pattern Apple Weather uses for its map module, and Material's expanding card), and a full card where it
does. Only accessibility text sizes scroll, as HIG and Material expect.
