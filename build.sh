#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
APP="$ROOT/build/Northstar Video Player.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Info.plist")"
PKG="$ROOT/build/Northstar-Video-Player-macOS-universal.pkg"
DMG="$ROOT/build/Northstar-Video-Player-macOS-universal.dmg"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$MACOS"
for ARCH in arm64 x86_64; do
    swiftc \
        -sdk "$SDK" \
        -target "${ARCH}-apple-macosx13.0" \
        -swift-version 5 \
        -parse-as-library \
        "$ROOT/UniversalVideoPlayer.swift" \
        -framework AppKit \
        -framework AVFoundation \
        -framework AVKit \
        -o "$TMP/$ARCH"
done

lipo -create "$TMP/arm64" "$TMP/x86_64" -output "$MACOS/UniversalVideoPlayer"
cp "$ROOT/Info.plist" "$CONTENTS/Info.plist"
codesign --force --deep --sign - "$APP"
pkgbuild \
    --component "$APP" \
    --install-location /Applications \
    --identifier com.northstar.UniversalVideoPlayer \
    --version "$VERSION" \
    --ownership recommended \
    "$PKG"

DMG_ROOT="$TMP/dmg-root"
mkdir -p "$DMG_ROOT"
cp -R "$APP" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"
hdiutil create \
    -volname "Northstar Video Player" \
    -srcfolder "$DMG_ROOT" \
    -ov \
    -format UDZO \
    "$DMG"
printf 'Built universal app: %s\nBuilt installer package: %s\nBuilt disk image: %s\n' "$APP" "$PKG" "$DMG"
