#!/bin/zsh
# Baut die App und packt sie als ZIP für einen GitHub-Release.
# Aufruf: ./release.sh 1.0
set -e
cd "$(dirname "$0")"
VERSION="${1:-1.0}"
VERSION="$VERSION" ./build.sh
mkdir -p dist
ZIP="dist/RAW-Import-$VERSION.zip"
rm -f "$ZIP"
# ditto erhält Signatur und Bundle-Struktur
ditto -c -k --sequesterRsrc --keepParent "RAW Import.app" "$ZIP"
# Fester Name, damit der Link .../releases/latest/download/RAW-Import.zip immer funktioniert
cp "$ZIP" dist/RAW-Import.zip
shasum -a 256 "$ZIP"
echo "Fertig: $ZIP (+ dist/RAW-Import.zip)"
