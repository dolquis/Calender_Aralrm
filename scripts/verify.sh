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

  local destinations
  destinations="$(xcodebuild -showdestinations \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -derivedDataPath "$DERIVED_DATA_PATH" 2>&1 || true)"

  # Prefer the highest-numbered iOS iPhone simulator available.
  # On CI runners the iOS 26 runtime may be installed separately;
  # fall back to any iPhone simulator so the build/test still runs.
  # Uses only POSIX awk (2-argument match) for macOS/BSD awk compatibility.
  printf '%s\n' "$destinations" | awk '
    /platform:iOS Simulator/ && /name:iPhone/ {
      line = $0
      if (match(line, /OS:[0-9]+/)) {
        major = substr(line, RSTART + 3, RLENGTH - 3) + 0
      } else {
        major = 0
      }
      if (major >= best_major && match(line, /id:[^,}]+/)) {
        id = substr(line, RSTART + 3, RLENGTH - 3)
        gsub(/^ +| +$/, "", id)
        candidate = "platform=iOS Simulator,id=" id
        best_major = major
      }
    }
    END {
      if (candidate != "") {
        print candidate
      }
    }
  '
}

DESTINATION_VALUE="$(resolve_destination)"
if [[ -z "$DESTINATION_VALUE" ]]; then
  echo "No eligible iPhone simulator found. Install the iOS platform runtime or set DESTINATION explicitly." >&2
  xcodebuild -showdestinations \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -derivedDataPath "$DERIVED_DATA_PATH" >&2 || true
  exit 1
fi

echo "Using destination: $DESTINATION_VALUE"

# Pretty-print xcodebuild output when xcbeautify is available; otherwise pass
# through unchanged so CI (which may not have it) still works. pipefail is set
# globally above, so a build/test failure still propagates through the pipe.
BEAUTIFY=(cat)
if command -v xcbeautify >/dev/null 2>&1; then
  BEAUTIFY=(xcbeautify)
fi

run_build() {
  xcodebuild build \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION_VALUE" \
    -derivedDataPath "$DERIVED_DATA_PATH" | "${BEAUTIFY[@]}"
}

run_test() {
  xcodebuild test \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION_VALUE" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -enableCodeCoverage YES | "${BEAUTIFY[@]}"
}

report_coverage() {
  # Best-effort coverage summary from the latest .xcresult; never fails the run.
  command -v xcresultparser >/dev/null 2>&1 || return 0
  local xcresult
  xcresult="$(/bin/ls -dt "$DERIVED_DATA_PATH"/Logs/Test/*.xcresult 2>/dev/null | head -1)"
  [ -n "$xcresult" ] || return 0
  echo "==> coverage ($xcresult)"
  xcresultparser -c -o cli "$xcresult" || true
}

case "$ACTION" in
  build)
    run_build
    ;;
  test)
    run_test
    report_coverage
    ;;
  all)
    run_build
    run_test
    report_coverage
    ;;
esac
