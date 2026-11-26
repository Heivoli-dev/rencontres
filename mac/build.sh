#!/bin/bash
# Construit l'appli Mac « Rencontres » (barre des menus) et la lance.
# Usage : ouvre le Terminal dans ce dossier, puis tape :  ./build.sh
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Rencontres.app"
ARCH="$(uname -m)"   # arm64 (puce Apple) ou x86_64 (Intel)

echo "→ Compilation pour ${ARCH}…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

xcrun swiftc -O -swift-version 5 -parse-as-library \
  -target "${ARCH}-apple-macos13.0" \
  Sources/*.swift \
  -o "$APP/Contents/MacOS/Rencontres"

cp Info.plist "$APP/Contents/Info.plist"
cp ../shared/creature/creature.html "$APP/Contents/Resources/creature.html"
cp ../shared/creature/plaza.html "$APP/Contents/Resources/plaza.html"

echo "→ Signature locale…"
codesign --force --deep --sign - "$APP"

echo "→ Création du DMG (à partager avec tes potes qui ont un Mac)…"
rm -rf build/dmg build/Rencontres.dmg
mkdir -p build/dmg
cp -R "$APP" build/dmg/
ln -s /Applications build/dmg/Applications
hdiutil create -quiet -volname "Rencontres" -srcfolder build/dmg -ov -format UDZO build/Rencontres.dmg
rm -rf build/dmg
echo "   DMG prêt : $(pwd)/build/Rencontres.dmg"

if [ -z "${NO_LAUNCH:-}" ]; then
  echo "→ Lancement. L'appli apparaît dans la barre des menus, en haut à droite (petite étincelle)."
  pkill -x Rencontres 2>/dev/null || true
  open "$APP"
fi
