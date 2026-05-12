#!/usr/bin/env bash
# Install XcodeGen so the Xcode project can be regenerated from project.yml.
# Run this once on a fresh machine before invoking scripts/regen.sh.
set -euo pipefail

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required. Install from https://brew.sh first." >&2
  exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Installing XcodeGen via Homebrew..."
  brew install xcodegen
else
  echo "XcodeGen already installed: $(xcodegen --version)"
fi
