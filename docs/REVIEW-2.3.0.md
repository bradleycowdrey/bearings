# Bearings 2.3.0 review: improvements, UI first

Reviewed from the CI screenshots of main (7fa3907) and the code. 59 verified findings, merged into the 53 items below.
Nothing here reverses an owner decision: the dial drawing, the "228° SW" readout, the status line, the colours, the 40% dial, the four layouts, the slim location bar, the single Targets card, the widget designs and the icon all stay.
Effort: S = about an hour or less, M = half a day to a day, L = several days.

## 1. Verdict

The main screen is in good shape on iPhone at default text size: Medium, Large and Small read as one finished instrument panel, and the bar, dial, readout and Targets card are consistent on every Apple device.
The weak spots are at the edges of the design, not the centre:

- **Android is a step behind iPhone.** The map shows white blocks instead of place names, two layouts look clipped at the bottom, and the map sheet blanks the status bar. All of this comes from emulator screenshots; a real phone has not been checked.
- **Extra Large and the "No heading" state have holes.** Extra Large has the biggest dial but the same small numbers in a half-empty strip. "No heading" (what every Mac shows, always) leaves gaps and unused space.
- **Large text falls off a cliff.** One notch above the default sizes the app becomes a scrolling list, and that list has two visible glitches.
- **The small and medium widgets** have sun and moon marks that look like drawing errors.
- **The web app and the README screenshot** still show the design from two redesigns ago.

## 2. UI improvements

### Fix now (looks broken or misleads)

1. **Android map: white blocks where place names should be** (Map tile, Small's map card, Map sheet). The built-in safety check reports a pass while the blocks are drawn. Fix: check the picture the map actually draws and hide the names if blocks appear; drop names in the small Map tile altogether; make the test fail on blocks. Check on a real phone first. *Android, M.*
2. **Android Large and Small look cut off at the bottom.** A "more below" fade is drawn over the last tiles, so their bottom edge disappears although nothing scrolls. Fix: make both layouts fit exactly, only show the fade when there is real overflow (more than 8 dp), and add a test that the four layouts never overflow. *Android, S-M.*
3. **Android Map sheet: the status bar is a plain black band** with no clock, Wi-Fi or battery. Fix: set the sheet's status icons to light. *Android, S.*
4. **Android "no compass" dial shows a crossed-out map pin**, which means "location off" while the line below says position still works. Fix: use the crossed-out compass icon. *Android, S.*
5. **iPhone large text: a hard line cuts the last card.** In the scrolling list the bottom fade stops short, so the Position card looks like two broken cards near the home indicator. Fix: run the fade to the bottom of the screen. *iPhone, S.*
6. **Medium Map tile: scraps of grey text under "MAP".** It is the top of Apple's "Legal" link poking out; it is in the first App Store screenshot too. Fix: push it fully out of the tile, or show it properly beside the Apple Maps mark. *iPhone/iPad, S.*
7. **Small layout shows the wrong moon shape.** The band always draws a half moon, whatever the phase, next to e.g. "1%". Fix: draw the real phase as Medium does. *iPhone/iPad/Mac, S.*
8. **The sample shows two different pressures:** 21.04 inHg / 712 hPa on Apple, 21.29 / 721 on Android (a typo with swapped digits). Fix: set Android to 712.4. *Android, S.*
9. **Small widget: the sun and moon marks at the edges look like glitches** (a bent hook under the sun, a "<" stuck to the moon, both touching the widget edge). Fix: one clean small arrow per mark, clear of the glyph and at least 6-10 pt from the edge; skip bodies below the horizon. *iOS/Mac/Android widgets, S.*
10. **Medium widget: the sun or moon sits on top of the N/E/S/W letters** when it is near a cardinal direction. Fix: move the sun and moon slightly further in on the medium dial. *iOS/Mac/Android widgets, S.*

### Polish (clearly better)

11. **Extra Large strip is hollow.** Position / Elevation / Sun have captions at the top, values at the bottom and 40-55 pt of nothing between; the values are no bigger than Medium's. On Android the values hug the top instead and the bottom is empty (a tall slab with no compass). Fix on all platforms: larger values in Extra Large (about 20-26 pt) placed just under the caption, or cap the strip at about 88 pt and give the rest to the dial; make Android match Apple (alignment, inset dividers, same column widths). *All, S.*
12. **"No heading" floats.** The words sit in a slot sized for the big readout, so there is a 35-50 pt gap before "Position, sun and map still work" (worst on iPad), and space is left over at the bottom. Fix: size the slot to the words, put the status line right under them, and give the freed space to the dial or tiles. *iPhone/iPad/Mac, S-M.*
13. **Mac window looks like its content does not fit.** A Mac never has a compass, and in that state there are about 34 pt above the dial and about 70 pt empty at the bottom. Fix: let the dial grow into the spare space before centring. *Mac, S.*
14. **iPad landscape and wide Mac windows: empty band under the status line** in the left pane (about 60-115 pt in Small and Medium). Fix: centre the dial, readout and status in the left pane, or let the dial take the space. *iPad/Mac, S.*
15. **iPad Small: the Position / Elevation / Sun band uses phone-size type** (13 pt) next to 19-22 pt everywhere else. Fix: caption 13, values 19-20, band 88 pt tall on iPad. *iPad, S.*
16. **Text Size one notch up loses the one-screen layout.** At "extra-extra-large" (not an accessibility size) the screen already becomes the scrolling list. Fix: first try one-line Targets rows and compact two-row tiles; keep the list for accessibility sizes only. Also make the CI large-text screenshot differ from the accessibility one (today they are the same picture). *iPhone, M.*
17. **Large-text list: the Sample pill forces "Maroon Bells, Colorado" onto two lines** and hangs between them. Fix: keep the pill on the date line, as at normal sizes. *iPhone, S.*
18. **Android: the marked-spot pin hangs over the dial's rim** towards the readout. Fix: move it inside the tick ring as on iPhone. *Android, S.*
19. **Android: the dial's crosshair and centre rings are nearly invisible** (drawn in raw pixels). Fix: draw them at 1 and 1.5 dp so they match iPhone. A unit fix, not a design change. *Android, S.*
20. **Small band and Extra Large strip disagree with the other layouts.** On iPhone Small, "2,922 m" is white like the main value (grey elsewhere and on Android); the Extra Large captions drop the format name and moon percentage. Fix: secondary line always grey; captions "POSITION · DD" and "SUN · 53%" in Extra Large. *iPhone/iPad/Mac, S.*
21. **Nothing reacts under a pointer or a finger press.** On Mac and iPad with a trackpad, tiles, rows and bar buttons do not highlight and have no tooltips; on iPhone tiles show no pressed state. Fix: one shared button style with a light highlight on press and hover, plus Mac tooltips ("Click for the next format", "Open the map"). *iPhone/iPad/Mac, S-M.*
22. **Widgets use pink for the marked spot and lock; the app uses white** (LOOK.md: "pink means north and nothing else"). The medium widget never says what the lock mark is, and it hangs outside the rim. Fix: draw them white, keep the lock mark inside the rim, label it ("Locked 240°") in the medium and large widgets. *All widgets, M.*
23. **Empty widgets are a black box with one line of text.** Fix: show the dial outline, the bar reading "Bearings" and the message where the tiles would be. *All widgets, M.*
24. **Widget time looks like a clock but is the time of the last reading,** so it is often 20-60 minutes "wrong". Fix: label it "as of 6:57 PM". *All widgets, S.*
25. **Android Map sheet shows "3.2 mph" in the still sample;** every other place hides speed in the sample. One-line fix. *Android, S.*
26. **Android Small: the short map card is crowded** with four buttons and a large "© OpenStreetMap" pill. Fix: three buttons (+, -, more) and the compact "© OSM" on short cards. *Android, M.*

### Later (nice to have)

27. One-line Position formats (MGRS, Plus Code) sit at the tile bottom, not level with "9,587 ft". Anchor the first line under the caption. *iPhone, S.*
28. Medium with no Targets: the two tile rows are 88 and 176 pt and the Moon section has uneven gaps. Even out the spacing. *iPhone, S-M.*
29. Terms screen: the sentence ends "...Privacy at" with the link alone below, duplicating "Read the Terms"; the block sits low. Reword to one sentence and move it up. *iPhone, S.*
30. iPad landscape, Large and Extra Large: a 44 pt hole in the location bar where the hidden map button was, so the sun glyph jumps between layouts. *iPad/Mac, S.*
31. Pro Max phones: about 35 pt unused under the tiles in Medium and Extra Large. Let the dial or tiles absorb it. *iPhone, S.*
32. Mac: the map opens in a fixed sheet wider than the window and cannot be enlarged. Open it in its own resizable window. *Mac, M.*
33. Mac/iPad resizable windows: all type jumps from phone size to tablet size at 700 pt. Make it grow smoothly. *Mac/iPad, M.*
34. 13-inch iPad portrait: content is a 720 pt column with wide black sides, and the Extra Large dial overhangs it. Add a 13-inch screenshot to CI first, then widen the column. *iPad, S.*
35. Mac wording: "No heading / Position, sun and map still work" reads like a fault on a machine that never has a compass. A Mac-only wording would help, but it touches the status line, so it needs the owner's say-so. *Mac, S.*
36. Android: the remove "x" in the Targets card is small and faint (make it 20 dp, 70% white); at the largest text the status line wraps with a stray "·" at the end of line one (break before the dot; wording unchanged). *Android, S.*
37. Large widget with no target: tiles stretch and the dial floats. Give the freed space to the dial. *iOS/Mac widgets, S.*
38. Icon at 29-40 px: the ring and the pink N tick fade away. Thicker ring, longer needle, fewer ticks at small sizes (no crimson band). *All, S.*
39. Apple/Android differences: Targets text sizes differ; pinch-to-change-layout is Apple only; the lock row has no tap menu although the docs promise one; a lock cannot be cleared from the dial once the compass drops. Pick one behaviour for both. *All, M.*

## 3. Other items (web, listing, accessibility, code)

### Fix now

40. **Web app is two redesigns behind** and is the hero of the product page: brown background, old header, separate Latitude/Longitude tiles, no Targets card, pink marks, crimson band, small dial. Restyle to the 2.3.0 Medium layout; at minimum colours, location bar, captions, status wording and Targets card. *Web, L (minimum pass M).*
41. **README screenshot shows the 0.1.0 screen.** Replace it with the current CI shot, fix the alt text, and have CI write it so it cannot go stale. *Docs, S.*

### Polish

42. **App Store screenshots:** every shot carries the orange "Sample" pill; the three iPhone shots are the same scene in three layouts; the iPad status bar says "Sat Nov 7" above a bar saying "Sun, Nov 1". Hide the pill for store shots, match the dates, and show different things (main screen, map, night, widgets). Captions are the owner's call. Re-shoot after items 6 and 11. *Listing, M.*
43. **App Store text:** the widgets line omits the compass widgets, the four layouts are not mentioned, "stays on your iPhone" should be "on your device", and keywords repeat the subtitle while missing widget, bearing, waypoint. *Listing, S.*
44. **Product page:** crimson bar and brown background, no bullets for layouts or compass widgets, share image is just the icon, iPhone card says "soon". *Web, S.*
45. **TalkBack reads the whole dial description again and again** while turning. Announce only "228 degrees, southwest", at most every 4 seconds, as on iPhone. Not yet tried on a device. *Android, S.*
46. **VoiceOver never hears "Coordinates copied" or "Layout: Large".** Announce them; also fix a repeated message vanishing early. *Apple, S.*

### Later

47. **Tests miss what is drawn:** iPad landscape, wide Mac windows, the large-text list and Android's composed screens are planned but never checked as pictures, which is how several items above passed CI. Extend the checks step by step. *M.*
48. **CI saves iPad landscape screenshots sideways.** Rotate them before upload. *S.*
49. **Android widgets are only tested as bare dials;** the header, tiles and empty state are never rendered. Add whole-widget screenshots. *M.*
50. **Stale comments and docs** describe the old screen order and old wording. One tidy-up pass. *S.*
51. **Two differing copies of the web app** (web/app.html and docs/app.html). Keep one source and build the other. *S.*

## 4. Suggested release scope

**2.3.1 (fixes, about a week of small jobs)**
- All of "Fix now": items 1-10, plus 41 (README screenshot).
- The small polish items that remove obvious gaps: 11, 12, 13, 14, 15, 17, 18, 19, 20, 24, 25.
- Accessibility quick wins: 45, 46.
- Guard rails so these stay fixed: the Android overflow test and map-blocks test (in 1 and 2), the large-text screenshot check (in 16), rotated landscape shots (48).
- Then re-shoot the App Store screenshots without the Sample pill and with matching dates (the firm part of 42) and update the listing text (43).
- Before release: look at the Android map and Map sheet on a real phone (items 1 and 3 are from emulator pictures).

**2.4 (larger pieces)**
- Web app restyle to the 2.3.0 look, product page refresh, one copy of the web app (40, 44, 51).
- Large text stays on one screen (16).
- Pointer and press feedback everywhere; resizable Mac map window; smooth type scaling (21, 32, 33).
- Widgets: white target marks with labels, proper empty state (22, 23, 37).
- New App Store screenshot set with map, night and widgets (rest of 42).
- Android map card tidy-up and Apple/Android parity decisions (26, 39).
- 13-inch iPad review, wider test coverage, whole-widget Android shots (34, 47, 49).
- Remaining small items as time allows: 27-31, 35 (needs owner sign-off), 36, 38, 50.
