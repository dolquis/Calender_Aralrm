#!/usr/bin/env bash
# Regenerate the Xcode project, then build and/or test on an available iOS 26 simulator.
set -euo pipefail

cd "$(dirname "$0")/.."

ACTION="${1:-all}"
PROJECT="${PROJECT:-ShiftAlarm.xcodeproj}"
SCHEME="${SCHEME:-ShiftAlarm}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$PWD/DerivedData}"

usage() {
  cat >&2 <<'USAGE'
Usage: bash scripts/verify.sh [all|build|test]

Environment overrides:
  DESTINATION        xcodebuild destination string
  PROJECT            Xcode project path (default: ShiftAlarm.xcodeproj)
  SCHEME             Xcode scheme (default: ShiftAlarm)
  DERIVED_DATA_PATH  DerivedData path (default: ./DerivedData)
USAGE
}

case "$ACTION" in
  all|build|test) ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage
    exit 2
    ;;
esac

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen not found. Run: bash scripts/bootstrap.sh" >&2
  exit 1
fi

bash scripts/regen.sh

resolve_destination() {
  if [[ -n "${DESTINATION:-}" ]]; then
    printf '%s\n' "$DESTINATION"
    return
  fi

  xcrun simctl list devices available | awk '
    /^-- iOS 26\./ {
      if (runtime_candidate != "") {
        candidate = runtime_candidate
      }
      runtime_candidate = ""
      in_ios26 = 1
      next
    }
    /^-- / {
      if (runtime_candidate != "") {
        candidate = runtime_candidate
      }
      runtime_candidate = ""
      in_ios26 = 0
      next
    }
    in_ios26 && /iPhone/ && runtime_candidate == "" {
      if (match($0, /[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}/)) {
        runtime_candidate = "platform=iOS Simulator,id=" substr($0, RSTART, RLENGTH)
      }
    }
    END {
      if (runtime_candidate != "") {
        candidate = runtime_candidate
      }
      if (candidate != "") {
        print candidate
      }
    }
  '
}

DESTINATION_VALUE="$(resolve_destination)"
if [[ -z "$DESTINATION_VALUE" ]]; then
  echo "No available iOS 26 simulator found. Install one or set DESTINATION explicitly." >&2
  exit 1
fi

echo "Using destination: $DESTINATION_VALUE"

run_build() {
  xcodebuild build \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION_VALUE" \
    -derivedDataPath "$DERIVED_DATA_PATH"
}

run_test() {
  xcodebuild test \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION_VALUE" \
    -derivedDataPath "$DERIVED_DATA_PATH"
}

case "$ACTION" in
  build)
    run_build
    ;;
  test)
    run_test
    ;;
  all)
    run_build
    run_test
    ;;
esac
