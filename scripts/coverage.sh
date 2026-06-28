#!/usr/bin/env bash
# Print a code-coverage summary from the most recent test result bundle.
# Run a test build first (bash scripts/verify.sh test) so an .xcresult exists.
# macOS + Xcode only.
set -euo pipefail

cd "$(dirname "$0")/.."

DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$PWD/DerivedData}"
xcresult="$(/bin/ls -dt "$DERIVED_DATA_PATH"/Logs/Test/*.xcresult 2>/dev/null | head -1 || true)"

if [ -z "$xcresult" ]; then
  echo "No .xcresult under $DERIVED_DATA_PATH/Logs/Test. Run: bash scripts/verify.sh test" >&2
  exit 1
fi

echo "==> coverage ($xcresult)"
if command -v xcresultparser >/dev/null 2>&1; then
  xcresultparser -c -o cli "$xcresult"
else
  echo "xcresultparser not found; falling back to xcrun xccov." >&2
  xcrun xccov view --report --only-targets "$xcresult"
fi
