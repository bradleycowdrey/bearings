# Bearings: layouts (Concept A, the "Instrument panel")

Status: the layout spec for Apple (SwiftUI, iOS 17 / macOS 14) and Android (Compose). The exact build spec,
with every size, is [REFINE.md](REFINE.md) "Concept A (chosen, Option 1)", which wins wherever the two
differ. Colours, type and tokens are in [LOOK.md](LOOK.md); features and wording in [DESIGN.md](DESIGN.md).
**The dial drawing, the readout "228° SW" and the status line do not change.**

The owner's brief: the compass is the hero (**≥ 40% of the screen height** in portrait, one column, every
layout); each fact once; nothing cut off or left empty; four layouts, each visibly different.

---

## 1. The structure

One fixed screen (only accessibility text sizes scroll), top to bottom:

**dial → readout → status line → location card → Targets card → the layout's tiles / map.**

- **Nothing is pinned to the status bar.** The dial's top is **safe top + 18** (iPhone 16 Pro: 80; Android:
  status inset + 18 dp; Mac: 46). The stack ends at the safe bottom (home-indicator inset; else 16; Android
  nav inset + 8).
- The **location card** (the blue sky card: place, date and time, Sample pill, sun glyph, the map button in
  Large and Extra Large, and **⋯**) sits 12 under the status line. It is 48 pt / 56 dp high, radius 14.
- The **Targets card** appears only when a bearing is locked or a spot is marked, 8 under the location card,
  and shows only the rows that exist: the lock row on the maroon tint (`#3D2128`, border `#5A2C38`),
  "Locked 240°" … "turn 12° right" ✕; a hairline; the spot row "Marked spot" … "9.2 mi · 46° NE" ✕. Rows 44
  pt / 48 dp (Extra Large and iPad 52 / 64 dp).
- Frozen gaps: dial → readout 12, readout → status 6, status → card 12, card → Targets 8, → tiles 8, rows 8.
  Margins 16; iPad column min(W − 48, 720); Mac 24.
- **No compass:** the words **"No heading"** (34 semibold, white 55%) take the readout's slot; the status
  line says "Position, sun and map still work".

---

## 2. The four layouts (iPhone 16 Pro, sample with lock + spot)

| | **Small** | **Medium** (default) | **Large** | **Extra Large** |
|---|---|---|---|---|
| Below the Targets card | one big **map card** with speed chip and map buttons; a frosted **band** along its bottom: POSITION · DD \| ELEVATION \| SUN · ◐ 53% | **2 × 2**: POSITION · DD \| ELEVATION (ft; m · inHg), SUN · ◐ 53% (↑ rise, ↓ set) \| **MAP** tile | **3 × 2** compact tiles: LATITUDE \| LONGITUDE \| ELEVATION, SUNRISE (↑ 6:36 AM, "Sets 5:08 PM") \| MOON (53%, Last quarter) \| **PRESSURE** (still) or **SPEED** (moving) | taller Targets rows and **one summary strip**: POSITION \| ELEVATION \| SUN |
| Map | card | tile | header button | header button |
| Dial (16 Pro) | 352 | 352 | ≈ 365 (cap 0.42 H) | 386 (width cap) |
| Readout | 1.0 | 1.0 | 1.0 | 1.25 |

With no lock and no spot the Targets card is absent and its space goes to the map card or tile growth (no
empty band over 24). On iPhone 16 / 16 Pro / Pixel 7 the four layouts always differ in grid and map
surface (a golden test).

---

## 3. The planner

`Sources/Bearings/Views/LayoutPlan.swift` and `android/.../ui/LayoutPlan.kt`: one pure function each, the
same constants and steps. The screens read every frame from the plan.

1. Dial top = safe top + 18; place the fixed blocks with the frozen gaps.
2. Dial = min(layout cap, what is left). Caps: Small and Medium round8(0.40 H), Large round8(0.42 H), Extra
   Large the width cap (W − 16; W − 32 for Small and Medium). Floor **ceil(0.40 H)** everywhere.
3. Spare goes to: the layout's growth (Small map card; Medium rows 72 → 88; Large rows → 104; XL strip →
   120), then the dial up to its width cap, then at most 24 at the bottom.
4. **Short of height**, give way in this order before the dial goes under 0.40 H: tile growth → spare gaps
   (top 18 → 12, status → card 12 → 8) → Targets rows to compact height (36 pt / 40 dp) → grid density
   (Large 3 × 2 → 2 × 2 compact) → map card → header button (three tiles in one compact row) → scrolling
   list.

---

## 4. Text size

- **k ≥ 1.3:** every three-column compact row becomes two rows: Position full width, then Elevation | Sun.
  No half-width chips; times never break (non-breaking spaces, 0.85 minimum scale); the last row ends above
  the safe bottom.
- **Accessibility sizes (AX1+ / fontScale ≥ 1.5):** one scrolling list: dial (≥ 0.40 H), readout, status,
  location card (wraps), two-line Targets rows, one tile per row (caption left, value right), Map tile.

---

## 5. iPad, Mac and landscape

- **Regular-width ramp:** location card 56 (20 / 15), Targets rows 52 at 19, tiles 96, captions 13, values
  22, secondary 15, column ≤ 720.
- **iPad portrait:** one column, dial 0.40 H (480 on 11"), then location card, Targets, Position | Elevation,
  Sun | Moon and a map card (Medium).
- **Two panes** (iPad landscape, Mac wide, a phone on its side): **no full-width header**. Left: dial,
  readout, status, top-aligned at the same top spacing. Right, top-aligned with the dial: the **location
  card**, the Targets card, the grid, and a map card to the bottom (≥ 240). Right-pane spare ≤ 24.
- **Mac:** no live compass ("No heading"), hidden title bar, 24 margins; update banner under the location
  card.

---

## 6. Night and sample

Night multiplies everything by `#FF2E1F`; secondary text at 90%; the Sample pill an outline. Sample mode
is still (Large shows Pressure).

---

## 7. The Layout setting and interactions

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

## 8. Tests

Golden table (`LayoutPlan.tableFailures()`, both ports, run by self-tests and unit tests) over the existing
devices × layouts × states × k. It fails if: a portrait dial is under 0.40 H; the dial top is not safe top
+ 18 (12 after give-way); the location card is not under the status line; any gap is off its token; an
empty band exceeds 24; row widths plus gutters differ from C; the four layouts are not distinct on iPhone
16 / 16 Pro / Pixel 7 in the sample; any value ellipsizes; at k ≥ 1.3 a three-column compact row remains or a
time splits. Also: Large's sixth tile is Pressure when still and Speed when moving; "No heading" is checked
on the rendered bitmap (centred, 12 under the dial, 34 pt, white 55%).

**Launch arguments** (this launch only, never saved): Apple `--sample`, `--format <id>`, `--layout
small|medium|large|extraLarge`, `--map-sheet`, `--no-compass` (with `--sample`), `--show-terms`,
`--selftest`. Android extras: `--ez sample true`, `--es format <id>`, `--es layout <id>`, `--ez mapSheet
true`, `--ez noCompass true`, `--ez lock false`, `--ez spot false`, `--es show terms`, `--ez selftest
true`, `--ez night true`.

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
