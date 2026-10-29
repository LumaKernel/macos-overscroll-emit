#!/usr/bin/env bash
# Zips build/OverscrollEmit.app (run scripts/build.sh first) and prints the zip path.
set -euo pipefail
cd "$(dirname "$0")/.."

plist="build/OverscrollEmit.app/Contents/Info.plist"
[[ -f "$plist" ]] || { echo "$plist not found; run scripts/build.sh" >&2; exit 1; }
# Name from the built app itself, so the zip always matches its contents.
version="$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$plist")"
build="$(/usr/libexec/PlistBuddy -c "Print OverscrollEmitBuild" "$plist")"
zip="build/OverscrollEmit-v${version}-${build}.zip"
rm -f "$zip"
ditto -c -k --keepParent build/OverscrollEmit.app "$zip"
echo "$zip"
