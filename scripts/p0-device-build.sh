#!/usr/bin/env bash
# Build the app for a real iOS device after P0 signing readiness checks pass.
set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT="${PROJECT:-ShiftAlarm.xcodeproj}"
SCHEME="${SCHEME:-ShiftAlarm}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$PWD/DerivedData}"
DESTINATION="${DESTINATION:-generic/platform=iOS}"

usage() {
  cat >&2 <<'USAGE'
Usage: bash scripts/p0-device-build.sh

Environment overrides:
  DESTINATION        xcodebuild destination (default: generic/platform=iOS)
  PROJECT            Xcode project path (default: ShiftAlarm.xcodeproj)
  SCHEME             Xcode scheme (default: ShiftAlarm)
  DERIVED_DATA_PATH  DerivedData path (default: ./DerivedData)

Before running:
  1. Copy Config/LocalSigning.xcconfig.example to Config/LocalSigning.xcconfig.
  2. Fill real Developer Team, bundle IDs, App Group, and related identifiers.
  3. Make sure the Apple Developer Portal app id has the AlarmKit entitlement approved.
USAGE
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  "")
    ;;
  *)
    usage
    exit 2
    ;;
esac

bash scripts/regen.sh
bash scripts/p0-readiness.sh

echo "Using destination: $DESTINATION"
xcodebuild build \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH"
