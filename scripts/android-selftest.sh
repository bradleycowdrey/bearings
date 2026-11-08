#!/usr/bin/env bash
# Runs the Android app in the emulator (in CI): photographs the first-launch terms, runs the self-test
# with the emulator placed at Maroon Bells, Colorado (live data; the self-test also runs the layout
# planner's golden table, docs/REFINE.md A.11, and measures the rendered "No heading" words),
# then photographs the live screen, the sample place (sun, moon, a marked spot and a locked bearing) in two
# coordinate formats, night mode, larger text, every layout (the "layout" extra: small, medium, large,
# extraLarge; never saved, so the other shots stay on the Medium default), the map sheet (the "mapSheet"
# extra), the no-compass state (the "noCompass" extra) in Medium and Extra Large, the sample with nothing
# locked or marked (the "lock" and "spot" extras, false) and an accessibility font size (1.5, the
# scrolling list); docs/LAYOUTS.md §8. The self-test also draws the widget's dials (android-widget-*.png).
# Usage: scripts/android-selftest.sh <apk> <output folder>
set -uo pipefail
APK="$1"; OUT="$2"; mkdir -p "$OUT"
ID=com.bradcowdrey.bearings
adb wait-for-device
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0
# CI emulators often report their own launcher as not responding; keep those dialogs off the screenshots.
adb shell settings put global hide_error_dialogs 1 || true
# Colorado time, where the emulator is placed (it runs on UTC otherwise).
adb root >/dev/null 2>&1 && sleep 2 && adb wait-for-device
adb shell setprop persist.sys.timezone America/Denver || true
adb shell cmd alarm set-timezone America/Denver >/dev/null 2>&1 || true
adb install -r "$APK"
shot() { adb shell am broadcast -a android.intent.action.CLOSE_SYSTEM_DIALOGS >/dev/null 2>&1; sleep 1; adb exec-out screencap -p > "$OUT/$1.png"; }
launch() { adb shell am start -W -n $ID/.MainActivity "$@" >/dev/null; }
stop() { adb shell am force-stop $ID; }

# 1. First launch: the terms.
launch --es show terms; sleep 6; shot android-1-terms; stop

# 2. The self-test with a real location, then the live screen.
adb shell run-as $ID rm -f files/report.txt
adb shell pm grant $ID android.permission.ACCESS_FINE_LOCATION || true
adb shell pm grant $ID android.permission.ACCESS_COARSE_LOCATION || true
adb shell cmd location set-location-enabled true || true
adb emu geo fix -106.94117 39.09898 2925 || true
sleep 2; adb emu geo fix -106.94117 39.09898 2925 || true
launch --ez selftest true
for i in $(seq 1 100); do adb shell run-as $ID ls files/report.txt >/dev/null 2>&1 && break; adb emu geo fix -106.94117 39.09898 2925 >/dev/null 2>&1; sleep 1; done
sleep 3; shot android-2-live
adb shell run-as $ID cat files/report.txt > "$OUT/report.txt" || echo "FAILED (no report)" > "$OUT/report.txt"
# The widget's north-up dials as the self-test drew them (Small's half dial, Medium, Large, Large with no spot).
for w in widget-small widget-medium widget-large widget-large-nospot; do
  adb exec-out run-as $ID cat files/$w.png > "$OUT/android-$w.png" 2>/dev/null || rm -f "$OUT/android-$w.png"
  [ -s "$OUT/android-$w.png" ] || rm -f "$OUT/android-$w.png"
done
stop

# 3. The sample place: decimal degrees, then MGRS, then night mode (not saved, so later runs start in day mode).
launch --ez sample true --es format dd; sleep 8; shot android-3-sample; stop
launch --ez sample true --es format mgrs; sleep 8; shot android-4-mgrs; stop
launch --ez sample true --es format dd --ez night true; sleep 8; shot android-5-night; stop
# A larger font size (Settings → Display → Font size, 1.3; REFINE.md A.7): the dial stays at least 40% of
# H; a three-column compact row becomes two rows (Position full width; Elevation | Sun), times never break,
# nothing ends in "…", and the last row ends at least 16 dp above the navigation bar.
adb shell settings put system font_scale 1.3 || true
launch --ez sample true --es format dd; sleep 8; shot android-6-large-text; stop
# The same font size at Extra Large: the planner gives things up (or scrolls as one list), nothing is cut.
launch --ez sample true --es format dd --es layout extraLarge; sleep 8; shot android-10-xl-large-text; stop
# An accessibility font size (1.5 and up): one scrolling list: dial, readout, status, the location card,
# the Targets card with the cue on line 2, tiles as 96 dp rows (caption leading, value trailing), the Map
# tile; no "…".
adb shell settings put system font_scale 1.5 || true
launch --ez sample true --es format dd; sleep 8; shot android-13-ax-text; stop
adb shell settings put system font_scale 1.0 || true
# 4. Every layout with the sample place (Medium is android-3-sample): Small (big map card with its band),
# Large (3 × 2 tiles, the sixth Pressure as the sample is still; map button in the location card) and
# Extra Large (biggest dial, one summary strip). Each starts with the dial at the status bar + 18 dp.
launch --ez sample true --es format dd --es layout small; sleep 8; shot android-7-small; stop
launch --ez sample true --es format dd --es layout large; sleep 8; shot android-8-large; stop
launch --ez sample true --es format dd --es layout extraLarge; sleep 8; shot android-9-xl; stop
# 5. The map sheet (the Map tile's full-height sheet), opened at launch.
launch --ez sample true --es format dd --ez mapSheet true; sleep 10; shot android-11-map-sheet; stop
# 6. No compass with the sample place: "No heading" in words (34 sp semibold, white 55%) in the readout's
# slot, "Position, sun and map still work" under it, the dial's no-compass drawing, the location card and
# Medium's normal grid (REFINE.md A.2). Then the same in Extra Large (map button in the location card).
launch --ez sample true --es format dd --ez noCompass true; sleep 8; shot android-12-no-compass; stop
launch --ez sample true --es format dd --ez noCompass true --es layout extraLarge; sleep 8; shot android-14-no-compass-xl; stop
# 7. The sample with nothing locked or marked (as live, REFINE.md A.3): no Targets card; its height goes to
# Medium's tiles (row 1 to 88, then row 2; from 150 the Sun tile gains a Moon section); nothing is pinned above
# the dial.
launch --ez sample true --es format dd --ez lock false --ez spot false; sleep 8; shot android-15-unlocked; stop
adb shell getprop ro.build.version.release > "$OUT/device.txt"
adb shell getprop ro.product.model >> "$OUT/device.txt"
cat "$OUT/report.txt"
