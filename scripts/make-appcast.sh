#!/bin/bash
#
# make-appcast.sh - signs the update zip and writes build/appcast.xml (the Sparkle update feed).
# Run after scripts/package.sh.
#
# Usage: scripts/make-appcast.sh <private-key-file>   (CI: the SPARKLE_PRIVATE_KEY secret)
#        scripts/make-appcast.sh --keychain           (local: the key generate_keys stored)
#
# The app reads the feed from the latest GitHub release (SUFeedURL in ScarlettGen1Mixer/Info.plist)
# and installs an update only if its signature matches SUPublicEDKey.

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/DerivedData/Build/Products/Release/ScarlettGen1Mixer.app"
ZIP="$BUILD/ScarlettGen1Mixer.zip"
REPO="https://github.com/jcksnvllxr80/scarlett-gen1-mixer"
[ -f "$ZIP" ] || { echo "ERROR: $ZIP not found; run scripts/package.sh first" >&2; exit 1; }

VERSION="$("$ROOT/scripts/version.sh")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP/Contents/Info.plist")"
MIN_OS="$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$APP/Contents/Info.plist")"
SIGN_UPDATE="$(find "$BUILD/DerivedData/SourcePackages/artifacts" -path "*/Sparkle/bin/sign_update" | head -1)"
[ -x "$SIGN_UPDATE" ] || { echo "ERROR: Sparkle's sign_update not found" >&2; exit 1; }

# Prints: sparkle:edSignature="…" length="…"
if [ "${1:-}" = "--keychain" ]; then
    SIGNATURE="$("$SIGN_UPDATE" --account scarlett-gen1-mixer "$ZIP")"
else
    SIGNATURE="$("$SIGN_UPDATE" -f "${1:?private key file or --keychain}" "$ZIP")"
fi

# This version's section of RELEASE_NOTES.md as simple HTML (bullets and **bold**)
NOTES="$(awk -v v="## $VERSION" '$0 == v {on=1; next} /^## / {on=0} on' "$ROOT/RELEASE_NOTES.md" | python3 -c '
import html, re, sys
out, in_list = [], False
for line in sys.stdin.read().strip().splitlines():
    text = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", html.escape(line.strip()))
    text = re.sub(r"`(.+?)`", r"<code>\1</code>", text)
    if line.startswith("- "):
        if not in_list: out.append("<ul>"); in_list = True
        out.append("<li>" + text[2:] + "</li>")
    elif text:
        if in_list: out.append("</ul>"); in_list = False
        out.append("<p>" + text + "</p>")
if in_list: out.append("</ul>")
print("\n".join(out))')"

cat > "$BUILD/appcast.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Scarlett Gen 1 Mixer</title>
    <link>$REPO</link>
    <item>
      <title>Version $VERSION</title>
      <pubDate>$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")</pubDate>
      <sparkle:version>$BUILD_NUMBER</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>$MIN_OS</sparkle:minimumSystemVersion>
      <description><![CDATA[
$NOTES
      ]]></description>
      <enclosure url="$REPO/releases/download/v$VERSION/ScarlettGen1Mixer-$VERSION.zip"
                 type="application/octet-stream" $SIGNATURE/>
    </item>
  </channel>
</rss>
XML
echo "==> Wrote $BUILD/appcast.xml ($VERSION, build $BUILD_NUMBER)"
