#!/usr/bin/env bash
# Detect unused Swift code with Periphery.
# Regenerates the Xcode project first so analysis matches project.yml.
# macOS + Xcode only (Periphery builds the project to analyze references).
# Configuration lives in .periphery.yml at the repository root.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v periphery >/dev/null 2>&1; then
  echo "periphery not found. Install: brew install periphery (or bash scripts/install-tools.sh)." >&2
  exit 1
fi

bash scripts/regen.sh
periphery scan "$@"
