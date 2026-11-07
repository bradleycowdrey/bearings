#!/usr/bin/env bash
# Runs the Android app in the emulator (in CI): photographs the first-launch terms, runs the self-test
# with the emulator placed at Maroon Bells, Colorado (live data; the self-test also runs the layout
# planner's golden table, C3.3, and measures the drawn no-heading dash against the digits' centre-line),
# then photographs the live screen, the sample place (sun, moon, a marked spot and a locked bearing) in two
# coordinate formats, night mode, larger text, every layout (the "layout" extra: small, medium, large,
# extraLarge; never saved, so the other shots stay on the Medium default), the map sheet (the "mapSheet"
# extra), the no-compass state (the "noCompass" extra) in Medium and Extra Large, the sample with nothing
# locked or marked (the "lock" and "spot" extras, false) and an accessibility font size (1.5, the
# scrolling list); docs/LAYOUTS.md §8.
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
stop

# 3. The sample place: decimal degrees, then MGRS, then night mode (not saved, so later runs start in day mode).
launch --ez sample true --es format dd; sleep 8; shot android-3-sample; stop
launch --ez sample true --es format mgrs; sleep 8; shot android-4-mgrs; stop
launch --ez sample true --es format dd --ez night true; sleep 8; shot android-5-night; stop
# A larger font size (Settings → Display → Font size, 1.3): the dial shrinks to min(C − 48, 0.36 H) so
# Position and Elevation sit whole above the fold; coordinates wrap rather than end in "…" (C3.4 #6).
adb shell settings put system font_scale 1.3 || true
launch --ez sample true --es format dd; sleep 8; shot android-6-large-text; stop
# The same font size at Extra Large: the planner gives things up (or scrolls as one list), nothing is cut.
launch --ez sample true --es format dd --es layout extraLarge; sleep 8; shot android-10-xl-large-text; stop
# An accessibility font size (1.5 and up): one scrolling list, lock and spot as one two-line Targets card,
# tiles as 64 dp rows (caption leading, value trailing), the first screen ending on a whole block, no "…".
adb shell settings put system font_scale 1.5 || true
launch --ez sample true --es format dd; sleep 8; shot android-13-ax-text; stop
adb shell settings put system font_scale 1.0 || true
# 4. Every layout with the sample place (Medium is android-3-sample).
launch --ez sample true --es format dd --es layout small; sleep 8; shot android-7-small; stop
launch --ez sample true --es format dd --es layout large; sleep 8; shot android-8-large; stop
launch --ez sample true --es format dd --es layout extraLarge; sleep 8; shot android-9-xl; stop
# 5. The map sheet (the Map tile's full-height sheet), opened at launch.
launch --ez sample true --es format dd --ez mapSheet true; sleep 10; shot android-11-map-sheet; stop
# 6. No compass with the sample place: the dash drawn as a bar on the digits' centre-line with "°" where it
# sits after 228, the note folded into the status line, the rose at 40%, Medium's normal grid and the freed
# height in the dial, then a 160 map card (C3.4 #3, #11). Then the same in Extra Large (map in the header).
launch --ez sample true --es format dd --ez noCompass true; sleep 8; shot android-12-no-compass; stop
launch --ez sample true --es format dd --ez noCompass true --es layout extraLarge; sleep 8; shot android-14-no-compass-xl; stop
# 7. The sample with nothing locked or marked (as live, C3.4 #14): the lock's 52 + 8 goes to the dial, then
# a map card; the header stays pinned at the status bar + 8.
launch --ez sample true --es format dd --ez lock false --ez spot false; sleep 8; shot android-15-unlocked; stop
adb shell getprop ro.build.version.release > "$OUT/device.txt"
adb shell getprop ro.product.model >> "$OUT/device.txt"
cat "$OUT/report.txt"
