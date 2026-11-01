#!/usr/bin/env bash
# Builds the iPhone and iPad app with its widget for the iOS Simulator into ./dist/ios/Bearings.app.
# (Device and App Store builds need Apple signing; see .github/workflows/ios-testflight.yml.)
# Usage: scripts/build-ios.sh [version]
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-${VERSION:-$(cat VERSION)}}"
VERSION="${VERSION##*v}"
BUILD="$(git rev-list --count HEAD 2>/dev/null || echo 1)"

command -v xcodegen >/dev/null || brew install xcodegen
xcodegen generate --quiet

LOG="$(mktemp)"
if ! xcodebuild -project Bearings.xcodeproj -scheme BearingsPhone -configuration Debug \
  -derivedDataPath build-ios -destination "generic/platform=iOS Simulator" \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD" \
  CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="" \
  build >"$LOG" 2>&1; then
  grep -E "(error|fatal):" "$LOG" | sort -u | head -25 | while IFS= read -r line; do echo "::error::${line}"; done
  tail -40 "$LOG"
  exit 1
fi

rm -rf dist/ios && mkdir -p dist/ios
cp -R build-ios/Build/Products/Debug-iphonesimulator/Bearings.app dist/ios/
test -d dist/ios/Bearings.app/PlugIns/BearingsWidget.appex || { echo "::error::The widget isn't inside the iPhone app"; exit 1; }
echo "Built dist/ios/Bearings.app ($VERSION build $BUILD) with widget"
