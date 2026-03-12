#!/bin/bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
DRY_RUN="${DRY_RUN:-false}"

GREEN='\033[0;32m'
NC='\033[0m'
info() { echo -e "${GREEN}[brew]${NC} $1"; }

# Install Homebrew
if ! command -v brew &>/dev/null; then
  info "Installing Homebrew..."
  if $DRY_RUN; then
    info "[dry-run] Skipping Homebrew install"
  else
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Set up path for Apple Silicon
    if [[ "$(uname -m)" == "arm64" ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
  fi
else
  info "Homebrew already installed"
fi

# Run Brewfile
info "Installing packages from Brewfile..."
if $DRY_RUN; then
  info "[dry-run] Skipping brew bundle"
  info "[dry-run] Packages that would be installed:"
  cat "$DOTFILES_DIR/Brewfile"
else
  brew update
  brew bundle --file="$DOTFILES_DIR/Brewfile"
fi

info "Homebrew setup done"
