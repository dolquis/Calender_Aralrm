#!/usr/bin/env bash
# Generate buildServer.json so SourceKit-LSP works in VS Code / other editors
# (and Claude Code's swift-lsp plugin) against the XcodeGen-generated project.
# buildServer.json holds machine-specific paths and is git-ignored.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcode-build-server >/dev/null 2>&1; then
  echo "xcode-build-server not found. Install: brew install xcode-build-server." >&2
  exit 1
fi

bash scripts/regen.sh
xcode-build-server config -project ShiftAlarm.xcodeproj -scheme ShiftAlarm
echo "Wrote buildServer.json (git-ignored). Restart your editor's SourceKit-LSP."
