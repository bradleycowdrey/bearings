#!/usr/bin/env bash
# Runs the Android app in the emulator (in CI): photographs the first-launch terms, runs the self-test
# with the emulator placed at Maroon Bells, Colorado (live data), then photographs the live screen, the
# sample place (sun, moon, a marked spot and a locked bearing) in two coordinate formats, night mode,
# larger text, every layout (the "layout" extra: small, medium, large, extraLarge; never saved, so the
# other shots stay on the Medium default) and the map sheet (the "mapSheet" extra); docs/LAYOUTS.md §8.
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
# A larger font size (Settings → Display → Font size): the screen must still fit, with larger type;
# tiles grow and coordinates wrap rather than end in "…" (there is no 1.15× clamp any more).
adb shell settings put system font_scale 1.3 || true
launch --ez sample true --es format dd; sleep 8; shot android-6-large-text; stop
# The same font size at Extra Large: the planner gives things up (or scrolls as one list), nothing is cut.
launch --ez sample true --es format dd --es layout extraLarge; sleep 8; shot android-10-xl-large-text; stop
adb shell settings put system font_scale 1.0 || true
# 4. Every layout with the sample place (Medium is android-3-sample).
launch --ez sample true --es format dd --es layout small; sleep 8; shot android-7-small; stop
launch --ez sample true --es format dd --es layout large; sleep 8; shot android-8-large; stop
launch --ez sample true --es format dd --es layout extraLarge; sleep 8; shot android-9-xl; stop
# 5. The map sheet (the Map tile's full-height sheet), opened at launch.
launch --ez sample true --es format dd --ez mapSheet true; sleep 10; shot android-11-map-sheet; stop
adb shell getprop ro.build.version.release > "$OUT/device.txt"
adb shell getprop ro.product.model >> "$OUT/device.txt"
cat "$OUT/report.txt"
