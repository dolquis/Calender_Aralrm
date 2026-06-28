#!/usr/bin/env bash
# Install cross-platform dev tools that are NOT pre-installed in the
# Claude Code on the Web cloud sandbox (Ubuntu 24.04, runs as root).
#
# Wired via .claude/settings.json -> SessionStart. The hook fires on every
# session, so this script exits immediately outside the cloud; local macOS
# sessions are unaffected (use scripts/install-tools.sh there instead).
#
# Docs: https://docs.claude.com/en/docs/claude-code/claude-code-on-the-web
# Keep tool versions in sync with the Brewfile and .github/workflows/ios.yml.
set -euo pipefail

# No-op unless we are inside a cloud sandbox session.
[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0

# Claude Code injects a SessionStart hook's stdout into the model context.
# Keep this installer side-effect-only: redirect all output (our logs and the
# package managers') to stderr so it stays as setup diagnostics, not as
# conversation input on every new/resumed cloud session.
exec >&2

GITLEAKS_VERSION="${GITLEAKS_VERSION:-8.30.1}"

have() { command -v "$1" >/dev/null 2>&1; }

echo "[cloud-setup] Preparing cross-platform tooling..."

# gitleaks: prebuilt Go binary from GitHub releases (most reliable on any distro).
if ! have gitleaks; then
  url="https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz"
  if curl -fsSL "$url" -o /tmp/gitleaks.tgz; then
    tar -xzf /tmp/gitleaks.tgz -C /usr/local/bin gitleaks && chmod +x /usr/local/bin/gitleaks
  else
    echo "[cloud-setup] WARN: gitleaks download failed" >&2
  fi
fi

# typos & lychee: install via cargo when a Rust toolchain is available.
install_cargo() { # $1 crate  $2 binary
  have "$2" && return 0
  if have cargo; then
    cargo install "$1" || echo "[cloud-setup] WARN: cargo install $1 failed" >&2
  else
    echo "[cloud-setup] NOTE: cargo absent; skipping $2 (add a Rust toolchain to enable)" >&2
  fi
}
install_cargo typos-cli typos
install_cargo lychee lychee

echo "[cloud-setup] Ready: gitleaks=$(command -v gitleaks || echo no), typos=$(command -v typos || echo no), lychee=$(command -v lychee || echo no)"
