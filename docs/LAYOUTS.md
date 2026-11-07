# Bearings: layouts (the "Instrument panel")

Status: the layout spec for Apple (SwiftUI, iOS 17 / macOS 14) and Android (Compose), as revised by
[REFINE.md](REFINE.md) Cycle 2 (C2.2, C2.3), which wins wherever the two differ. Colours, type and tokens are
in [LOOK.md](LOOK.md); features and wording in [DESIGN.md](DESIGN.md). The dial drawing, the colours, the
night palette and the widgets do not change.

The owner's brief: **the compass stays large and is the hero; each fact is shown once, nothing is cut off
and nothing is left empty; four layouts, Small, Medium, Large and Extra Large, each with a visibly
different result.**

---

## 1. The structure

**One fixed, non-scrolling screen** (at normal text sizes), top to bottom:

**header bar → dial → readout → status line → lock row → spot row → tile grid → map card (only where it
fits whole).**

- Every fact appears **once**: there is no summary strip, no DETAILS tiles, no title row and no sky card.
- The map is **whole or a tile**, never a sliver: a Map tile, a full-width map card, or a map button in the
  header. All three open the same **map sheet**. There is no bottom fade.
- The planner works **bottom-up** (§3). **No more than 24 is ever left empty at the bottom**, and no block
  is partly visible.
- Only accessibility text sizes scroll (§7).

---

## 2. The elements (Apple pt, Android dp; same numbers)

| Element | Size and content |
|---|---|
| **Header bar** | 48 high (52 on iPad) × k, radius 14, full column width, the sky gradient. Line 1: the place, 17 semibold (the state is dropped first, then it truncates). Line 2: "Sun, Nov 1 · 9:41 AM", 13 at white 75%, and the **Sample** pill. The time never truncates: the date shortens to "Nov 1", then line 2 wraps at the "·"; at k > 1.1 or with three trailing buttons the Sample pill moves to line 1. Trailing, fixed on every layout: the sky symbol (20, decorative), the **map button** (Extra Large only), then **⋯** (44×44 pt / 48×48 dp, 8 apart). |
| **Dial** | Unchanged drawing, centred. Its size comes from the layout's rule (§4). |
| **Readout** | "228° SW", heading 56 (64 on iPad) × the readout scale (1.25 at Extra Large: 70 / 80). Its line box is trimmed: **dial → readout is 12**, from the dial's bottom edge to the digits' cap height. With no compass: "—°" (U+2014) at white 40%, then "NO HEADING" (11 caps) 4 below. |
| **Status line** | 13, white 60%, centred, 6 under the readout: "True north · 8° E declination · ±8° accuracy". Amber warnings take the same slot. Wraps to 2 lines only at k > 1.1 (or for the no-compass note), at a "·", within C − 32. |
| **Lock row** | Only when a bearing is locked: a full-width tile row, 44 high, leading-aligned: `lock.fill`, "Locked 240°", "turn 12° right", and ✕ 8 after the text (44×44 / 48 dp target). Status → lock row 8 × k. |
| **Spot row** | Only when a spot is marked: the same row form. Pin 17, "Marked spot" 15 medium, "9.2 mi · 46° NE" 15 tabular, ✕ 8 after the text. Tap: Lock to Spot, Clear Marked Spot. 8 above the grid. |
| **Tile grid** | **Full** (3 columns, u = (C − 16) / 3, gutters 8): POSITION (2u + 8) \| ELEVATION, then SUN \| MOON \| MAP. **Compact row**: widths from C, not from units: Elevation = Sun = **w = max(104, round(0.27 C))**, Position = C − 16 − 2w (C 370 → 146 \| 104 \| 104; C 380 → 156 \| 104 \| 104; C 700 → 306 \| 189 \| 189). Moon stays in the row through the Sun caption, `SUN · ◐ 53%`. Every row's widths plus gutters equal C. |
| **Map card** | Full column width, at least 140 (160 when promoted, 200 for Medium on iPad), radius 16. One vertical control stack top-trailing: 36 circles (44 pt / 48 dp hit areas), 8 apart, inset 12: +, −, follow heading, open in Maps; a card under 192 tall shows +, − and ⋯ (the other two in the overflow). Speed chip inset 12 top-leading; attribution bottom-trailing, kept clear. |
| **Map sheet** | Full-bleed map under a translucent bar ("Map" title, Done trailing, one baseline), the same control stack, heading cone and speed chip on both ports. iPad: `.presentationSizing(.page)`; Android: 64 dp top bar, `contentWindowInsets`, `skipPartiallyExpanded`. |
| **Details sheet** | iOS `.sheet` with `[.medium, .large]` and a grabber; Android `ModalBottomSheet`: accuracy, fix age, format name, pressure, moon phase, rise and set azimuths. |

**The tile** (one component on both ports, as the widgets): `frostedTile()` / `surfaceContainer`, radius 16,
padding 12 × 10. The **caption is pinned to the top** (inset 10) and the **value block to the bottom** (inset
10) with a spacer between, so a grown tile is never empty underneath. Caption 11 semibold caps, tracking 0.6,
white 60%; value 17 medium tabular (15 in the compact row); secondary 13, white 60%.

| Tile | Caption | Value | Secondary | Tap / long-press |
|---|---|---|---|---|
| Position | `POSITION · DD` (DD, DMS, DDM, UTM, MGRS, PLUS) | "39.09898° N" over "106.94117° W" | dims when stale | Tap: next format. Long-press: Copy, Details… |
| Elevation | `ELEVATION` | "9,587 ft" | "2,922 m" (order follows Units) | Details sheet |
| Sun | `SUN` (`SUN · ◐ 53%` in the compact row) | "↑ 6:36 AM" over "↓ 5:08 PM"; in the compact row 15 semibold, scale 0.85, then "6:36" over an 11 pt "AM" | polar: "Up all day" / "Down all day" | Details sheet (Moon in full) |
| Moon | `MOON` | phase glyph + "53%" | "Last quarter" | Details sheet |
| Map | `MAP`, bottom-leading on a 40% scrim | live thumbnail, heading cone, no controls; attribution bottom-trailing | — | Map sheet |

**Nothing ever ellipsizes** (values, coordinates, times): text scales to 0.85×, then wraps; a tile grows
taller first. Times use one formatter on every platform (`.hour().minute()`, a narrow no-break space before
AM/PM). Before the first fix tiles show "—" and "Finding position…".

---

## 3. The planner

`Sources/Bearings/Views/LayoutPlan.swift` and `android/.../ui/LayoutPlan.kt`: one pure function, the same
constants and order, no UI code.

**Gaps** (tokens 4 / 8 / 12 / 16 / 24, multiplied only by k): top → header 4 · header → dial 12 · dial →
readout 12 (fixed) · readout → status 6 · status → lock row 8 · readout group → rows 16 · between rows 8 ·
grid → map card 12 · last block → bottom 8. Side margins 16 (20 on iPad). **Mac windows: 16 on all four
edges (24 at widths of 600 or more)**, subtracted before the map card is sized. Column **C = min(W − 2 ×
margin, 640)**.

With **S** the safe height and **H** the full height:

1. Place the fixed blocks: header, readout group, lock row, spot row, and the layout's grid at 72.
2. The dial takes its layout's rule (§4), at most its cap (W − 2e; on tablets also a share of H).
3. Below the layout's **floor** (0.30 / 0.30 / 0.38 / 0.40 H), the screen becomes the scrolling list (§7);
   Small first shrinks its map card toward 140.
4. Spare height: (a) 160 or more and the layout allows → a full-width map card (Medium takes up to 200 from
   the dial for it); (b) Medium only: tiles grow 72 → 88 (96 on iPad); (c) up to +12 on header → dial and on
   readout group → rows; (d) the rest above the header and below the grid, **never more than 24 at the
   bottom**.

---

## 4. The four layouts

One rule per layout, the same on every port and device (C2.2 #2). The ⋯ menu subtitle states the result,
e.g. "Dial 386 · map in header".

| Layout | Grid | Tiles | Map | Dial | Readout |
|---|---|---|---|---|---|
| **Small** "Compass and map" | compact row | 72 | card of 140 or more, filling the rest | 0.36 H (floor 0.30 H) | 1.0 |
| **Medium** (default) "Balanced" | full 2-row grid | 72–88 (96 iPad) | tile, or a card (≥ 200 on iPad) when 160 or more is spare | Large's less 24 | 1.0 |
| **Large** "Bigger compass" | full grid | fixed 72 | tile (a card only where 160 or more is still spare) | gets the saved height, up to W − 16 | 1.0 |
| **Extra Large** "Biggest compass" | compact row | 72 | header button, on every device | W − 16 (tablet: up to 0.64 H) | 1.25 |

Neighbouring layouts always differ by **24 or more of dial, or by grid mode** (a test).

### 4.1 Planner results

At the default text size; each cell is **dial · grid · map · empty at the bottom** ("grid" = full, "row" =
compact, "list" = the scrolling list). Pixel 7 S = 915 − 52 − 24 = 839 dp. The tests hold the rules, not
these exact numbers, except the iPhone 16 Pro and Mac checks in §8.

**Nothing locked or marked:**

| Device | Small | **Medium** | Large | Extra Large |
|---|---|---|---|---|
| iPhone SE 375×667 | 240 · row · card 157 · 0 | **305 · grid · tile · 0** | 329 · grid · tile · 0 | 359 · row · button · 8 |
| iPhone 16 393×852 | 307 · row · card 202 · 0 | **353 · grid · tile · 16** | 377 · grid · tile · 20 | 377 · row · button · 24 |
| iPhone 16 Pro 402×874 | 315 · row · card 213 · 0 | **362 · grid · tile · 21** | 386 · grid · tile · 24 | 386 · row · button · 24 |
| Pixel 7 412×915 dp | 329 · row · card 259 · 0 | **372 · grid · tile · 24** | 396 · grid · tile · 24 | 396 · row · button · 24 |
| Mac 420×840 | 302 · row · card 267 · 0 | **380 · grid · tile · 24** | 404 · grid · tile · 24 | 404 · row · button · 24 |
| iPad 11" 834×1210 | 436 · row · card 470 · 0 | **626 · grid · card 200 · 0** | 653 · grid · card 173 · 0 | 774 · row · button · 24 |

**Locked and marked (the sample):**

| Device | Small | **Medium** | Large | Extra Large |
|---|---|---|---|---|
| iPhone SE 375×667 | list | **201 · grid · tile · 0** | list | 295 · row · button · 0 |
| iPhone 16 393×852 | 265 · row · card 140 · 0 | **313 · grid · tile · 0** | 337 · grid · tile · 0 | 377 · row · button · 3 |
| iPhone 16 Pro 402×874 | 284 · row · card 140 · 0 | **332 · grid · tile · 0** | 356 · grid · tile · 0 | 386 · row · button · 8 |
| Pixel 7 412×915 dp | 329 · row · card 155 · 0 | **372 · grid · tile · 0** | 396 · grid · tile · 0 | 396 · row · button · 24 |
| Mac 420×840 | 302 · row · card 163 · 0 | **374 · grid · tile · 0** | 398 · grid · tile · 0 | 404 · row · button · 20 |
| iPad 11" 834×1210 | 436 · row · card 366 · 0 | **629 · grid · tile · 16** | 653 · grid · tile · 24 | 774 · row · button · 2 |

Where the bottom is under 24 with a tile or button, the spare went into taller tiles (Medium) and wider gaps.

---

## 5. iPad, Mac and landscape

- **Portrait iPad, and Mac windows taller than wide:** one centred column, C = min(W − 2 × margin, 640) (W − 40 on iPad; W − 32 on a Mac under 600), the same
  four layouts. Medium promotes the map to a card of 200 or more whenever 160 or more is spare; Extra Large
  never shows a card.
- **Two panes** (W > H and W ≥ 700, or a phone in landscape): one full-width header; the **leading pane**
  holds the dial, readout and status line, centred; the **trailing pane** = clamp(share × W, 320,
  480), share 0.48 / 0.42 / 0.36 / 0.36, top-aligned with the dial: lock row, spot row, **fixed 80 rows** (3 columns at
  360 or wider, otherwise 2), then the map card filling the rest (at least 160; otherwise Map stays a tile;
  Extra Large: the header button). Without the Map tile, Sun and Moon share their row at (C − 8) / 2 each.
  In two panes the layouts differ by the pane's share and the map rule; the dial is usually height-limited.
- **Footer** ("Made by Bradley Cowdrey · bradcowdrey.com") lives in the ⋯ menu on every layout and platform.
- **Mac:** no live compass (the no-compass state); `.hiddenTitleBar`, window title Bearings; minimum
  380×740 (header + dial + grid + insets), ideal 420×840. Update banner: 44 high, tile style, under the header.

---

## 6. The Layout setting and interactions

- **Menu:** the first group in ⋯: "Layout" with Small, Medium, Large, Extra Large, each with a symbol, the
  result as its subtitle ("Dial 386 · map in header") and a checkmark (Android: `DropdownMenuItem` with
  supporting text). **Mac:** View › Layout, ⌘= larger, ⌘− smaller, ⌘0 Medium.
- **Stored** under `"layout"` as `small`, `medium`, `large`, `extraLarge`; unknown or missing → `medium`.
- **Change:** animated (0.35 s spring; none with Reduce Motion), focus stays put.
- **Dial actions:** Lock / Unlock Bearing, Larger Compass, Smaller Compass (disabled at the ends).
- **Gestures:** tap the dial to lock/unlock; tap Position for the next format, long-press to copy (Mac:
  right-click); Elevation, Sun and Moon open Details; Map (tile, card or header button) opens the map
  sheet; tap the lock or spot row for its menu, ✕ to clear.

---

## 7. Text size and accessibility

- **k up to 1.3** (Dynamic Type; Android fontScale, no clamp): heights are k-scaled; tiles grow before
  anything truncates; values scale to 0.85× and then wrap (`minimumScaleFactor(0.85)`).
- **Accessibility sizes** (iOS AX1+; Android fontScale ≥ 1.5), or when nothing fits at the floor: one
  `ScrollView` / `LazyColumn`, scroll indicator flashed on appear, a 24 bottom fade as the cue: header
  (wraps), dial at min(C − 32, 0.40 H) chosen so the fold falls 24 or more below a whole block, readout,
  status line, lock row, spot row, tiles as full-width rows, map card at 200. VoiceOver/TalkBack swipes
  scroll into the next block.
- **Reading order:** header, dial, readout + status, lock row, spot row, Position, Elevation, Sun, Moon,
  Map. Each tile is one element. No compass reads "Heading unavailable", announced once politely.
- **Targets:** 44×44 pt, 28×28 pt on macOS, 48×48 dp. **Contrast** 4.5:1; night secondary at least
  `#E03020` on black.

---

## 8. CI and tests

**Launch arguments** (this launch only, never saved): Apple `--sample`, `--format <id>`, `--layout
small|medium|large|extraLarge`, `--map-sheet`, `--no-compass` (with `--sample`), `--show-terms`,
`--selftest`. Android extras: `--ez sample true`, `--es format <id>`, `--es layout <id>`, `--ez mapSheet
true`, `--ez noCompass true`, `--es show terms`, `--ez selftest true`, `--ez night true`.

**The golden table** (`LayoutPlan.tableFailures()`, Swift and Kotlin, run by the self-tests and the unit
tests): devices (iPhone SE, 16, 16 Pro, 17 Pro Max, Pixel 7, iPad mini / 11" / 13" portrait, iPad 11" / 13"
landscape, Mac 380×740 / 420×840 / 1200×800, a phone in landscape) × 4 layouts × {none, locked, marked,
both} × {k 1.0, 1.3, accessibility} × {banner or not} × {compass or not}. It fails if:

- more than 24 is empty at the bottom, a block is partly visible, or the dial is under its floor or over
  its cap;
- a map card is under 140, or Extra Large shows a map card;
- any row's widths plus gutters differ from C, or a compact tile is under 104;
- a Mac window is closer than 16 to an edge;
- two neighbouring layouts differ by less than 24 of dial with the same grid;
- the worked numbers drift (iPhone 16 Pro Medium 362 with 88 tiles; Extra Large 386, compact, header
  button, readout 1.25; compact widths at 370 and 380; iPad 11" Medium map card ≥ 200).

Also on both ports: no "…" in any tile value or the header time (the strings at every size; Apple's
`MainView.fitFailures` and Android's `tableFailures()` measure the compact row and the header at k 1.0 and
1.3; at AX1 the tiles are full-width rows of the scrolling list), the no-compass readout is `—°`, and night secondary contrast ≥
4.5:1. Swift: `Tests/BearingsTests/LayoutPlanTests.swift` (`swift test`, Tests workflow). Android:
`android/app/src/test/.../LayoutPlanTest.kt` (`testDebugUnitTest`).

**Screenshots:**

| Where | Files |
|---|---|
| iPhone and iPad (`ios.yml`, `$P` = iphone / ipad) | `$P-1-terms`, `$P-2-sample` (Medium), `$P-3-mgrs`, `$P-6-small`, `$P-7-large`, `$P-8-xl`, `$P-10-map-sheet`, `$P-11-no-compass`; `iphone-4-live`, `iphone-5-large-text`, `iphone-9-xl-large-text`, `iphone-12-ax1`; `ipad-9-landscape`, `ipad-12-landscape-small`, `ipad-13-landscape-xl` when the Simulator can rotate |
| Android (`scripts/android-selftest.sh`) | `android-1-terms`, `-2-live`, `-3-sample` (Medium), `-4-mgrs`, `-5-night`, `-6-large-text`, `-7-small`, `-8-large`, `-9-xl`, `-10-xl-large-text`, `-11-map-sheet`, `-12-no-compass`, `-13-ax-text` |
| Mac (`mac.yml`, ImageRenderer) | `mac-main` (Medium), `mac-night`, `mac-nocompass`, `mac-layout-small`, `-large`, `-extraLarge` (420×840), `mac-layout-extraLarge-min` (380×740). ImageRenderer cannot draw sheets or MapKit, so there is no Mac map-sheet shot. |
| App Store (`app-store.yml`) | 3 per device, layouts named: Medium, Extra Large, Small (UTM). None may show empty space or "…". |

---

## 9. Platform notes

- **Apple:** `MainView.swift` reads `LayoutPlan.plan(...)` from the root `GeometryReader`. `\.flatDetails`
  (set by `Mac/SelfTest.swift`) draws plain stacks and the ⋯ symbol, which ImageRenderer can draw.
  `PhoneLaunch` (`BearingsPhoneApp.swift`) and `BearingsMacApp.swift` read the launch arguments.
- **Android:** `MainScreen.kt` uses `BoxWithConstraints` and `LayoutPlan.plan(...)`; `MainActivity.kt` reads
  the extras without saving them. Map: a dark style, red-tinted at night (≤ 15% luminance), with a visible
  `© OpenStreetMap` bottom-leading and (i) as a 48 dp target. ✕ glyphs are 18 dp `Icons.Rounded.Close` in a
  48 dp `IconButton`.
- **Web** (`docs/app.html`) follows later with the same table and order.

Why a fixed panel: the earlier scrolling page put tiles below the fold, cut the map at it and left black
above it. Five facts and a map fit on one screen when laid out compactly, and instruments are glanced at:
every value visible without a gesture. Only accessibility sizes scroll, as HIG and Material expect.
