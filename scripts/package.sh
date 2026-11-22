#!/bin/bash
#
# package.sh - builds the app (Release, universal) and packages it as a styled .dmg:
# opening it shows the app, an arrow and the Applications folder: drag to install.
#
# Usage: scripts/package.sh            → build/ScarlettGen1Mixer.dmg
# The version comes from ScarlettGen1Mixer/Version.xcconfig; the build number from
# $BUILD_NUMBER (CI run number) or the commit count.
#
# No paid Apple Developer account: the app is ad-hoc signed. On first launch macOS may
# say it can't verify the developer: System Settings ▸ Privacy & Security ▸ Open Anyway.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
PROJECT="$ROOT/ScarlettGen1Mixer/ScarlettGen1Mixer.xcodeproj"
APP_NAME="ScarlettGen1Mixer"
VOLUME="Scarlett Gen 1 Mixer"
VERSION="$("$ROOT/scripts/version.sh")"
BUILD_NUMBER="${BUILD_NUMBER:-$(git -C "$ROOT" rev-list --count HEAD 2>/dev/null || echo 1)}"

rm -rf "$BUILD"
mkdir -p "$BUILD"

"$ROOT/scripts/sync-guide.sh"
echo "==> Building $APP_NAME $VERSION ($BUILD_NUMBER) (Release)"
xcodebuild -project "$PROJECT" -scheme "$APP_NAME" -configuration Release \
    -destination 'generic/platform=macOS' -derivedDataPath "$BUILD/DerivedData" \
    CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM= \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    build > "$BUILD/xcodebuild.log" 2>&1 || {
        echo "ERROR: build failed. Errors:" >&2
        grep -E "error:|BUILD FAILED" "$BUILD/xcodebuild.log" | sort -u >&2
        exit 1
    }
tail -1 "$BUILD/xcodebuild.log"

APP="$BUILD/DerivedData/Build/Products/Release/$APP_NAME.app"
[ -d "$APP" ] || { echo "ERROR: $APP not found" >&2; exit 1; }

# Stamp the git commit into the app (shown in About and the header)
COMMIT="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
git -C "$ROOT" diff --quiet HEAD 2>/dev/null || COMMIT="$COMMIT+"   # "+" = built with uncommitted changes
plutil -create xml1 "$APP/Contents/Resources/BuildInfo.plist"
plutil -insert GitCommit -string "$COMMIT" "$APP/Contents/Resources/BuildInfo.plist"

echo "==> Ad-hoc signing"
codesign --force --deep --sign - "$APP"
codesign --verify --strict "$APP"

echo "==> Creating styled disk image"
# Detach a leftover volume with the same name from an earlier run
[ -d "/Volumes/$VOLUME" ] && hdiutil detach "/Volumes/$VOLUME" -force >/dev/null || true
TMP_DMG="$BUILD/tmp.dmg"
hdiutil create -size 80m -fs HFS+ -volname "$VOLUME" -ov "$TMP_DMG" >/dev/null
DEVICE="$(hdiutil attach -readwrite -noverify -noautoopen "$TMP_DMG" | awk '/Apple_HFS/ {print $1}')"
MOUNT="/Volumes/$VOLUME"
ditto "$APP" "$MOUNT/$APP_NAME.app"
ln -s /Applications "$MOUNT/Applications"
mkdir "$MOUNT/.background"
cp "$ROOT/packaging/dmg/background.tiff" "$MOUNT/.background/background.tiff"

# Window layout: 640×400, big icons, app left, Applications right, background art.
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$VOLUME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 840, 520}
        set opts to the icon view options of container window
        set arrangement of opts to not arranged
        set icon size of opts to 112
        set text size of opts to 12
        set background picture of opts to file ".background:background.tiff"
        set position of item "$APP_NAME.app" of container window to {170, 200}
        set position of item "Applications" of container window to {470, 200}
        close
        open
        update without registering applications
        delay 2
        close
    end tell
end tell
APPLESCRIPT

sync
hdiutil detach "$DEVICE" >/dev/null
hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -ov -o "$BUILD/$APP_NAME.dmg" >/dev/null
rm -f "$TMP_DMG"

echo "==> Done: $BUILD/$APP_NAME.dmg"
