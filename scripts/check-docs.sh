#!/usr/bin/env bash
# Documentation quality checks: spelling (typos, offline) and, optionally,
# external links (lychee, network).
#
#   bash scripts/check-docs.sh           # spelling only
#   bash scripts/check-docs.sh --links   # spelling + external link check
#
# Cross-platform: typos also runs in the Linux cloud sandbox and CI.
# Configuration lives in typos.toml and lychee.toml at the repository root.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v typos >/dev/null 2>&1; then
  echo "typos not found. Install: brew install typos-cli (macOS) or see scripts/cloud-setup.sh (Linux)." >&2
  exit 1
fi

echo "==> typos (spell check)"
typos

case " $* " in
  *" --links "*)
    if ! command -v lychee >/dev/null 2>&1; then
      echo "lychee not found. Install: brew install lychee." >&2
      exit 1
    fi
    echo "==> lychee (link check)"
    lychee --config lychee.toml README.md README.ja.md AGENTS.md ROADMAP.md docs
    ;;
esac
