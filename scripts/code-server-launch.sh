#!/bin/bash
set -euo pipefail

# LaunchAgent has a minimal PATH; restore homebrew + tailscale.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

if ! command -v code-server >/dev/null 2>&1; then
  echo "[code-server] code-server not found in PATH — install with 'brew install code-server'" >&2
  exit 78
fi

# code-server reads ~/.config/code-server/config.yaml (bind-addr, auth, password).
# Default in this repo: 127.0.0.1:8088. For tailnet access, front it with
# `tailscale serve` (HTTPS via tailnet cert) — never expose 8088 on 0.0.0.0.
exec code-server
