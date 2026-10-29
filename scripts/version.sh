#!/usr/bin/env bash
# Sourced by scripts. Sets MAJOR, VERSION_STRING ({MAJOR}.0.0) and BUILD (commit hash, "-dirty" if uncommitted changes).
# BUILD_ID overrides BUILD when building outside a git checkout.
# shellcheck disable=SC2034  # variables are read by the sourcing script

# shellcheck source=SCRIPTDIR/../VERSION
source ./VERSION
[[ "${MAJOR:-}" =~ ^[1-9][0-9]*$ ]] || { echo "VERSION: MAJOR must be a positive integer" >&2; exit 1; }
VERSION_STRING="${MAJOR}.0.0"

if [[ -n "${BUILD_ID:-}" ]]; then
  BUILD="$BUILD_ID"
else
  BUILD="$(git rev-parse HEAD 2>/dev/null)" \
    || { echo "cannot read HEAD (not a git repo or no commits yet); commit first or set BUILD_ID" >&2; exit 1; }
  [[ -z "$(git status --porcelain)" ]] || BUILD="${BUILD}-dirty"
fi
[[ "$BUILD" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "invalid build id: $BUILD" >&2; exit 1; }
