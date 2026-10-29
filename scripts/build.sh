#!/usr/bin/env bash
# Builds build/OverscrollEmit.app from the Swift package.
#   CODESIGN_IDENTITY  signing identity. Default: the first valid code-signing identity in the
#                      keychain, else "-" (ad-hoc). A stable identity keeps the Accessibility
#                      grant across rebuilds; ad-hoc signatures change every build and lose it.
set -euo pipefail
cd "$(dirname "$0")/.."

# shellcheck source=SCRIPTDIR/version.sh
source ./scripts/version.sh
version="$VERSION_STRING"
identity="${CODESIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | awk '/^ *[0-9]+\)/ { print $2; exit }')}"
if [[ -z "$identity" ]]; then
  identity="-"
  echo "warning: no code-signing identity found; signing ad-hoc (Accessibility grant resets on every rebuild)" >&2
fi

swift build -c release --product OverscrollEmitApp
swift build -c release --product overscroll-emit-cli
bin="$(swift build -c release --show-bin-path)"

app="build/OverscrollEmit.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Helpers"
cp "$bin/OverscrollEmitApp" "$app/Contents/MacOS/OverscrollEmit"
cp "$bin/overscroll-emit-cli" "$app/Contents/Helpers/overscroll-emit"
sed -e "s/__VERSION__/${version}/" -e "s/__BUILD__/${BUILD}/" Resources/Info.plist > "$app/Contents/Info.plist"

codesign --force --options runtime --sign "$identity" "$app/Contents/Helpers/overscroll-emit"
codesign --force --options runtime --sign "$identity" "$app"

signer="$(codesign -dvv "$app" 2>&1 | sed -n 's/^Authority=//p' | head -1)"
echo "Built $app (v${version}, build ${BUILD}, signed by ${signer:-ad-hoc})"
