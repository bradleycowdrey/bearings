# Bearings: layouts (compass size)

Status: final spec for implementation on Apple (SwiftUI, iOS 17 / macOS 14) and Android (Compose).
It replaces §3's "36% of the height and 360" rule and the height maths in §7–8 of
[DESIGN.md](DESIGN.md). Colours, type and tokens stay in [LOOK.md](LOOK.md). When this file and DESIGN.md
disagree about layout, this file wins. Update DESIGN.md §3 and §6–8 to point here once it ships.

The owner's brief: **the compass takes up at least 40% of the screen; there are four layouts, Small,
Medium, Large and Extra Large, chosen in the app; the other tiles are managed so the compass stays large
and in focus.**

---

## 1. The pattern in one paragraph

The screen has two parts. The **head** never scrolls: the sky, the dial, the readout ("228° SW"), the
subline and, when a spot is marked, the spot line. Everything else lives in **Details**, a scrolling area
that fills the height left under the head: a one-row **summary strip**, then the **map card**, then the
full **2×2 tiles**, then (Mac and iPad) the footer. The dial is sized **first**, as a share of the
screen height; the rest gives up space in a fixed order before the dial ever shrinks, and the dial never
goes below 40% of the screen height on a portrait phone. The layout setting changes the dial's share and
how much of Details shows before you scroll. Wide windows put Details in a column beside the dial
instead of under it.

Nothing that changes what the dial shows (marked spot, locked bearing, warnings) ever leaves the head.

---

## 2. Terms and the dial size rule

- **H**: the full height of the window. On iPhone and Android phones this is the whole screen height,
  including the status bar and home indicator (what the owner sees in a screenshot). On Apple, read it
  as `geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom` from the root
  `GeometryReader`; on Android, `LocalConfiguration.current.screenHeightDp` plus the system-bar insets, or
  simply `BoxWithConstraints` on a root that draws edge to edge.
- **S**: the safe height (H minus the safe-area insets). Everything is laid out inside S.
- **W**: the window width. **C**, the column width: `min(W, 760)` (phones: C = W).
- **e**: the dial's side margin for the layout (table below).
- **f**: the layout's share of H (table below).

```
target = min(f × H, C − 2e)
floor  = min(0.40 × H, C − 2e)          // the owner's rule, portrait single column only
dial   = target, reduced only by step 7 of the give-up order (§4), never below floor
dial   = max(dial, 140)                 // absolute floor for pathological windows
```

The old caps (`0.36`, `360`, `420` in `MainView.dialSide`; `360.dp`, `0.36` in `MainScreen.dialFor`) are
removed.

| Layout id    | Name        | f    | e  | Readout scale | Header         | Guaranteed on the first screen |
|--------------|-------------|------|----|---------------|----------------|--------------------------------|
| `small`      | Small       | 0.40 | 16 | ×1.00         | title row if it fits, sky card | strip **and** map (≥ 96) |
| `medium`     | Medium (default) | 0.44 | 16 | ×1.00    | title row if it fits, sky card | strip; the map's top edge may peek |
| `large`      | Large       | 0.48 | 16 | ×1.08         | sky card (no title row) | strip |
| `extraLarge` | Extra Large | 0.52 | 8  | ×1.15         | sky bar (44)   | strip |

Readout scale multiplies the heading number (56 pt light, 46 when S < 700) and the point letters
(28 pt). It never goes above ×1.15: the freed space goes to calm space around the dial, not a bigger
number.

### 2.1 Dial size by device (default text size, no marked spot)

Numbers are pt (dp on Pixel), then % of H. They come from running the planner in §4 with the constants in
§3; on Apple use the measured safe areas, which can move these by a few points.

| Device (W×H)                    | Small       | **Medium**      | Large        | Extra Large  |
|---------------------------------|-------------|-----------------|--------------|--------------|
| iPhone SE (375×667)             | 267 (40.0%) | **293 (44.0%)** | 320 (48.0%)  | 347 (52.0%)  |
| iPhone 16 (393×852)             | 341 (40.0%) | **361 (42.4%)** | 361 (42.4%)  | 377 (44.2%)  |
| iPhone 17 Pro Max (440×956)     | 382 (40.0%) | **408 (42.7%)** | 408 (42.7%)  | 424 (44.4%)  |
| Pixel 7 (412×915 dp)            | 366 (40.0%) | **380 (41.5%)** | 380 (41.5%)  | 396 (43.3%)  |
| iPad 11" portrait (834×1210)    | 484 (40%)   | **532 (44%)**   | 581 (48%)    | 629 (52%)    |
| iPad 13" portrait (1032×1376)   | 550 (40%)   | **605 (44%)**   | 660 (48%)    | 716 (52%)    |
| Mac window, default (420×840)   | 336 (40.0%) | **370 (44.0%)** | 388 (46.2%)  | 404 (48.1%)  |
| Mac window, minimum (380×720)   | 288 (40.0%) | **317 (44.0%)** | 346 (48.0%)  | 364 (50.6%)  |

Today, for comparison: iPhone 16 190 pt (22%), 152 pt with a marked spot.

**Tell the owner plainly:** on a portrait phone the screen's width caps the dial at about 42–46% of the
height. On modern iPhones and Pixels, Medium and Large give the same dial; Large differs by dropping the
title row and a slightly larger readout, and Extra Large by the 8 pt margins, the one-line sky bar and a
larger readout. On iPhone SE, iPad and the Mac the four layouts differ clearly in dial size.

---

## 3. What each layout shows, top to bottom

Spacing stays on the 4-pt grid. Gaps between blocks are 12 (8 when S < 700). Top padding 4, bottom 8.
Heights below are at the default text size; multiply text-driven heights by the text multiplier `k`
(today's rule: up to 1.3 on Apple, 1.4 on Android).

### 3.1 The head (never scrolls)

1. **Title row** (48 + 4): "Bearings" and the ⋯ menu, as today. Shown only at Small and Medium, and only
   when it fits (it is the first thing given up, §4). When it is absent, the ⋯ menu sits in the sky
   card's corner (the existing compact mode).
2. **Sky** — one of:
   - **Sky card** (72; 68 compact): unchanged from DESIGN.md §2.
   - **Sky bar** (44, Extra Large or after give-up step 3): one line on the same sky gradient,
     "Crested Butte · 4:12 PM": the town (without the state or country, 15 semibold) and the time (15
     regular); the date is left to the full sky card so the town keeps its room. One line, the town
     truncates last; then the sun/moon symbol, and the ⋯ menu at the right in a 44×44 target.
3. **Dial**: `dial × dial`, centred, with e on each side at minimum. Unchanged drawing.
4. **Readout**: "228°" and "SW" on one baseline, scaled by the layout's readout scale. Height =
   heading size × 1.2 (× 1.1 on Android, as today).
5. **Subline** (13, 18 high + 4): unchanged, including warnings in amber and "· Locked 240° · turn 12°
   right". Warnings never move.
6. **Spot line** (28 high, only when a spot is marked; replaces the 46–58 pt pill at every layout):
   "📍 Marked spot · 0.4 mi · 245° SW", 15 medium, white; a ✕ at the trailing end with a 44×44 pt
   (48×48 dp) hit area that reaches into the gaps above and below. The line itself is a button that
   opens a small menu: **Lock to Spot**, **Clear Marked Spot**. "Clear Marked Spot" stays in ⋯.

### 3.2 Details (scrolls under the head)

Order, top to bottom:

1. **Summary strip** (64 high, frosted like a tile, radius 16, three cells divided by hairlines):
   - **Coordinates** (two units wide): the value in the current format on two lines (lat over lon; UTM,
     MGRS and Plus Code on one or two lines as they fit), 17 medium tabular. Tap cycles the six formats;
     long-press copies (with the same "Copied" feedback as today). Dims when the fix is stale.
   - **Elevation** (one unit): "9,596 ft" (17 medium) over "2,925 m" (13, white at 60%); metres first
     when chosen.
   - **Sun** (one unit): "6:42–5:01" (15 medium, the device's 12/24-hour setting, no AM/PM) over the
     moon glyph and "82%" (13).
   - At Small and Medium the strip is **visible on the first screen** on every device in §2.1. At Large
     and Extra Large it is visible unless give-up step 6 scrolls it.
2. **Map card**: unchanged (heading cone, +, −, follow heading, open in Maps, speed chip). Height:
   - Small: fills the height left on the first screen, at least 96; if less than 96 is left it moves
     below the fold at 240.
   - Medium: 240, starting right after the strip; its top peeks when there is room.
   - Large, Extra Large: 240, below the fold.
   - The map's own gestures are already off (`interactionModes: []` on Apple,
     `setAllGesturesEnabled(false)` on Android), so it never fights the scroll.
3. **Tiles**, 2×2, exactly as today (Latitude, Longitude, Elevation, Sun with their details:
   accuracy, fix age, format name, pressure, moon phase name). Header "DETAILS" (the tiles' caption
   style) above them, marked as a heading for VoiceOver/TalkBack.
4. **Footer** (Mac and iPad only): "Made by Bradley Cowdrey · bradcowdrey.com ↗".

Scroll cues: a 16 pt fade to black at the bottom edge of Details while more is below; the scroll
indicator flashes once on appear (`.scrollIndicatorsFlash(onAppear: true)`); `.scrollBounceBehavior(
.basedOnSize)` so nothing bounces when it all fits. Changing the layout scrolls Details back to the top.

### 3.3 Per-layout summary on iPhone 16 (759 pt safe height)

| | Small | Medium | Large | Extra Large |
|---|---|---|---|---|
| Header | sky card (title row dropped: it does not fit) | title row + sky card | sky card | sky bar |
| Dial | 341 | 361 | 361 | 377 |
| Readout | 56 | 56 | 60 | 64 |
| First screen | head, strip, map (≈ 133 tall) | head, strip, top of the map | head, strip, air | head, strip, air |
| Below the fold | tiles | map, tiles | map, tiles | map, tiles |

---

## 4. The planner (one pure function, two ports)

`LayoutPlan.swift` (in `Sources/Bearings/Views/`) and `ui/LayoutPlan.kt`, the same constants and the
same order, with no UI code so both can be unit-tested.

```
input:  W, H, S, layout, k (text multiplier), accessibilityText (Bool), hasSpot, hasUpdateBanner,
        showsFooter, isLandscapePhone
output: twoPane, dial, readoutScale, header (titleRow+card | card | bar), mapOnFirstScreen,
        stripOnFirstScreen, detailsViewport, scrollsWhole
```

1. If `accessibilityText` (`dynamicTypeSize.isAccessibilitySize`; Android `fontScale >= 1.5`), use
   `max(layout, large)`'s rules for header, readout and map (dial share stays the chosen layout's).
2. If two panes apply (§7), plan that instead.
3. Start from the table in §2 and lay out the head plus the guaranteed first-screen content. The Details
   viewport must be at least **96** (1.5 strip rows) tall.
4. While it overflows S, give up in this order, one step at a time:
   1. Title row → gone (⋯ into the sky card).
   2. Inline map (Small) → below the fold.
   3. Sky card → sky bar.
   4. Readout scale → ×1.00 (46 pt heading when S < 700).
   5. Footer → About (it is in Details anyway; this only matters for the minimum viewport).
   6. Strip → allowed to sit below the fold (viewport still ≥ 96).
   7. Dial → shrinks, never below `floor`.
5. If it still overflows with the dial at `floor` (accessibility text on iPhone SE, split screen), set
   `scrollsWhole`: the head and Details become one scroll view, the dial stays at `floor`. Nothing is
   ever clipped or overlapped.

Large text (k = 1.3, marked spot) still keeps every layout above 40% on every device in §2.1; the planner
only drops the title row, the inline map, the sky card (to the bar) or the readout scale. Example: iPhone
SE Extra Large drops the readout scale and the dial goes 347 → 336 (50.4%).

---

## 5. Interactions

| Action | Result |
|---|---|
| Tap the dial | Lock / unlock the bearing (unchanged). Never changes layout or scroll. |
| Pinch the dial (optional; ship last) | Steps one layout per gesture: scale > 1.12 up, < 0.89 down; selection haptic; toast "Layout: Large". Apple `MagnifyGesture` simultaneous with the dial's Button; Android a two-pointer-only `pointerInput` next to `clickable`. If it misfires against tap on hardware, leave it out. |
| Tap the strip's Coordinates cell, or the Latitude/Longitude tile | Next of the six formats. |
| Long-press either | Copy, "Copied" for 1.2 s. Mac: right-click context menu "Copy Coordinates". Android 13+: no toast (the system shows its own). |
| Tap the Elevation or Sun cell | Scrolls Details to the tiles. |
| Tap ✕ on the spot line | Clear the marked spot. |
| Tap the spot line | Menu: Lock to Spot · Clear Marked Spot. |
| Map controls | Unchanged, wherever the map card is. "Open in Maps" is also added to ⋯. |
| Scroll Details | Only Details moves; the head stays. |

Pull the coordinate tap/long-press logic out of the Longitude tile into one shared view,
`CoordinateText` (Swift) / `CoordinateText()` (Compose, today's `combinedClickable` in `MainScreen.kt`),
used by the strip and the tiles so they behave identically.

---

## 6. The Layout setting

- **Name in the UI:** "Layout". Options: **Small, Medium, Large, Extra Large**.
- **Persisted key:** `"layout"`; values `small`, `medium`, `large`, `extraLarge`. Unknown or missing →
  `medium`.
  - Apple: `Navigator` gains `@Published var layout: Layout { didSet { defaults.set(layout.rawValue,
    forKey: "layout") } }`, read in `init` next to `format`. `enum Layout: String, CaseIterable { case
    small, medium, large, extraLarge }`.
  - Android: the same enum in Kotlin, stored in the existing `prefs` under `"layout"`, exposed from the
    navigator like `format`.
- **Default:** Medium on every platform and device (Mac included).
- **Menu placement:** the first group in the ⋯ menu.
  - Apple: `Picker("Layout", selection: $nav.layout)` with `.pickerStyle(.menu)` inside a `Menu("Layout")`,
    so it shows as a submenu whose subtitle is the current choice; a checkmark on the current option.
  - Android: a "Layout" header item followed by four radio-checked items in the DropdownMenu, the same
    `Check` style as the other groups.
- **Live preview:** choosing an option animates the layout with a 0.35 s spring
  (`.animation(.spring(duration: 0.35), value: nav.layout)`; Compose `animateDpAsState` with a spring).
  With Reduce Motion (Android: animator duration scale 0), it changes without animation.
- **Mac:** a "View › Layout" command menu with the four options and **⌘=** larger, **⌘−** smaller,
  **⌘0** Medium.
- The setting is a **target**: the planner (§4) may give things up on a small window or with large text,
  but never takes the dial below 40% of H in a portrait single column.
- No coach marks or onboarding hints.

---

## 7. iPad, Mac and landscape: two panes

**When:** `W ≥ 700 && W > H` (iPad landscape, wide Mac windows, Android tablets and foldables at
≥ 600 dp wide in landscape), or a phone in landscape (`S < 480`).

**Layout:** a plain `HStack` / `Row` (not `.inspector`, not `NavigationSplitView`, not
`material3-adaptive`):

- **Leading pane:** the head (sky card or bar, dial, readout, subline, spot line), centred vertically.
  `dial = min(paneWidth − 48, S − headBelowDial − headerHeight − 2 × gap)`.
- **Trailing column:** the title row "Bearings" with ⋯ (when it fits), then Details (strip, map, tiles,
  footer) in a scroll view. Width = `clamp(W × c, 300, 440)` with c = **0.50 / 0.45 / 0.40 / 0.35** for
  Small / Medium / Large / Extra Large. So the setting still changes the dial: a narrower column gives the
  dial pane more width.
- The 40% floor is automatically met in two panes (the dial is sized by height); assert it in tests.

**iPad portrait** and the **default Mac window (420×840)** use the single column of §3 with `C =
min(W, 760)`. The Mac window keeps its minimum of 380×720 and ideal 420×840.

**Mac has no live compass**: the dial is static with `noCompassText`. The setting still applies; Medium
is the default.

---

## 8. Accessibility

- **Dial** (one element): label "Compass"; value "Heading 228 degrees, southwest. True north. Sun 245
  degrees, up. Moon 110 degrees, down. Marked spot 0.4 miles at 245 degrees. Locked 240, turn 12
  right." (parts present only when they apply; announcements stay rate-limited as today).
  - Custom actions: **Lock Bearing / Unlock Bearing**, **Larger Compass**, **Smaller Compass** (the
    last two step the layout setting; disabled at the ends). Android: `CustomAccessibilityAction`s with
    the same names.
- **Strip cells**, each one element with the full text, e.g. "Coordinates, 39.09898 north, 106.94117
  west, decimal degrees" with actions **Next Format** and **Copy**; "Elevation, 9,596 feet, 2,925
  metres, from GPS, pressure 1,013 hectopascals"; "Sun, rises 6:42 AM, sets 5:01 PM, moon waxing gibbous,
  82 percent".
- **Spot line**: "Marked spot, 0.4 miles, 245 degrees southwest"; actions **Lock to Spot**, **Clear**.
- **Reading order:** sky, dial, readout + subline (one element), spot line, Details heading, strip,
  map, tiles, footer.
- **Touch targets:** at least 44×44 pt on iOS, 28×28 pt on macOS, 48×48 dp on Android: the ⋯ menu in
  every header, the spot ✕, strip cells (64 tall), map controls (32 visual circles with 44 hit areas, as
  today).
- **Contrast:** any text that carries information is at least 4.5:1 against its background (white at 60%
  on the frosted tile passes; do not go lower). Nothing important is only in 13 pt muted text: the muted
  second lines in the strip repeat or extend what is in the first line or in the tiles.
- **Text size:** all text scales with Dynamic Type / font scale. Layout uses `k` (capped at 1.3 Apple,
  1.4 Android) for heights; at accessibility sizes (§4 step 1) the strip becomes a vertical list via
  `ViewThatFits` (Apple) or a width check (Compose), the coordinate cell wraps, and the heading number is
  capped at `.accessibility2`. Details takes up the extra length by scrolling.
- **Night mode:** the red multiply covers the whole stack, Details and the sky bar included.

---

## 9. Android specifics

- `MainScreen.kt`: replace `dialFor` with `LayoutPlan.plan(...)`. Structure:
  `Column(head…, Box(Modifier.weight(1f)) { Column(Modifier.verticalScroll(state)) { strip, map, tiles } })`;
  when `scrollsWhole`, one `verticalScroll` around everything.
- Two panes via `BoxWithConstraints` (`maxWidth >= 600.dp && maxWidth > maxHeight`, or height < 480 dp).
  No new dependency.
- Not used: `BottomSheetScaffold` (experimental, focus quirks), `ModalBottomSheet` (scrim blocks the
  dial), `HorizontalPager` (TalkBack page-focus bug, issuetracker 354109776).
- `MainActivity.kt`: read `intent.getStringExtra("layout")` next to `format` and `night`, applied
  **without saving** (like `night`), so CI runs don't change the stored choice.

## 10. Apple specifics

- `MainView.swift`: replace `dialSide`, `columnHeight`, `isCompact` and `mapMinimum` with
  `LayoutPlan`. Head in a `VStack`; Details in a `ScrollView` below it.
- **ImageRenderer cannot draw a `ScrollView`, sheet, menu or MapKit `Map`.** Add an environment value
  `\.flatDetails` (default false). When true, Details is a plain `VStack` clipped to the viewport instead of
  a `ScrollView`. `Mac/SelfTest.swift` sets it. MapKit still renders blank there, as today.
- `BearingsPhoneApp.swift` / `PhoneLaunch`: `--layout <id>` next to `--format`, applied without saving.
- Mac: `BearingsMacApp.swift` adds the View › Layout commands; `--layout <id>` is honoured with
  `--selftest`.

---

## 11. CI and self-tests

**Launch argument:** `--layout small|medium|large|extraLarge` (iPhone, iPad, Mac). Android extra:
`--es layout <id>`. Neither is saved.

**Unit tests (new; the first real layout tests):**
- `Tests/BearingsTests/LayoutPlanTests.swift` and `android/app/src/test/java/com/bradcowdrey/bearings/LayoutPlanTest.kt`,
  the same table: devices {iPhone SE, iPhone 16, iPhone 17 Pro Max, iPad 11" and 13" in both
  orientations, Mac 380×720 and 420×840, Pixel 7, phone landscape} × 4 layouts × k {1.0, 1.3,
  accessibility} × {no spot, spot} × {no update banner, banner}.
- Assert: in portrait single column, `dial ≥ 0.40 × H` (within 0.5 pt); the head plus the guaranteed
  content does not overflow S unless `scrollsWhole` is set; the Details viewport is ≥ 96 unless
  `scrollsWhole`; the dial never exceeds `C − 2e`; Medium is the default.

**Mac self-test (`Mac/SelfTest.swift`):** keep every existing check and file name.
- `mac-main.png` and `mac-night.png`: Medium at 420×840 (unchanged names; the image changes once).
- Add `mac-layout-small.png`, `mac-layout-large.png`, `mac-layout-extraLarge.png` at 420×840 and
  `mac-layout-extraLarge-min.png` at 380×720.
- Keep the "more than 3 colours" check on each image, and add: run the planner table and fail the
  self-test if any case breaks the 40% floor.

**iPhone and iPad (`.github/workflows/ios.yml`, `run_on` and the large-text block):** keep
`-1-terms`, `-2-sample`, `-3-mgrs`, `iphone-4-live`, `iphone-5-large-text` (all at the Medium default).
Add per device:
- `$P-6-small.png`: `--sample --layout small`
- `$P-7-large.png`: `--sample --layout large`
- `$P-8-xl.png`: `--sample --layout extraLarge`
- `iphone-9-xl-large-text.png`: extra-extra-large Text Size, `--sample --layout extraLarge`
- `ipad-9-landscape.png` if the simulator can be rotated (`--sample`, two panes)

**Android (`scripts/android-selftest.sh`):** keep `android-1-terms` … `android-6-large-text`. Add
`android-7-small` (`--ez sample true --es layout small`), `android-8-large`, `android-9-xl`, and
`android-10-xl-large-text` (font scale 1.3, `--es layout extraLarge`). `SelfTest.kt` writes the
planner's result for the running screen (dial, % of H, layout) to `report.txt` and reports FAILED if the
dial is under 40% of H in portrait.

**App Store (`.github/workflows/app-store.yml`):** pass `--layout medium` explicitly to every shot. Keep
exactly 6 screenshots. The images change once because the default dial grows (Pro Max: about 291 → 408).

**Web (`docs/app.html`):** follows later with the same table, key and order; not part of this change.

---

## 12. Phase 2 (only if testing shows people miss the map)

A tray inside the layout (`safeAreaInset(edge: .bottom)`; Compose a `Box` overlay), **not** a sheet:
a 44-pt handle "Map & details ⌃" that shows the live heading, two fixed heights toggled by tap (no
hand-written drag at first), with a plain scroll view inside holding the map and tiles. Its handle's
accessibility value carries elevation and sun times; hidden content is removed from focus. Ship only
after owner testing.

---

## 13. Why (best-practice evidence)

- **The compass apps that people rate highest never shrink the dial to fit tiles.** Apple Compass gives
  the dial roughly 40–45% of the screen with a short list of facts under it (heading, place,
  coordinates, elevation; touch-and-hold copies the coordinates). Trail Sense, GPS Status & Toolbox and
  Commander Compass give the dial about half the screen and put the extra data on the ring or close
  around it. Bearings already draws the sun, moon, marked spot and locked bearing on the dial, so the
  dial carries the most important information itself.
- **Hero first, details in a scroll below** is how Apple Weather presents a large hero and cards (the
  same structure as Two Degrees), and the native, accessible pattern for "more than fits": Dynamic Type at
  200% and Android font scaling only make the scroll longer. Nothing is squeezed out or hidden behind a
  gesture.
- **A fixed set of named sizes, not a slider**, follows WidgetKit's model (small sizes show only the
  most critical data, larger ones add detail) and the familiar Small / Medium / Large / Extra Large
  wording. A setting in a menu is discoverable; a pinch is only a shortcut (Apple and Android both warn
  against gesture-only features).
- **Why not a pull-up sheet:** Apple's HIG says sheets on macOS are always modal and dim the window,
  and that an app should show one sheet at a time (Bearings' Terms, About and Share would collide);
  `interactiveDismissDisabled` has reported regressions on iOS 18.1+; ImageRenderer cannot draw sheets,
  so the Mac self-test would lose the tiles. Material's `ModalBottomSheet` blocks the screen behind it and
  `BottomSheetScaffold` is still experimental.
- **Why not swipeable pages:** `TabView(.page)` does not exist on macOS; page dots are easy to miss; the
  Compose pager has a TalkBack focus bug (issuetracker 354109776); and coordinates would no longer be
  visible at a glance.
- **Two panes on wide screens** follow Android's window size classes (and its warning that phones in
  landscape need the height checked too) and iPadOS/macOS practice of a content column beside the main
  view.
- **Accessibility minimums:** 44×44 pt (iOS), 28×28 pt (macOS), 48×48 dp (Android) touch targets; text
  that scales; 4.5:1 contrast; and nothing important only behind a hidden page or collapsed panel.

Sources: Apple HIG (Sheets, Page Controls, Accessibility, Layout); SwiftUI docs for `presentationDetents`,
`scrollTargetBehavior`, `PageTabViewStyle`, `ViewThatFits`, `containerRelativeFrame`, `WidgetFamily`;
Android developers: window size classes, bottom sheets, Pager, accessibility; Trail Sense navigation
guide; Gadget Hacks and Mytour on Apple Compass; Sound & Vision on GPS Status & Toolbox; onX and Gaia GPS
compass-mode help; Tom's Guide and 9to5Mac on iOS 18 Weather; Apple developer forum threads 767475 and
767056.
