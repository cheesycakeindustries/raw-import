#!/bin/zsh
set -e
cd "$(dirname "$0")"
VERSION="${VERSION:-1.0}"
APP="RAW Import.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
# Icon: icon/AppIcon.png -> AppIcon.icns  (neu zeichnen: swift tools/make_icon.swift icon/AppIcon.png)
mkdir -p "$APP/Contents/Resources"
SET=$(mktemp -d)/AppIcon.iconset; mkdir -p "$SET"
for s in 16 32 128 256 512; do
  sips -z $s $s icon/AppIcon.png --out "$SET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) icon/AppIcon.png --out "$SET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$SET" -o "$APP/Contents/Resources/AppIcon.icns"
# Universal Binary (Apple Silicon + Intel)
BIN=$(mktemp -d)
for ARCH in arm64 x86_64; do
  swiftc -O -parse-as-library -target $ARCH-apple-macos14.0 -o "$BIN/RAWImport-$ARCH" src/main.swift
done
lipo -create "$BIN/RAWImport-arm64" "$BIN/RAWImport-x86_64" -output "$APP/Contents/MacOS/RAWImport"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>RAW Import</string>
<key>CFBundleDisplayName</key><string>RAW Import</string>
<key>CFBundleIdentifier</key><string>io.github.cheesycakeindustries.rawimport</string>
<key>CFBundleExecutable</key><string>RAWImport</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$VERSION</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSRemovableVolumesUsageDescription</key><string>RAW Import liest die Fotos von deiner SD-Karte.</string>
</dict></plist>
PLIST
xattr -cr "$APP"
codesign --force -s - "$APP"
echo "Gebaut: $APP"
