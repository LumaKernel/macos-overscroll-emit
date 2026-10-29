#!/usr/bin/env bash
# Builds and installs OverscrollEmit.app.
#   INSTALL_DIR  where to put OverscrollEmit.app (default: /Applications)
#   BIN_DIR      if set, symlinks the CLI as $BIN_DIR/overscroll-emit
set -euo pipefail
cd "$(dirname "$0")/.."

install_dir="${INSTALL_DIR:-/Applications}"
./scripts/build.sh

# Stop the running copy so the new binary is picked up.
if pgrep -qf "${install_dir}/OverscrollEmit.app/Contents/MacOS/OverscrollEmit"; then
  "${install_dir}/OverscrollEmit.app/Contents/Helpers/overscroll-emit" quit || true
fi
rm -rf "${install_dir}/OverscrollEmit.app"
cp -R build/OverscrollEmit.app "${install_dir}/OverscrollEmit.app"
echo "Installed ${install_dir}/OverscrollEmit.app"

cli="${install_dir}/OverscrollEmit.app/Contents/Helpers/overscroll-emit"
if [[ -n "${BIN_DIR:-}" ]]; then
  ln -sf "$cli" "${BIN_DIR}/overscroll-emit"
  echo "Linked ${BIN_DIR}/overscroll-emit -> $cli"
else
  echo "To put the CLI on PATH: ln -sf '$cli' /usr/local/bin/overscroll-emit  (or rerun with BIN_DIR=...)"
fi
