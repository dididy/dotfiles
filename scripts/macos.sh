#!/bin/bash
set -euo pipefail

DRY_RUN="${DRY_RUN:-false}"

GREEN='\033[0;32m'
NC='\033[0m'
info() { echo -e "${GREEN}[macos]${NC} $1"; }

run_defaults() {
  if $DRY_RUN; then
    info "[dry-run] defaults $*"
  else
    defaults "$@"
  fi
}

# ── Dock ──
info "Configuring Dock..."
run_defaults write com.apple.dock autohide -bool true
run_defaults write com.apple.dock tilesize -int 36
run_defaults write com.apple.dock show-recents -bool false
run_defaults write com.apple.dock minimize-to-application -bool true
# Enable "Show Desktop" trackpad gesture
run_defaults write com.apple.dock showDesktopGestureEnabled -bool true

# ── Finder ──
info "Configuring Finder..."
run_defaults write com.apple.finder AppleShowAllFiles -bool true
run_defaults write com.apple.finder ShowPathbar -bool true
run_defaults write com.apple.finder ShowStatusBar -bool true
run_defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
run_defaults write NSGlobalDomain AppleShowAllExtensions -bool true
# Disable extension change warning
run_defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# ── Keyboard ──
info "Configuring keyboard..."
run_defaults write NSGlobalDomain KeyRepeat -int 1
run_defaults write NSGlobalDomain InitialKeyRepeat -int 10
run_defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# CapsLock → Escape (persistent via hidutil + LaunchAgent)
info "Mapping CapsLock → Escape..."
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
if ! $DRY_RUN; then
  mkdir -p "$LAUNCH_AGENTS_DIR"
  cat > "$LAUNCH_AGENTS_DIR/com.user.capslock-escape.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.user.capslock-escape</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/hidutil</string>
    <string>property</string>
    <string>--set</string>
    <string>{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x700000029}]}</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
PLIST
  launchctl load "$LAUNCH_AGENTS_DIR/com.user.capslock-escape.plist" 2>/dev/null || true
  hidutil property --set '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x700000029}]}'
else
  info "[dry-run] Skipping CapsLock → Escape"
fi

# Input source switch → Command+Space, Spotlight → Option+Space
info "Configuring input source / Spotlight shortcuts..."
# Spotlight: move to Option+Space (key 64 = Show Spotlight search)
run_defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 \
  "<dict><key>enabled</key><true/><key>value</key><dict><key>type</key><string>standard</string><key>parameters</key><array><integer>32</integer><integer>49</integer><integer>524288</integer></array></dict></dict>"
# Disable Spotlight window shortcut (key 65)
run_defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 65 \
  "<dict><key>enabled</key><false/></dict>"
# Disable previous input source shortcut (key 60) — use key 61 only
run_defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 60 \
  "<dict><key>enabled</key><false/></dict>"
# Input source switch (next source) → Command+Space (key 61)
run_defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 61 \
  "<dict><key>enabled</key><true/><key>value</key><dict><key>type</key><string>standard</string><key>parameters</key><array><integer>32</integer><integer>49</integer><integer>1048576</integer></array></dict></dict>"
# Apply shortcut changes immediately
if ! $DRY_RUN; then
  /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
fi

# ── Trackpad ──
info "Configuring trackpad..."
run_defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
run_defaults write NSGlobalDomain com.apple.swipescrolldirection -bool true
# Three-finger drag (via Accessibility path)
run_defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true
run_defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -bool true

# ── Screenshots ──
info "Configuring screenshots..."
SCREENSHOT_DIR="$HOME/Screenshots"
if ! $DRY_RUN; then
  mkdir -p "$SCREENSHOT_DIR"
fi
run_defaults write com.apple.screencapture location -string "$SCREENSHOT_DIR"
run_defaults write com.apple.screencapture type -string "png"

# ── Misc ──
info "Other settings..."
# Don't create .DS_Store on network/USB drives
run_defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
run_defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Apply changes
if ! $DRY_RUN; then
  killall Dock 2>/dev/null || true
  killall Finder 2>/dev/null || true
  killall SystemUIServer 2>/dev/null || true
fi

info "macOS settings done"
