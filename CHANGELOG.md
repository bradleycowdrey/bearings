# What's new in Bearings

On a Mac, Bearings shows a banner when a new version is out. Every version is on
[Releases](https://github.com/bradleycowdrey/bearings/releases).

## [2.3.1] - 2026-11-09

Fixes and polish for the new instrument panel, and the Mac and web apps brought up to the same design.

- **Android map**: place names no longer show as white blocks, the Large and Small layouts no longer look
  cut off at the bottom, and the map sheet keeps its clock, Wi-Fi and battery icons.
- **Extra Large** shows bigger numbers in its summary row, with the format and moon percentage in the
  captions, on every platform.
- **"No heading"** sits right above its status line, and the space it frees goes to the compass. On a Mac
  and on iPad in landscape the compass now fills the room it has.
- **Mac**: the window opens at a size every layout fills, a taller window gains a map card, tiles and
  buttons highlight under the pointer and have tooltips, and View has Show Map.
- **Small layout**: the moon is drawn in its real phase, and the second line of each value is grey as
  everywhere else. On iPad its Position, Elevation and Sun band uses iPad-size type.
- **Widgets**: cleaner sun and moon marks that stay clear of the edge and of N, E, S and W, and the time
  now reads "as of 6:57 PM", because it is the time of the last reading.
- **Web app**: redrawn to match the phones: the location bar, the big compass, the Targets card and
  labelled tiles, in the same colours.
- **Large text** on iPhone: the Sample label stays on the date line, and the list fades cleanly at the
  bottom of the screen.
- **Android**: the marked-spot pin sits inside the dial, the dial's fine lines are visible, the
  "no compass" dial shows a crossed-out compass, and the sample shows one pressure everywhere.
- **Screen readers**: VoiceOver announces "Coordinates copied" and layout changes; TalkBack reads only the
  heading as you turn.
- App Store listing: new screenshots without the Sample label, and text that mentions the compass widgets
  and the four layouts.

## [2.3.0] - 2026-11-08

A new instrument panel, compass widgets and a cleaner icon.

- **The instrument panel**: a slim location bar at the top, then the big compass, its reading and
  status, then one **Targets** card for your locked bearing and marked spot, and labelled tiles below.
- **Four layouts**, each its own: Small (compass and a big map), Medium (the standard: compass and a
  2 × 2 of position, elevation, sun and map), Large (six compact tiles) and Extra Large (the biggest
  compass with one summary row). The compass is always at least 40% of the screen.
- **No compass?** It says "No heading" plainly, and position, sun and map still work.
- **Widgets that look like the app**, with a north-up compass showing where the sun, the moon, your
  marked spot and your locked bearing lie. On the Lock Screen: elevation, place and coordinates.
- **A cleaner icon** without the top band.
- Large text, iPad, Mac windows and night mode all follow the new layout. Android map labels fixed.

## [2.2.0] - 2026-11-07

The compass comes first.

- **A much bigger compass**: at least 40% of the screen on a phone, nearly twice as wide as before on a
  typical iPhone. Your place, heading, warnings and marked spot stay at the top; everything else scrolls
  below it.
- **A summary row** under the compass: your coordinates (tap to switch format, hold to copy), elevation,
  sunrise and sunset. The map and the full tiles follow.
- **Four layouts**, in the menu under Layout: Small, Medium (the default), Large and Extra Large. Pinch the
  compass to change it; on the Mac, View › Layout (⌘=, ⌘−, ⌘0).
- **iPad, Mac and phones on their side** show the compass beside the details.
- The marked spot is one line: tap it to lock to the spot or clear it.

## [2.1.0] - 2026-11-07

A new look, in the style of Two Degrees.

- **Black, with a sky card**: a large Bearings title, and a card for the place, date and time whose colour
  follows the real sun where you are: blue by day, twilight at dusk, deep navy at night.
- **The dial on black**: white ticks and letters, with pink kept for north.
- **Frosted tiles** with small captions: Latitude, Longitude, Elevation and Sun.
- **Widgets** in the same style, on iPhone, iPad, Mac and Android.
- **A new icon** in the app's colours: the sky, a white dial and pink north.
- On a small screen or with a larger text size, the title makes way so the dial stays big.
- The iPhone app includes Apple's privacy manifest.

## [2.0.0] - 2026-11-01

The first public release of Bearings: get your bearings, on one screen.

- **The compass**: 228° SW under a fixed line, turning the short way past north, with a light tick at N, E,
  S and W. True north by default, with the declination; magnetic north if you prefer.
- **Where and when**: the town you're in, or how far you are from the nearest one, with the date and time.
- **Six coordinate formats**: decimal degrees, DMS, decimal minutes, UTM, MGRS and Plus Codes. Tap to
  switch; hold to copy; share your location.
- **Elevation in feet and metres at once**, from GPS when it's accurate, otherwise terrain data, with air
  pressure where your device has a barometer.
- **The sun and moon on the dial**, with sunrise, sunset and the moon's phase.
- **Mark a spot and find it again**: its direction on the dial and how far it is.
- **Lock a bearing**, and a **bubble level** in the middle of the dial.
- **A map** with your heading, north up or following you; satellite on iPhone, iPad and Mac.
- **Honest accuracy**: ± for position and heading, a figure-8 hint only when needed, a warning near
  magnets and metal, and your speed as you move.
- **Night mode**: all red, to keep your night vision.
- **Widgets**: iPhone and iPad Home Screen and Lock Screen, Mac desktop, Android Home Screen.
- On iPhone and iPad, Android, Mac (no compass) and the web at bradcowdrey.com/bearings.
- Free and open source. No ads, no account, no tracking.
