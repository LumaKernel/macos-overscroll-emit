#!/usr/bin/env bash
# CI only: switch to the newest Xcode on the runner so swift / swift-format match local as closely as possible.
set -euo pipefail
latest="$(find /Applications -maxdepth 1 -name 'Xcode_*.app' | sort -V | tail -1)"
[[ -n "$latest" ]] || { echo "no Xcode_*.app found" >&2; exit 1; }
sudo xcode-select -s "$latest"
xcodebuild -version
swift --version
