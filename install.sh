#!/bin/bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
DRY_RUN=false

for arg in "$@"; do
  case $arg in
    --dry-run) DRY_RUN=true ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done

export DOTFILES_DIR DRY_RUN

TAG="install"
# shellcheck source=scripts/lib/common.sh
source "$DOTFILES_DIR/scripts/lib/common.sh"

if $DRY_RUN; then
  warn "=== DRY RUN MODE — no changes will be made ==="
fi

echo ""
echo "========================================="
echo "  macOS dev environment setup (dotfiles)"
echo "========================================="
echo ""
echo "The following will be installed/configured:"
echo "  1. Homebrew & apps (brew.sh + Brewfile)"
echo "  2. macOS system settings (macos.sh)"
echo "  3. Dev tools: nvm, pyenv, etc. (dev.sh)"
echo "  4. Shell — Oh My Zsh + plugins (shell.sh)"
echo "  5. Git — config + SSH keys (git.sh)"
echo "  6. Claude Code setup (claude.sh)"
echo "  7. opencode setup (opencode.sh)"
echo "  8. Hermes Agent (hermes.sh)"
echo "  9. dotfiles symlinks"
echo " 10. Tailscale VPN + Tailscale SSH (tailscale.sh)"
echo " 11. purplemux + code-server LaunchAgents (services.sh)"
echo " 12. Company overlay (only if the company/ submodule is initialized)"
echo ""

read -rp "Ready to continue? (y/N) " confirm
if [[ "$confirm" != [yY] ]]; then
  echo "Aborted."
  exit 0
fi

# ── 1. Homebrew ──
info "1/11 Installing Homebrew & apps..."
bash "$DOTFILES_DIR/scripts/brew.sh"

# ── 2. macOS settings ──
info "2/11 Applying macOS system settings..."
bash "$DOTFILES_DIR/scripts/macos.sh"

# ── 3. Dev environment ──
info "3/11 Setting up dev environment..."
bash "$DOTFILES_DIR/scripts/dev.sh"

# ── 4. Shell ──
info "4/11 Configuring shell environment..."
bash "$DOTFILES_DIR/scripts/shell.sh"

# ── 5. Git ──
info "5/11 Configuring Git..."
bash "$DOTFILES_DIR/scripts/git.sh"

# ── 6. Claude Code ──
info "6/11 Setting up Claude Code..."
bash "$DOTFILES_DIR/scripts/claude.sh"

# ── 7. opencode ──
info "7/11 Setting up opencode..."
bash "$DOTFILES_DIR/scripts/opencode.sh"

# ── 8. Hermes Agent ──
info "8/11 Setting up Hermes Agent..."
bash "$DOTFILES_DIR/scripts/hermes.sh"

# ── 9. Symlinks ──
info "9/11 Creating dotfiles symlinks..."

link_file "$DOTFILES_DIR/configs/.zshrc"              "$HOME/.zshrc"
link_file "$DOTFILES_DIR/configs/.tmux.conf"          "$HOME/.tmux.conf"
link_file "$DOTFILES_DIR/configs/.gitconfig"           "$HOME/.gitconfig"
link_file "$DOTFILES_DIR/configs/.gitconfig-personal"  "$HOME/.gitconfig-personal"
link_file "$DOTFILES_DIR/configs/.gitconfig-work"      "$HOME/.gitconfig-work"
link_file "$DOTFILES_DIR/configs/.gitignore_global"    "$HOME/.gitignore_global"

# shared agent config (canonical)
mkdir -p "$HOME/.agent"
link_file "$DOTFILES_DIR/configs/AGENTS.md" "$HOME/.agent/AGENTS.md"

# Claude Code
# NOTE: MCP servers are NOT registered via symlinking a file. Claude Code stores
# user-scope MCP entries in ~/.claude.json (managed via `claude mcp add`), not in
# ~/.claude/.mcp.json. Registration is handled by scripts/claude.sh which reads
# configs/mcp.json (single source of truth) and runs `claude mcp add-json`.
mkdir -p "$HOME/.claude/hooks" "$HOME/.claude/plugins"
link_file "$DOTFILES_DIR/configs/claude-settings.json" "$HOME/.claude/settings.json"
link_file "$DOTFILES_DIR/configs/CLAUDE.md"            "$HOME/.claude/CLAUDE.md"
link_file "$DOTFILES_DIR/configs/hooks/skill-eval.sh"  "$HOME/.claude/hooks/skill-eval.sh"

# Cursor
mkdir -p "$HOME/.cursor/rules"
link_file "$DOTFILES_DIR/configs/AGENTS.md" "$HOME/.cursor/rules/AGENTS.md"

# opencode AGENTS.md (opencode.sh handles its own config files)
mkdir -p "$HOME/.config/opencode"
link_file "$DOTFILES_DIR/configs/AGENTS.md" "$HOME/.config/opencode/AGENTS.md"

# Codex CLI
mkdir -p "$HOME/.codex"
link_file "$DOTFILES_DIR/configs/codex/config.toml" "$HOME/.codex/config.toml"

RTK_CONFIG_DIR="$HOME/Library/Application Support/rtk"
mkdir -p "$RTK_CONFIG_DIR"
link_file "$DOTFILES_DIR/configs/rtk-config.toml"     "$RTK_CONFIG_DIR/config.toml"

# ── 10. Tailscale + Tailscale SSH ──
info "10/11 Setting up Tailscale (incl. Tailscale SSH)..."
bash "$DOTFILES_DIR/scripts/tailscale.sh"

# ── 11. purplemux + code-server services ──
info "11/11 Installing purplemux + code-server LaunchAgents..."
bash "$DOTFILES_DIR/scripts/services.sh"

echo ""
info "Done."
info "Restart your terminal or run 'source ~/.zshrc'."

# ── 회사용 overlay (옵션, git submodule) ──
# company/ 는 git submodule로 별도의 사내 git 저장소에 호스팅된다.
# 새 머신: git clone --recurse-submodules ... 또는 git submodule update --init
if [ -x "$DOTFILES_DIR/company/install.sh" ]; then
  echo ""
  info "Detected company/install.sh — running company overlay..."
  bash "$DOTFILES_DIR/company/install.sh"
elif [ -d "$HOME/work" ]; then
  echo ""
  warn "~/work detected but company/ submodule is not initialized."
  warn "Run: git -C $DOTFILES_DIR submodule update --init"
  warn "(Requires SSH access to the internal git host — see company/README.md)"
fi
