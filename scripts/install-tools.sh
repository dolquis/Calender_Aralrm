#!/usr/bin/env bash
# Install the full local development toolchain from the repo Brewfile.
# macOS + Homebrew. For the minimal CI bootstrap, see scripts/bootstrap.sh.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required. Install from https://brew.sh first." >&2
  exit 1
fi

brew bundle --file=Brewfile
echo "Toolchain installed. Next steps: bash scripts/lsp-setup.sh && pre-commit install"
