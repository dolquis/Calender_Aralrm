#!/usr/bin/env bash
# Scan the working tree for committed secrets with gitleaks.
# Cross-platform: also runs in the Linux cloud sandbox and CI.
# Configuration lives in .gitleaks.toml at the repository root.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v gitleaks >/dev/null 2>&1; then
  echo "gitleaks not found. Install: brew install gitleaks (macOS) or see scripts/cloud-setup.sh (Linux)." >&2
  exit 1
fi

gitleaks dir . --no-banner --redact "$@"
