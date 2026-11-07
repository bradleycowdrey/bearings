# Bearings: layouts (the "Instrument panel")

Status: the layout spec for Apple (SwiftUI, iOS 17 / macOS 14) and Android (Compose), as revised by
[REFINE.md](REFINE.md) Cycle 3 (C3.2–C3.4), which wins wherever the two differ. Colours, type and tokens are
in [LOOK.md](LOOK.md); features and wording in [DESIGN.md](DESIGN.md). The dial drawing, the colours and the
night palette do not change.

The owner's brief: **the compass stays large and is the hero; each fact is shown once, nothing is cut off
and nothing is left empty; four layouts, Small, Medium, Large and Extra Large, each visibly different.**

---

## 1. The structure

**One fixed, non-scrolling screen** (at normal text sizes), top to bottom:

**header bar → dial → readout → status line → lock row → spot row → tile grid → map card (only where it
fits whole).**

- Every fact appears **once**. The map is **whole or a tile**, never a sliver: a Map tile, a full-width map
  card, or a map button in the header. All three open the same **map sheet**.
- The header is **pinned at the safe top + 8** (Android: status bar + 8 dp; a Mac window: 24) in every
  layout and state: live, sample, no compass, locked or not.
- **Gaps are frozen.** Spare height never widens a gap; it goes to the dial, the map card, Medium's tiles,
  and then at most 24 above the dial and 24 at the bottom (§3).
- Only accessibility text sizes scroll (§7).

---

## 2. The elements (Apple pt, Android dp; same numbers)

| Element | Size and content |
|---|---|
| **Header bar** | 48 high (56 on iPad) × k, radius 14, full column width, the sky gradient. Line 1: the **full place name** ("Maroon Bells, Colorado"), 17 semibold (22 on iPad); it wraps rather than drop the state. Line 2: "Sun, Nov 1 · 9:41 AM", 13 at white 75% (15 on iPad); the date shortens to "Nov 1" first, then the title wraps; the time never truncates. The **Sample** pill always trails line 2 (13 semibold in a 20 capsule), on line 1 only at accessibility sizes. Trailing: the sky symbol (decorative), the **map button** (Large and Extra Large), then **⋯** (44×44 pt / 48×48 dp, 8 apart). |
| **Dial** | Unchanged drawing, centred. Its size comes from the plan (§3, §4). |
| **Readout** | "228° SW", 56 (96 on iPad) × the readout scale (1.25 at Extra Large). **Dial → readout is 12**, from the dial's edge to the digits' cap height. **No compass:** the dash is **drawn, not typed**: a rounded bar 0.5 em × 0.08 em (28 × 4.5 at 56), white 40%, centred on the digits' cap-height midline, with "°" where it sits after "228", same size and weight. Spoken: "Heading unavailable". |
| **Status line** | 13, white 60%, centred, 6 under the readout: "True north · 8° E declination · ±8° accuracy". Amber warnings take the same slot. No compass: "No compass · position, sun and map still work" (there is no separate NO HEADING line). Wraps at a "·" only at k > 1.1 or for the no-compass note. |
| **Lock row** | Only when a bearing is locked. **One component on both ports:** 52 high, fill `#3D2128` (night: red at 15% luminance), 1 pt border `#5A2C38`. "Locked 240°" leading, 17 regular; "turn 12° right" trailing, 17 semibold; 12 minimum between; non-breaking spaces inside values. ✕ 18 in a 44 pt / 48 dp target, 4 from the trailing edge. At k ≥ 1.5 the cue drops to line 2 at 15. |
| **Spot row** | Only when a spot is marked: the same two-column row (52) on the neutral tile fill. "Marked spot" leading, "9.2 mi · 46° NE" trailing, ✕. Tap: Lock to Spot, Clear Marked Spot. |
| **Tile grid** | **Full** (Medium): 3 columns, u = (C − 16) / 3: POSITION (2u + 8) \| ELEVATION, then SUN \| MOON \| MAP. **2 × 2** (Large): (C − 8) / 2 each: POSITION \| ELEVATION, then SUN \| MOON. **Compact row** (Small, Extra Large): Elevation = Sun = **w = max(104, round(0.27 C))**, Position = C − 16 − 2w (C 370 → 146 \| 104 \| 104; 380 → 156 \| 104 \| 104; 700 → 306 \| 189 \| 189); the moon rides in the Sun caption, `SUN · ◐ 53%`. Every row's widths plus gutters equal C. |
| **Map card** | Full column width, at least 140 (160 with no compass, 200 when Medium promotes it, 240 in a two-pane trailing pane), radius 16. One control stack top-trailing: 36 circles in 44 pt / 48 dp targets, 8 apart, inset 12. Speed chip top-leading with 48 dp collision padding. Attribution `© OpenStreetMap ⓘ` in one pill bottom-leading at 8 (Android); Apple's Legal in the sheet. |
| **Map sheet** | Full-bleed map, "Map" title and Done on one baseline, the same control stack, heading cone and speed chip. iPad: `.presentationSizing(.page)`. Android: a 32 × 4 dp grabber, the status bar visible (`contentWindowInsets`), `skipPartiallyExpanded`. |

**The tile** (one component on both ports): radius 16, insets 10 (14 on iPad). **Captions are text only**
(no glyphs), 11 semibold caps (13 on iPad), tracking 0.6, white 60%, at inset 10 top and leading. The **last
baseline of every value block sits at inset 10 from the bottom**, so Sun's times, Moon's "53%" and a
one-line MGRS line up. Value 17 medium tabular (22 on iPad; 15 in the compact row); secondary 13 (15 on
iPad). Position's two lines share **one** point size (the longer line decides); one-line formats (MGRS,
Plus Code) are 20, and the tile stays 72.

| Tile | Caption | Value | Secondary | Tap / long-press |
|---|---|---|---|---|
| Position | `POSITION · DD` (DD, DMS, DDM, UTM, MGRS, PLUS) | "39.09898° N" over "106.94117° W" | dims when stale | Tap: next format. Long-press: Copy, Details… |
| Elevation | `ELEVATION` | "9,587 ft" | "2,922 m" (order follows Units) | Details sheet |
| Sun | `SUN` (`SUN · ◐ 53%` in the compact row) | "↑ 6:36 AM" over "↓ 5:08 PM" | polar: "Up all day" / "Down all day" | Details sheet |
| Moon | `MOON` | phase glyph + "53%" | "Last quarter" | Details sheet |
| Map | `MAP` + expand glyph, bottom-leading on a 24 scrim (the one deliberate bottom caption: it labels an image) | Apple under 160 wide: a static snapshot with the user dot; Android: the dark map with labels at 70% | attribution trailing, 9–10 | Map sheet. One element: "Map, opens full map" |

**Nothing ever ellipsizes** (values, coordinates, times): text scales to 0.85×, then wraps. Times use one
formatter on every platform (a narrow no-break space before AM/PM). Before the first fix tiles show "—".

---

## 3. The planner: one rule set

`Sources/Bearings/Views/LayoutPlan.swift` and `android/.../ui/LayoutPlan.kt`: one pure function each, **the
same constants, the same steps in the same order** (C3.3). The screens read `dial`, `grid`, `map`, `tile`
and every gap from the plan and nowhere else. `gapGrow` is gone.

**Frozen gap tokens** (× k, never grown): header → dial 12 · dial → readout 12 · readout → status 6 · status
→ lock 8 · lock → spot 8 · readout group (or spot) → grid 8 · between rows 8 · grid → map card 12 · bottom 16
(24 on iPad and Mac). Margins 16 on phones; iPad column **min(W − 48, 720)**, centred, so the side margin is
the same in every layout; **Mac: 24 on all four edges**. Phone column **C = W − 32**.

**Shared steps** (S = safe height, H = full height):

1. Pin the header at safe top + 8.
2. Place the fixed blocks with the frozen tokens: header, readout group, lock row, spot row, the layout's
   grid at 72.
3. **Dial = min(cap, S − fixed).** Under the layout's floor, apply its pressure order (§4), then the
   scrolling list (§7).
4. Spend spare **in this order**: (a) the dial, up to its cap; (b) the map card, Small and Medium only;
   (c) tile growth, Medium only, 72 → 88 (96 on iPad); (d) split between header → dial and the bottom,
   **each at most 24**.

**No compass, or live with nothing locked:** the readout stack is two lines, and the freed height (no
NO HEADING line; the lock's 52 + 8) goes through the same order: dial, then a 160 map card. The grid stays
the layout's own.

---

## 4. The four layouts

The map surface shrinks as the compass grows, one step per layout, and **every step changes the grid
mode**. The ⋯ menu subtitle says what changes.

| | **Small** "Compass + big map" | **Medium** (default) "Balanced · map tile" | **Large** "Bigger compass · map in header" | **Extra Large** "Biggest compass · one row" |
|---|---|---|---|---|
| Grid | compact row | 3 columns, 2 rows (with the Map tile) | 2 × 2 at (C − 8) / 2 | compact row |
| Tiles | 72 | 72, grows to 88 (96 tablet) from spare only | fixed 72 | 72 |
| Map | card ≥ 140, takes all spare | tile; a card (≥ 200) when ≥ 160 is spare | header button | header button |
| Dial cap | 0.36 H (floor 0.30 H) | C − 32 (tablet: min(C − 32, 0.48 H)) | C − 16 (tablet: min(C − 16, 0.54 H)) | C − 16 (tablet: min(C − 16, 0.64 H), the column widens to the dial) |
| Readout | 1.0 | 1.0 | 1.0 | 1.25 |
| Under pressure | map card → 140, then dial → floor | tiles → 72, then the scrolling list | dial → 0.42 H, then the compact row | never shrinks the dial while the grid can scroll |

Neighbouring layouts always differ in **grid mode and map surface** (card → tile → button), and on phones
**dial(Large) ≥ dial(Medium) + 16**. These are tests (§8).

### 4.1 What each layout draws (iPhone 16 Pro, the sample: locked and marked)

- **Small:** dial 0.36 H or less, the compact row, and a map card of 140 or more taking the rest.
- **Medium:** the 3-column grid with the Map tile; tiles 72, grown from spare only.
- **Large:** a dial 16 or more over Medium's, the 2 × 2 grid at fixed 72, the map in the header.
- **Extra Large:** the biggest dial (C − 16 at most), readout 1.25, one compact row, the map in the header.

The exact numbers per device are printed by the self-tests (one line per layout: "dial 338 · 3 columns ·
map tile", with the bottom spare) and held by the golden table's rules, not by this page.

---

## 5. iPad, Mac and landscape

- **Portrait iPad and tall Mac windows:** one centred column (iPad min(W − 48, 720); Mac W − 48), the same
  four layouts with the **regular-width type ramp**: header 22 / 15, tile caption 13 caps, value 22
  semibold tabular, secondary 15, readout 96, tiles 96, insets 14.
- **Two panes** (W > H and W ≥ 700, or a phone on its side): one full-width header. **Leading pane:** dial
  and readout, centred vertically, readout 12 under the dial, 24 or more at the bottom. **Trailing pane:**
  lock 52, spot 52, **fixed 80 rows** (Sun and Moon at (C − 8) / 2), the rest to the map card (≥ 240).
  - Small: map card ≥ 60% of the pane, compact row.
  - Medium: 3-column rows and the map card.
  - Large: 2 × 2, map in the header, pane stack centred vertically.
  - Extra Large: leading pane 60% wide, compact row, stack centred.
  - Small and Extra Large: where the compact row's Position is too narrow for a longitude at the current
    text size (a narrow trailing pane, e.g. a 900-wide Mac window), the pane takes the 2 × 2 instead, if it
    fits (both ports).
  The four layouts give **four distinct plans** in landscape too (a test).
- **No compass on iPad:** the layout's own grid; the freed readout height goes to the dial, then the card.
- **Mac:** no live compass (the no-compass state); `.hiddenTitleBar`; 24 on all four edges; header pinned.
  Update banner: 44 high, tile style, under the header. "Made by Bradley Cowdrey" lives in the ⋯ menu.

---

## 6. The Layout setting and interactions

- **Menu:** the first group in ⋯: "Layout" with Small, Medium, Large, Extra Large, each with a symbol,
  the subtitle above ("Bigger compass · map in header") and a checkmark (Android: `DropdownMenuItem` with
  supporting text). **Mac:** View › Layout, ⌘= larger, ⌘− smaller, ⌘0 Medium.
- **Stored** under `"layout"` as `small`, `medium`, `large`, `extraLarge`; unknown or missing → `medium`.
- **Change:** animated (0.35 s spring; none with Reduce Motion), focus stays put.
- **Dial actions:** Lock / Unlock Bearing, Larger Compass, Smaller Compass (disabled at the ends).
- **Gestures:** tap the dial to lock/unlock; tap Position for the next format, long-press to copy (Mac:
  right-click); Elevation, Sun and Moon open Details; Map (tile, card or header button) opens the map
  sheet; tap the lock or spot row for its menu, ✕ to clear.

---

## 7. Text size and accessibility

- **k ≥ 1.3** (Dynamic Type; Android fontScale): the dial is **min(C − 48, 0.36 H)** (about 300 pt / 280
  dp), so Position and Elevation sit whole above the fold, which lands 24 or more below a whole block.
- **Accessibility sizes** (iOS AX1+; Android fontScale ≥ 1.5): one `ScrollView` / `LazyColumn`; lock and
  spot merge into one two-line **Targets** card; tiles become a 1-column list of **64** rows (caption
  leading, value trailing); map card 200. A 24 fade at the bottom, the scroll indicator flashed once on
  appear, and VoiceOver/TalkBack swipes scroll into the cut tile.
- **Reading order:** header, dial, readout + status, lock row, spot row, Position, Elevation, Sun, Moon,
  Map. Each tile is one element. No compass reads "Heading unavailable", announced once politely.
- **Targets:** 44×44 pt, 28×28 pt on macOS, 48×48 dp. **Contrast** 4.5:1; night secondary at least
  `#E03020` on black.

---

## 8. CI and tests

**Launch arguments** (this launch only, never saved): Apple `--sample`, `--format <id>`, `--layout
small|medium|large|extraLarge`, `--map-sheet`, `--no-compass` (with `--sample`), `--show-terms`,
`--selftest`. Android extras: `--ez sample true`, `--es format <id>`, `--es layout <id>`, `--ez mapSheet
true`, `--ez noCompass true`, `--ez lock false`, `--ez spot false`, `--es show terms`, `--ez selftest
true`, `--ez night true`.

**The golden table** (`LayoutPlan.tableFailures()`, Swift and Kotlin, run by the self-tests and the unit
tests): iPhone SE, 16, 16 Pro, Pro Max, iPad mini / 11" / 13" portrait and landscape, Mac, Android 360×640,
412×914, Pixel 7, tablet portrait and landscape, a phone on its side × 4 layouts × {sample, live, no
compass, locked, marked} × {k 1.0, 1.3, accessibility}. It fails if:

- the header top is not safe top + 8, or any inter-row gap is not its token × k;
- more than 24 is spare above the dial or at the bottom, or anything is cut;
- any row's widths plus gutters differ from C, or a tile is taller than its cap (portrait and landscape);
- a map card is under 140, or Large or Extra Large shows a Map tile;
- neighbouring layouts share a grid mode or map surface, dial(L) < dial(M) + 16 on a phone, or the four
  landscape plans are not distinct;
- at k ≥ 1.3, Position and Elevation are not whole above the fold.

Also on both ports: no "…" in any tile value or the header time; the **drawn** no-heading dash centre is
within ±4 of the digit centre-line of "228°" at the same scale (a render check, not a string check);
both Position lines at one point size; the lock row never splits inside a value; night secondary contrast
≥ 4.5:1; Android map label colour and italics checked against the style JSON. Swift:
`Tests/BearingsTests/LayoutPlanTests.swift` (`swift test`). Android: `android/app/src/test/.../LayoutPlanTest.kt`.

**Screenshots** (CI fails if a layout, the map sheet or a no-compass shot is missing):

| Where | Files |
|---|---|
| iPhone and iPad (`ios.yml`, `$P` = iphone / ipad) | `$P-1-terms`, `$P-2-sample` (Medium), `$P-3-mgrs`, `$P-6-small`, `$P-7-large`, `$P-8-xl`, `$P-10-map-sheet`, `$P-11-no-compass`, `$P-14-no-compass-xl`; `iphone-4-live`, `iphone-5-large-text`, `iphone-9-xl-large-text`, `iphone-12-ax1`; landscape when the Simulator can rotate: `ipad-9-landscape` (Medium), `ipad-12-landscape-small`, `ipad-15-landscape-large`, `ipad-13-landscape-xl`, `ipad-16-landscape-no-compass` |
| Android (`scripts/android-selftest.sh`) | `android-1-terms`, `-2-live`, `-3-sample` (Medium), `-4-mgrs`, `-5-night`, `-6-large-text`, `-7-small`, `-8-large`, `-9-xl`, `-10-xl-large-text`, `-11-map-sheet`, `-12-no-compass`, `-13-ax-text`, `-14-no-compass-xl`, `-15-unlocked` |
| Mac (`mac.yml`, ImageRenderer) | `mac-main` (Medium), `mac-night`, `mac-nocompass`, `mac-live`, `mac-layout-small`, `-large`, `-extraLarge`, `mac-layout-extraLarge-min`, `mac-wide-medium`, `mac-wide-large` (two panes). No Mac map-sheet shot: ImageRenderer cannot draw sheets or MapKit. |
| App Store (`app-store.yml`) | 3 per device, layouts named: Medium, Extra Large, Small (UTM). None may show empty space or "…". |

---

## 9. Platform notes

- **Apple:** `MainView.swift` reads `LayoutPlan.plan(...)` from the root `GeometryReader`. `\.flatDetails`
  (set by `Mac/SelfTest.swift`) draws plain stacks, which ImageRenderer can draw. `PhoneLaunch`
  (`BearingsPhoneApp.swift`) and `BearingsMacApp.swift` read the launch arguments.
- **Android:** `MainScreen.kt` uses `BoxWithConstraints` and `LayoutPlan.plan(...)`; `MainActivity.kt` reads
  the extras without saving them. Map labels: `#C9D3D6` regular (not italic), 11–12 sp, a 1.5 dp `#0F3B3A`
  halo, 70% in the tile; POI labels hidden under 160 dp of map height, road shields under 200 dp of width.
  Night: the map red-tinted at 35% luminance; the Sample pill a red outline with red text on black.
- **Web** (`docs/app.html`) follows later with the same table and order.

Why a fixed panel: instruments are glanced at, so every value is visible without a gesture. Only
accessibility sizes scroll, as HIG and Material expect.
