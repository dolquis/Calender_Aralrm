#!/usr/bin/env bash
# Regenerate ShiftAlarm.xcodeproj from project.yml.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen not found. Run scripts/bootstrap.sh first." >&2
  exit 1
fi

xcodegen generate
echo "Generated ShiftAlarm.xcodeproj"
