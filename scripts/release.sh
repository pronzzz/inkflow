#!/bin/bash
# Builds a universal Inkflow release into dist/:
#   Inkflow-<version>.dmg   drag-to-Applications installer
#   Inkflow-<version>.zip   the app on its own
#   SHA256SUMS.txt
#
#   scripts/release.sh             build only
#   scripts/release.sh --publish   build, then create the GitHub release v<version> with notes from CHANGELOG.md
#
# Needs: Xcode, xcodegen and create-dmg (brew install xcodegen create-dmg), and gh for --publish.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PUBLISH=0
[ "${1:-}" = "--publish" ] && PUBLISH=1

VERSION=$(awk -F'"' '/MARKETING_VERSION/ {print $2; exit}' project.yml)
BUILD_DIR="$ROOT/build/release"
DIST="$ROOT/dist"
APP="$BUILD_DIR/Build/Products/Release/Inkflow.app"
NAME="Inkflow-$VERSION"

step() { printf "\n\033[1m==> %s\033[0m\n" "$1"; }

step "Inkflow $VERSION"
for tool in xcodegen create-dmg; do
  command -v "$tool" >/dev/null || { echo "Missing $tool (brew install $tool)" >&2; exit 1; }
done

step "Generating project"
xcodegen generate --quiet

step "Running tests"
xcodebuild -project Inkflow.xcodeproj -scheme Inkflow -derivedDataPath "$BUILD_DIR" test -quiet

step "Building universal Release"
rm -rf "$BUILD_DIR/Build/Products/Release"
xcodebuild -project Inkflow.xcodeproj -scheme Inkflow -configuration Release \
  -derivedDataPath "$BUILD_DIR" ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO build -quiet
lipo -info "$APP/Contents/MacOS/Inkflow"
codesign --verify --deep --strict "$APP"
BUILT_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
[ "$BUILT_VERSION" = "$VERSION" ] || { echo "Built version $BUILT_VERSION != $VERSION" >&2; exit 1; }

rm -rf "$DIST"
mkdir -p "$DIST"

step "Packaging zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$DIST/$NAME.zip"

step "Building DMG"
STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/"
tiffutil -cathidpicheck docs/art/dmg-background.png docs/art/dmg-background@2x.png -out "$STAGE/background.tiff" 2>/dev/null
create-dmg \
  --volname "Inkflow $VERSION" \
  --volicon "$APP/Contents/Resources/AppIcon.icns" \
  --background "$STAGE/background.tiff" \
  --window-pos 200 160 \
  --window-size 660 428 \
  --icon-size 128 \
  --text-size 13 \
  --icon "Inkflow.app" 170 170 \
  --hide-extension "Inkflow.app" \
  --app-drop-link 490 170 \
  --no-internet-enable \
  "$DIST/$NAME.dmg" \
  "$STAGE/Inkflow.app" >/dev/null
rm -rf "$STAGE"
codesign --force --sign - "$DIST/$NAME.dmg"
hdiutil verify "$DIST/$NAME.dmg" >/dev/null

(cd "$DIST" && shasum -a 256 "$NAME.dmg" "$NAME.zip" > SHA256SUMS.txt)

step "Artifacts"
ls -lh "$DIST"

if [ "$PUBLISH" = 1 ]; then
  step "Publishing v$VERSION to GitHub"
  NOTES=$(mktemp)
  # The section of CHANGELOG.md for this version, without its heading.
  awk -v v="$VERSION" '
    $0 ~ "^## \\[" v "\\]" { found = 1; next }
    found && /^## \[/ { exit }
    found { print }
  ' CHANGELOG.md > "$NOTES"
  [ -s "$NOTES" ] || { echo "No CHANGELOG.md section for $VERSION" >&2; exit 1; }
  ASSETS=("$DIST/$NAME.dmg" "$DIST/$NAME.zip" "$DIST/SHA256SUMS.txt")
  if gh release view "v$VERSION" >/dev/null 2>&1; then
    gh release upload "v$VERSION" "${ASSETS[@]}" --clobber
    gh release edit "v$VERSION" --notes-file "$NOTES"
  else
    gh release create "v$VERSION" --title "Inkflow $VERSION" --notes-file "$NOTES" --latest "${ASSETS[@]}"
  fi
  rm -f "$NOTES"
fi
