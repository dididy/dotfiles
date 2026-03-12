#!/bin/bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
DRY_RUN="${DRY_RUN:-false}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
info() { echo -e "${GREEN}[git]${NC} $1"; }
warn() { echo -e "${YELLOW}[git]${NC} $1"; }

# ── User info ──
echo ""
echo "=== Git account setup ==="
echo ""

# Read current values as defaults
_cur_personal_name=$(git config -f "$DOTFILES_DIR/configs/.gitconfig-personal" user.name 2>/dev/null || true)
_cur_personal_email=$(git config -f "$DOTFILES_DIR/configs/.gitconfig-personal" user.email 2>/dev/null || true)
_cur_work_name=$(git config -f "$DOTFILES_DIR/configs/.gitconfig-work" user.name 2>/dev/null || true)
_cur_work_email=$(git config -f "$DOTFILES_DIR/configs/.gitconfig-work" user.email 2>/dev/null || true)

# Personal account
read -rp "Personal Git name [${_cur_personal_name}]: " personal_name
personal_name="${personal_name:-$_cur_personal_name}"
read -rp "Personal Git email [${_cur_personal_email}]: " personal_email
personal_email="${personal_email:-$_cur_personal_email}"

# Work account
read -rp "Work Git name [${_cur_work_name}]: " work_name
work_name="${work_name:-$_cur_work_name}"
read -rp "Work Git email [${_cur_work_email}]: " work_email
work_email="${work_email:-$_cur_work_email}"

if $DRY_RUN; then
  info "[dry-run] .gitconfig-personal: $personal_name <$personal_email>"
  info "[dry-run] .gitconfig-work: $work_name <$work_email>"
else
  # Write user info to configs directory
  cat > "$DOTFILES_DIR/configs/.gitconfig-personal" <<EOF
[user]
    name = $personal_name
    email = $personal_email
EOF

  cat > "$DOTFILES_DIR/configs/.gitconfig-work" <<EOF
[user]
    name = $work_name
    email = $work_email
EOF
fi

# ── Create project directories ──
if ! $DRY_RUN; then
  mkdir -p "$HOME/personal" "$HOME/work"
fi

# ── Generate SSH keys ──
generate_ssh_key() {
  local name="$1"
  local email="$2"
  local key_file="$HOME/.ssh/id_ed25519_$name"

  if [ -f "$key_file" ]; then
    info "SSH key already exists: $key_file"
    return
  fi

  info "Generating SSH key: $name ($email)"
  if $DRY_RUN; then
    info "[dry-run] Skipping ssh-keygen"
  else
    ssh-keygen -t ed25519 -C "$email" -f "$key_file"
  fi
}

generate_ssh_key "personal" "$personal_email"
generate_ssh_key "work" "$work_email"

# ── SSH config ──
SSH_CONFIG="$HOME/.ssh/config"
if $DRY_RUN; then
  info "[dry-run] Skipping SSH config write"
else
  mkdir -p "$HOME/.ssh"
  cat > "$SSH_CONFIG" <<EOF
# Personal GitHub
Host github.com-personal
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_personal
    IdentitiesOnly yes

# Work GitHub
Host github.com-work
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_work
    IdentitiesOnly yes

# Default (personal)
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_personal
    IdentitiesOnly yes
EOF
  chmod 600 "$SSH_CONFIG"
fi

# ── Register with ssh-agent ──
if ! $DRY_RUN; then
  eval "$(ssh-agent -s)" >/dev/null 2>&1
  ssh-add "$HOME/.ssh/id_ed25519_personal" 2>/dev/null || true
  ssh-add "$HOME/.ssh/id_ed25519_work" 2>/dev/null || true
fi

echo ""
info "Git setup done"
warn "Don't forget to add your SSH public keys to GitHub:"
warn "  Personal: cat ~/.ssh/id_ed25519_personal.pub"
warn "  Work:     cat ~/.ssh/id_ed25519_work.pub"
