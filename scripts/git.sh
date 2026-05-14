#!/bin/bash
set -euo pipefail
TAG="git"
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

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
  # Write user.name/email to the (tracked) personal/work configs.
  # signingkey lives in ~/.gitconfig.local because the SSH key path is
  # machine-specific and shouldn't be committed.
  cat > "$DOTFILES_DIR/configs/.gitconfig-personal" <<EOF
[user]
    name = $personal_name
    email = $personal_email
# signingkey: machine-local — set in ~/.gitconfig.local
EOF

  cat > "$DOTFILES_DIR/configs/.gitconfig-work" <<EOF
[user]
    name = $work_name
    email = $work_email
# signingkey: machine-local — set in ~/.gitconfig.local
EOF

  # Machine-local signing config. Per-account keys generated below.
  # Verifiers (GitHub) need the same key registered as a "Signing key" on
  # the account, in addition to the auth key — separate dropdowns on
  # github.com/settings/keys.
  cat > "$HOME/.gitconfig.local" <<EOF
[user]
    signingkey = ~/.ssh/id_ed25519_personal.pub
[gpg]
    format = ssh
[commit]
    gpgsign = true
[tag]
    gpgsign = true

# Override per work scope: when remote matches oss.navercorp.com, use the work key.
[includeIf "hasconfig:remote.*.url:https://**oss.navercorp.com/**"]
    path = ~/.gitconfig.local-work
[includeIf "hasconfig:remote.*.url:git@**oss.navercorp.com:**"]
    path = ~/.gitconfig.local-work
[includeIf "hasconfig:remote.*.url:ssh://**oss.navercorp.com/**"]
    path = ~/.gitconfig.local-work
EOF

  cat > "$HOME/.gitconfig.local-work" <<EOF
[user]
    signingkey = ~/.ssh/id_ed25519_work.pub
EOF
fi

# ── Project directories ──
# Convention: company repos live under ~/work/, personal repos under ~/personal/.
# Git account selection is remote-URL-based (see configs/.gitconfig), but the
# company overlay's project-scoped MCP config lives at ~/work/.mcp.json — so
# Claude Code automatically picks up company MCP servers when started in any
# ~/work/<repo>/ directory, and leaves them out everywhere else.
if ! $DRY_RUN; then
  mkdir -p "$HOME/work" "$HOME/personal"
fi

# ── Generate SSH keys ──
generate_ssh_key() {
  local name="$1"
  local email="$2"
  local key_file="$HOME/.ssh/id_ed25519_$name"
  local pub_file="${key_file}.pub"

  if [ -f "$key_file" ] && [ -f "$pub_file" ]; then
    info "SSH key already exists: $key_file (with .pub)"
    return
  fi

  if [ -f "$key_file" ] && [ ! -f "$pub_file" ]; then
    warn "Found $key_file but no .pub — regenerating .pub from private key"
    if ! $DRY_RUN; then
      ssh-keygen -y -f "$key_file" > "$pub_file"
      chmod 644 "$pub_file"
    fi
    return
  fi

  info "Generating SSH key: $name ($email)"
  if $DRY_RUN; then
    info "[dry-run] Skipping ssh-keygen"
  else
    read -rp "Use a passphrase for $name key? (Y/n) " want_pw
    if [[ "$want_pw" =~ ^[Nn]$ ]]; then
      ssh-keygen -t ed25519 -C "$email" -f "$key_file" -N ""
    else
      ssh-keygen -t ed25519 -C "$email" -f "$key_file"
    fi
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
# macOS Sequoia+ no longer auto-loads keys into ssh-agent on session start, so
# we use --apple-use-keychain to persist the passphrase in the user's Keychain.
# That way every shell — and signed-commit invocation — picks up the key
# without re-prompting.
#
# IMPORTANT: ssh-add needs to prompt for the passphrase the FIRST time. We
# can't safely do that here (the install script is running non-interactively
# from install.sh's perspective), so we just record which keys still need to
# be registered and surface them in the final warning block below.
KEYS_NEEDING_AGENT=()
if ! $DRY_RUN; then
  eval "$(ssh-agent -s)" >/dev/null 2>&1
  # ssh-add -l exits 1 when the agent has no identities — expected on a fresh
  # agent. Swallow that so `set -euo pipefail` doesn't kill the script silently.
  loaded_fingerprints=$(ssh-add -l 2>/dev/null | awk '{print $2}' || true)
  for key in id_ed25519_personal id_ed25519_work; do
    [ -f "$HOME/.ssh/$key" ] || continue
    fp=$(ssh-keygen -lf "$HOME/.ssh/$key.pub" 2>/dev/null | awk '{print $2}')
    if echo "$loaded_fingerprints" | grep -Fxq "$fp"; then
      info "$key already in ssh-agent"
    else
      KEYS_NEEDING_AGENT+=("$key")
    fi
  done
fi

# ── Global gitignore ──
# install.sh creates the symlink; we just register it as the global excludesfile.
# Path is recorded as-is — git resolves it lazily, so the symlink doesn't need
# to exist yet.
if $DRY_RUN; then
  info "[dry-run] git config --global core.excludesfile ~/.gitignore_global"
else
  git config --global core.excludesfile "$HOME/.gitignore_global"
fi

echo ""
info "Git setup done"
echo ""
warn "═══════════════════════════════════════════════════════════════"
warn "  REQUIRED MANUAL STEPS — git won't push/sign correctly until done"
warn "═══════════════════════════════════════════════════════════════"
warn ""

# 1. ssh-agent / Keychain registration
if [ "${#KEYS_NEEDING_AGENT[@]}" -gt 0 ]; then
  warn "1) Register SSH keys with ssh-agent + macOS Keychain (one-time, per key):"
  for key in "${KEYS_NEEDING_AGENT[@]}"; do
    warn "     ssh-add --apple-use-keychain ~/.ssh/$key"
  done
  warn "     # ssh-add will prompt for each key's passphrase. After this every"
  warn "     # shell + signed commit picks the key up automatically."
  warn "     # Verify:  ssh-add -l   (both keys should appear)"
else
  info "1) ssh-agent registration: already done ✓"
fi
warn ""

# 2. Public key registration on git hosts
warn "2) Register the PUBLIC keys on each git host as BOTH Auth + Signing keys."
warn "   (Signing is a separate dropdown on GitHub — needed for 'Verified' badge.)"
warn ""
warn "   Personal (github.com):"
warn "     pbcopy < ~/.ssh/id_ed25519_personal.pub"
warn "     # then open: https://github.com/settings/keys → New SSH key"
warn ""
warn "   Work — public GitHub repos you contribute to as your work identity:"
warn "     pbcopy < ~/.ssh/id_ed25519_work.pub"
warn "     # then open: https://github.com/settings/keys (separate account)"
warn ""
warn "   Work — corporate GitHub Enterprise (if any):"
warn "     pbcopy < ~/.ssh/id_ed25519_work.pub"
warn "     # paste at: https://<your-internal-git-host>/settings/keys"
warn "     # e.g. https://oss.navercorp.com/settings/keys"
warn ""

# 3. Sanity check
warn "3) Verify auth works on each host:"
warn "     ssh -T git@github.com                    # 'Hi <user>!'"
warn "     ssh -T git@<your-internal-git-host>      # 'Hi <user>!'"
warn ""
