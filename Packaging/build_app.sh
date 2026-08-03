#!/bin/bash
#
# Baut die App "activities" als eigenstaendiges .app-Bundle.
#
# Ablauf: Release-Build (SwiftPM) -> Bundle-Struktur -> Icon (.icns) ->
# Info.plist -> Ad-hoc-Signatur. Ergebnis liegt unter dist/activities.app.
#
# Voraussetzungen: Command Line Tools (swift, iconutil, codesign).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="activities"
DIST="$ROOT/dist"
APP="$DIST/${APP_NAME}.app"

# Universelles Binary (Apple Silicon + Intel). Da ohne volles Xcode das
# Flag --arch (xcbuild) nicht verfuegbar ist, werden beide Architekturen
# getrennt gebaut und anschliessend mit lipo zusammengefuehrt.
DEPLOY="x86_64-apple-macosx14.0"

echo "==> Release-Build arm64"
cd "$ROOT"
swift build -c release --product "$APP_NAME"
ARM_BIN="$(swift build -c release --product "$APP_NAME" --show-bin-path)/$APP_NAME"

echo "==> Release-Build x86_64 (Cross-Build)"
swift build -c release --product "$APP_NAME" --scratch-path .build-x86 \
    -Xswiftc -target -Xswiftc "$DEPLOY"
X86_BIN="$(swift build -c release --product "$APP_NAME" --scratch-path .build-x86 \
    -Xswiftc -target -Xswiftc "$DEPLOY" --show-bin-path)/$APP_NAME"

echo "==> Bundle-Struktur"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "==> Universelles Binary zusammenfuehren (lipo)"
lipo -create "$ARM_BIN" "$X86_BIN" -output "$APP/Contents/MacOS/$APP_NAME"
lipo -info "$APP/Contents/MacOS/$APP_NAME"

echo "==> Info.plist"
cp "$ROOT/Packaging/Info.plist" "$APP/Contents/Info.plist"

echo "==> Versionsinfo aus Git injizieren"
GIT_DESCRIBE="$(git -C "$ROOT" describe --tags --always --dirty 2>/dev/null || echo unknown)"
GIT_REVISION="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
GIT_COUNT="$(git -C "$ROOT" rev-list --count HEAD 2>/dev/null || echo 0)"
BUILD_DATE="$(date '+%Y-%m-%d %H:%M:%S %z')"
PLIST="$APP/Contents/Info.plist"
PB=/usr/libexec/PlistBuddy
set_key() { # key value
    "$PB" -c "Add :$1 string $2" "$PLIST" 2>/dev/null || "$PB" -c "Set :$1 $2" "$PLIST"
}
set_key GitDescribe "$GIT_DESCRIBE"
set_key GitRevision "$GIT_REVISION"
set_key BuildDate "$BUILD_DATE"
"$PB" -c "Set :CFBundleVersion $GIT_COUNT" "$PLIST" 2>/dev/null || true
echo "   $GIT_DESCRIBE (rev $GIT_REVISION, build $GIT_COUNT)"

echo "==> App-Icon"
ICONSET="$DIST/AppIcon.iconset"
rm -rf "$ICONSET"
swift "$ROOT/Packaging/make_icon.swift" "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

echo "==> Ad-hoc-Signatur"
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || {
    echo "   (Signatur uebersprungen)"
}

echo "==> Fertig: $APP"
