# Brewfile — ShiftAlarm local development toolchain.
#
# Install / refresh everything:  bash scripts/install-tools.sh   (wraps `brew bundle`)
# All formulae below are in homebrew-core; no extra taps are required.

# --- Xcode project generation & build ergonomics (macOS) ---
brew "xcodegen"            # project.yml -> ShiftAlarm.xcodeproj (also via scripts/bootstrap.sh)
brew "xcbeautify"          # human-readable xcodebuild output
brew "xcode-build-server"  # SourceKit-LSP for VS Code / editors on the XcodeGen project

# --- Swift code quality (macOS / Xcode toolchain) ---
brew "swift-format"        # formatter / linter, config .swift-format (used by scripts/lint.sh)
brew "swiftlint"           # additional Swift linter
brew "periphery"           # unused-code detection (scripts/periphery.sh)
brew "xcresultparser"      # coverage extraction from .xcresult

# --- Cross-platform checks (also run in the Linux cloud sandbox / CI) ---
brew "gitleaks"            # secret scanning (scripts/scan-secrets.sh)
brew "typos-cli"           # source / doc spell check (scripts/check-docs.sh)
brew "lychee"              # documentation link checker
brew "pre-commit"          # local commit-time hook runner (.pre-commit-config.yaml)

# --- General CLI used by scripts & agents ---
brew "gh"
brew "jq"
brew "ripgrep"
brew "fd"
