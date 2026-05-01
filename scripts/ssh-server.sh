#!/bin/bash
set -euo pipefail
TAG="ssh"
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

# ── Generate host keys if missing ──
# Note: we do NOT enable Remote Login here. The hardened config has to be
# in place AND we have to know there's an authorized_keys entry (or the
# user has explicitly opted into a temporary password-auth window) before
# the listener goes live, so an attacker on the LAN can't race a stock
# config-and-no-keys window.
if ! $DRY_RUN; then
  if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
    info "Generating SSH host keys..."
    sudo ssh-keygen -A
  fi
fi

# ── Install hardened config ──
SSHD_CONFIG_DIR="/etc/ssh/sshd_config.d"
HARDENED_CONF="$SSHD_CONFIG_DIR/hardened.conf"
SSHD_MAIN="/etc/ssh/sshd_config"
INCLUDE_LINE="Include /etc/ssh/sshd_config.d/*.conf"
INCLUDE_ADDED_BY_US=false

info "Installing hardened sshd config..."
if $DRY_RUN; then
  info "[dry-run] sudo cp hardened.conf -> $HARDENED_CONF"
else
  sudo mkdir -p "$SSHD_CONFIG_DIR"

  if ! sudo grep -q "^Include.*sshd_config.d" "$SSHD_MAIN" 2>/dev/null; then
    warn "Adding Include directive to $SSHD_MAIN"
    echo "$INCLUDE_LINE" | sudo tee -a "$SSHD_MAIN" >/dev/null
    INCLUDE_ADDED_BY_US=true
  fi

  sed "s/__SSH_USER__/$(whoami)/g" "$DOTFILES_DIR/configs/sshd_config.d/hardened.conf" \
    | sudo tee "$HARDENED_CONF" >/dev/null
  sudo chmod 644 "$HARDENED_CONF"
  info "Installed: hardened.conf -> $HARDENED_CONF (AllowUsers=$(whoami))"
fi

# ── Validate config (do NOT reload yet — Remote Login may still be off) ──
if ! $DRY_RUN; then
  info "Validating sshd config..."
  if ! sudo sshd -t; then
    warn "sshd config validation failed (see error above)"
    warn "Reverting hardened config..."
    sudo rm -f "$HARDENED_CONF"
    if $INCLUDE_ADDED_BY_US; then
      warn "Reverting Include directive added to $SSHD_MAIN"
      sudo sed -i '' "\\|^${INCLUDE_LINE}\$|d" "$SSHD_MAIN"
    fi
    exit 1
  fi
fi

# ── Decide whether Remote Login is safe to enable ──
# Only flip the listener on once at least one of:
#   (a) authorized_keys exists and is non-empty (key-only, key + TOTP), or
#   (b) the user explicitly opts into a temporary password-auth window and
#       takes responsibility for locking it back down right after.
HAS_AUTHORIZED_KEYS=false
if [ -s "$HOME/.ssh/authorized_keys" ]; then
  HAS_AUTHORIZED_KEYS=true
fi

ENABLE_REMOTE_LOGIN=false
TEMP_PASSWORD_FLOW=false

if $HAS_AUTHORIZED_KEYS; then
  ENABLE_REMOTE_LOGIN=true
elif ! $DRY_RUN; then
  echo ""
  warn "No authorized_keys found — remote devices can't connect yet."
  warn "Enabling Remote Login now would expose sshd before any key is in place."
  read -rp "Temporarily enable password auth so you can ssh-copy-id? (y/N) " enable_pw
  if [[ "$enable_pw" == [yY] ]]; then
    ENABLE_REMOTE_LOGIN=true
    TEMP_PASSWORD_FLOW=true
  else
    warn "Skipping Remote Login enable. Run this script again after you've"
    warn "  populated ~/.ssh/authorized_keys (e.g. via Tailscale SSH or"
    warn "  by pasting your public key into the file directly)."
  fi
fi

# ── Enable Remote Login + reload (only when safe) ──
if $ENABLE_REMOTE_LOGIN && ! $DRY_RUN; then
  REMOTE_LOGIN=$(sudo systemsetup -getremotelogin 2>/dev/null | awk '{print $NF}')
  if [ "$REMOTE_LOGIN" != "On" ]; then
    info "Enabling macOS Remote Login..."
    sudo systemsetup -setremotelogin on
  else
    info "Remote Login already enabled"
  fi
  info "Reloading sshd..."
  sudo launchctl kickstart -k system/com.openssh.sshd 2>/dev/null || \
    sudo launchctl stop com.openssh.sshd 2>/dev/null || true
fi

# ── Firewall check ──
info "Checking macOS firewall..."
if $DRY_RUN; then
  info "[dry-run] Skipping firewall check"
else
  FW_STATE=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null | awk '{print $NF}' || echo "unknown")
  if [ "$FW_STATE" = "enabled." ]; then
    warn "Firewall is ON — make sure SSH (port 22) is allowed"
    warn "  Run: sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/sbin/sshd"
  else
    info "Firewall is off (SSH traffic will pass through)"
  fi
fi

# ── Temporary password-auth window (only if user opted in above) ──
if $TEMP_PASSWORD_FLOW && ! $DRY_RUN; then
  # Ensure password auth is locked down on exit/interrupt no matter what.
  lockdown() {
    sudo sed -i '' 's/PasswordAuthentication yes/PasswordAuthentication no/' "$HARDENED_CONF"
    sudo sed -i '' 's/AuthenticationMethods any/AuthenticationMethods publickey,keyboard-interactive:pam/' "$HARDENED_CONF"
    sudo launchctl kickstart -k system/com.openssh.sshd 2>/dev/null || true
    info "Password auth disabled — key-only access restored"
  }
  trap lockdown EXIT INT TERM

  sudo sed -i '' 's/PasswordAuthentication no/PasswordAuthentication yes/' "$HARDENED_CONF"
  sudo sed -i '' 's/AuthenticationMethods publickey,keyboard-interactive:pam/AuthenticationMethods any/' "$HARDENED_CONF"
  sudo launchctl kickstart -k system/com.openssh.sshd 2>/dev/null || true
  info "Password auth enabled temporarily"
  warn "From remote device, run: ssh-copy-id $(whoami)@<your-tailscale-ip-or-hostname>"
  warn "  (avoid pasting your public WAN IP here — prefer the tailnet address)"
  echo ""
  read -rp "Press Enter after you've copied the key to lock it back down..."
  lockdown
  trap - EXIT INT TERM
fi

echo ""
info "SSH server setup done"
warn "Test locally: ssh localhost"
