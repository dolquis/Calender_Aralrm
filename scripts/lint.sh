#!/usr/bin/env bash
# Lint or auto-format Swift sources with Apple's swift-format.
# Style is configured in .swift-format at the repository root.
set -euo pipefail

cd "$(dirname "$0")/.."

ACTION="${1:-check}"

usage() {
  cat >&2 <<'USAGE'
Usage: bash scripts/lint.sh [check|fix]

  check  Lint Swift sources and fail on any style violation (default).
  fix    Reformat Swift sources in place.

Requires Xcode 26 or a Swift 6 toolchain that bundles swift-format.
USAGE
}

case "$ACTION" in
  check|fix) ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage
    exit 2
    ;;
esac

# Resolve a swift-format invocation across toolchain layouts.
if xcrun --find swift-format >/dev/null 2>&1; then
  SWIFT_FORMAT=(xcrun swift-format)
elif command -v swift-format >/dev/null 2>&1; then
  SWIFT_FORMAT=(swift-format)
elif command -v swift >/dev/null 2>&1 && swift format --version >/dev/null 2>&1; then
  SWIFT_FORMAT=(swift format)
else
  echo "swift-format not found. Install Xcode 26 or a Swift 6 toolchain." >&2
  exit 1
fi

TARGETS=(Sources App Widget Tests)

case "$ACTION" in
  check)
    "${SWIFT_FORMAT[@]}" lint --strict --recursive --parallel "${TARGETS[@]}"
    echo "swift-format: no violations."
    ;;
  fix)
    "${SWIFT_FORMAT[@]}" format --in-place --recursive --parallel "${TARGETS[@]}"
    echo "swift-format: reformatted ${TARGETS[*]}."
    ;;
esac
