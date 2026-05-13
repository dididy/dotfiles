# dotfiles

My opinionated macOS dev setup. Three goals: AI-assisted by default (Claude Code, opencode, hermes-agent, codex CLI side-by-side), remote access via Tailscale (private mesh, no public ports) with both OpenSSH and Tailscale SSH enabled side-by-side, and reproducible (idempotent scripts, `--dry-run`, CI-checked with shellcheck + `bash -n` + Brewfile validation + bats).

Clone and run `install.sh`. It'll ask for confirmation before starting, then prompt for git name/email when it gets there.

## Quick start

```bash
git clone --recurse-submodules https://github.com/voidmatcha/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

The `--recurse-submodules` flag pulls the optional `company/` overlay if you
have access to the internal git host; without access the submodule clone fails
silently and the public `install.sh` proceeds normally.

## What gets installed

**Homebrew + apps** — packages from `Brewfile`, including the usual CLI tools (ripgrep/fd/bat/eza/fzf/zoxide/atuin/direnv/jq/delta/tmux) plus `bats-core` for shell-script tests, `uv` (Python tool installer used by serena), `gettext` (envsubst, used by company overlay), `git-filter-repo` (surgical history rewrites), and `docker` CLI (no Docker Desktop — pair with Rancher Desktop on hosts with licensing restrictions).

**macOS settings** — dock autohide, Finder tweaks, keyboard repeat rates, CapsLock → Escape, three-finger drag, screenshots to `~/Screenshots`.

**Dev tools:**
- nvm + Node.js LTS, corepack (pnpm + yarn)
- pyenv + latest Python 3
- SDKMAN + Java LTS + Maven
- Playwright CLI (for coding agents)
- whisper-cpp model (~1.5GB, large-v3-turbo)
- ccusage, rtk, agent-browser
- [serena](https://github.com/oraios/serena) — MCP server for semantic code navigation (LSP-backed). Installed via `uv tool install`, registered in `configs/mcp.json` with `--context claude-code --project-from-cwd`. `.zshrc` wraps `claude` to inject serena's system-prompt-override (counters Opus 4.7 bias toward built-in tools)
- [graphify](https://github.com/safishamsi/graphify) — Claude Code skill (`/graphify`) that turns any folder into a queryable knowledge graph. Installed via `pip install --user graphifyy && graphify install`
- [wrangler](https://developers.cloudflare.com/workers/wrangler/) — Cloudflare Workers/Pages/R2/D1 CLI

**Shell** — Oh My Zsh with zsh-autosuggestions, zsh-syntax-highlighting, zsh-completions.

**Git** — separate personal/work accounts via `includeIf`, each with its own SSH key. Commits and tags are SSH-signed by default (`gpg.format=ssh`, `commit.gpgsign=true`) using the same per-account key — register the public key as a Signing Key on GitHub to get a verified badge. A global `~/.gitignore_global` (symlink to `configs/.gitignore_global`) catches `.DS_Store`, editor leftovers, `.envrc`, `.env*`, etc., so individual repos don't have to.

**Claude Code:**
- Skills — agent-skills, clarify, code-review, e2e-skills, frontend-design, humanizer, im-not-ai, karpathy-guidelines, security-best-practices, superpowers, ui-skills, ultrawork
- Plugins — ralph-loop (iterative autonomous dev loops), [codex@openai-codex](https://github.com/openai/codex-plugin-cc) (delegate to / review with Codex from inside Claude Code; pulls in `@openai/codex` CLI), superpowers, rust-analyzer-lsp, fakechat, vercel, session-report, claude-md-management (`/revise-claude-md` + `claude-md-improver` audit skill), hookify
- Hooks — skill-eval (forced-eval prompt injection per Scott Spence pattern, ~84% activation rate), rtk-rewrite (auto-compresses Bash output, 60–90% token savings)
- MCP — chrome-devtools (browser control via Chrome DevTools Protocol), serena (semantic code intelligence). Defined in `configs/mcp.json`; `scripts/claude.sh` reads that file and registers each entry via `claude mcp add-json --scope user` (writes to `~/.claude.json`, not the older `.mcp.json` symlink path).
- Codex CLI — installed alongside via `codex@openai-codex`; `configs/codex/config.toml` enables the experimental `/goal` slash command (`[features].goals = true`, see https://developers.openai.com/codex/use-cases/follow-goals)
- Token saving — settings calibrated against [spilist's checklist gist](https://gist.github.com/spilist/c468cbf1ed0ffc91100f813aabdcd520) (verified against official docs). Claude Code: `includeGitInstructions: false` drops the built-in git workflow instructions + git status snapshot from the system prompt. `autoInstallIdeExtension: false` keeps Claude Code as a pure terminal tool — no auto-install of VS Code/JetBrains extensions. Codex: `web_search = "disabled"` drops the web_search tool definition (re-enable per-invocation with `codex --search`). `[features].apps = false` drops ChatGPT-connector tool definitions.

**opencode:**
- Brew tap — `anomalyco/tap` (third-party tap with current versions; homebrew-core formula is stale)
- npm plugins (auto-installed via Bun on first run from `opencode.json`):
  - `oh-my-openagent@latest` — Sisyphus/Oracle/Librarian/Explore agents + category-based delegation
  - `@ex-machina/opencode-anthropic-auth@1.8.0` — Anthropic OAuth refresh
- Config — `configs/opencode/{opencode.json, oh-my-openagent.json}` symlinked to `~/.config/opencode/`
- Auth — `opencode.sh` detects missing `~/.local/share/opencode/auth.json` and prompts to run `opencode auth login`
- AGENTS.md — same canonical file as Claude Code/Cursor (symlinked to `~/.config/opencode/AGENTS.md`)

**[Hermes Agent](https://github.com/NousResearch/hermes-agent):** Nous Research's self-improving AI agent. `hermes.sh` runs the upstream one-shot installer (`curl … | bash`) — idempotent, skips if `hermes` is already on PATH. Configure with `hermes setup` after a shell reload.

**tmux** — minimal `~/.tmux.conf` (symlinked from `configs/.tmux.conf`): `C-Space` prefix, mouse on, vi-mode copy, `|`/`-` splits that keep CWD, 100k scrollback, true-color.

**Auto-launched browser dev services (LaunchAgents):**
Both run at every login with `KeepAlive=true` (throttle 60s). Both are reached over the tailnet via `tailscale serve` (HTTPS via Tailscale's `*.ts.net` cert; configured automatically by `services.sh`). code-server binds to `127.0.0.1` (kernel-level isolation). purplemux binds to `*:8022` but enforces an app-level `networkAccess: "tailscale"` filter — non-tailnet/non-loopback IPs get HTTP 403 before auth. Defense-in-depth: `macos.sh` already enables the macOS firewall in stealth mode, so a hostile-wifi attacker sees stealthed ports even before reaching the app filter.

- `com.user.purplemux` — [purplemux](https://github.com/subicura/purplemux), web-native terminal multiplexer for Claude Code
  - Installed via `npm install -g purplemux` (services.sh handles this)
  - Listens on `*:8022` (no `--bind` flag upstream); enforces `networkAccess: "tailscale"` at the app layer. Logs at `~/Library/Logs/purplemux.{out,err}.log`
  - Tailnet exposure: `tailscale serve --bg --https=443 --set-path=/ http://localhost:8022`
  - Restart: `launchctl kickstart -k gui/$(id -u)/com.user.purplemux`
- `com.user.code-server` — [code-server](https://github.com/coder/code-server), VS Code in the browser
  - Installed via Brewfile (`brew "code-server"`)
  - Reads `~/.config/code-server/config.yaml` (services.sh scaffolds with a random password and enforces `chmod 600`)
  - Binds to `127.0.0.1:8088`. Logs at `~/Library/Logs/code-server.{out,err}.log`
  - Tailnet exposure: `tailscale serve --bg --https=8443 --set-path=/ http://localhost:8088`
  - Restart: `launchctl kickstart -k gui/$(id -u)/com.user.code-server`

**Shared agent config** — canonical `~/.agent/AGENTS.md` with shared rules, also symlinked to `~/.cursor/rules/AGENTS.md` and (after opencode setup) `~/.config/opencode/AGENTS.md`. `~/.claude/CLAUDE.md` imports it via `@AGENTS.md`.

**Dotfiles symlinks** — zshrc, tmux.conf, gitconfig, gitignore_global, Claude Code settings, skill-eval hook.

**Tailscale + Tailscale SSH** — private mesh VPN for remote access. Each device gets a stable `100.x.x.x` IP and `*.ts.net` hostname; no port forwarding, no public exposure. `tailscale.sh` runs `tailscale set --ssh` so inbound shell access can go through Tailscale (identity from the tailnet, ACL-gated in the admin console). Persistent sessions: `tailscale ssh yongjae@<host> -- tmux attach`. OpenSSH (`systemsetup -setremotelogin on`, set in `macos.sh`) is enabled in parallel — Tailscale SSH is the primary path, OpenSSH stays as a fallback for tooling that doesn't speak the Tailscale layer. Free tier covers personal use.

**mosh** — UDP-based shell that survives network changes / roaming / disconnects. Bootstraps over SSH for auth (so OpenSSH must stay enabled) then switches to UDP ports 60000–61000. Useful on mobile hotspots or unstable links. Connect with `mosh user@host` or `mosh --ssh="tailscale ssh" user@host` to layer mosh on top of Tailscale SSH. The macOS Application Firewall is in stealth mode, so the first `mosh` session may need a manual exception for `mosh-server` (System Settings → Network → Firewall → Options).

**Tests** — bats-core suites under `tests/` cover `scripts/lib/common.sh` helpers and a smoke check that every shell script parses, uses `set -euo pipefail`, and that the `Brewfile` resolves. Run with `bats tests/`.

## Structure

```
dotfiles/
├── install.sh              # main entry point
├── Brewfile                # Homebrew package list
├── scripts/
│   ├── brew.sh             # Homebrew install
│   ├── macos.sh            # macOS system settings
│   ├── dev.sh              # nvm, pyenv, Java, etc.
│   ├── shell.sh            # Oh My Zsh + plugins
│   ├── git.sh              # Git config + SSH keys
│   ├── claude.sh           # Claude Code skills, plugins, tools
│   ├── lib/
│   │   └── common.sh       # shared helpers (info/warn/error/run_or_dry/link_file)
│   ├── opencode.sh         # opencode config + auth prompt
│   ├── hermes.sh           # Hermes Agent (Nous Research) installer wrapper
│   ├── services.sh         # purplemux + code-server LaunchAgent installer
│   ├── purplemux-launch.sh # LaunchAgent wrapper for purplemux (PATH + node resolution)
│   ├── code-server-launch.sh # LaunchAgent wrapper for code-server
│   └── tailscale.sh        # Tailscale VPN + `tailscale set --ssh`
├── configs/
│   ├── .zshrc
│   ├── .tmux.conf
│   ├── .gitconfig
│   ├── .gitconfig-personal
│   ├── .gitconfig-work
│   ├── .gitignore_global
│   ├── AGENTS.md           # canonical agent rules (Claude + Cursor + opencode)
│   ├── CLAUDE.md           # Claude Code wrapper (imports AGENTS.md)
│   ├── claude-settings.json
│   ├── mcp.json            # shared MCP servers imported by oh-my-openagent
│   ├── com.user.purplemux.plist     # LaunchAgent template (sed-substituted at install)
│   ├── com.user.code-server.plist   # LaunchAgent template (sed-substituted at install)
│   ├── opencode/
│   │   ├── opencode.json           # opencode global config + plugin list
│   │   └── oh-my-openagent.json    # agents/categories with model fallbacks
│   ├── rtk-config.toml
│   └── hooks/
│       └── skill-eval.sh   # forced-eval prompt injection hook
├── tests/                  # bats-core suites: run `bats tests/`
│   ├── common.bats
│   └── scripts.bats
└── company/                # (gitignored) optional company overlay — see company/README.md
```

## Company overlay (optional)

For environments that require company-internal configuration (private plugin
marketplaces, image registries, scoped npm registries, team-issued API keys),
`install.sh` automatically invokes `company/install.sh` if that path exists.

`company/` is a **git submodule** pointing at a separate, internally-hosted
repo (URL listed in `.gitmodules`). The submodule URL is visible publicly but
the repository itself is only accessible over the internal network with proper
auth — clone fails gracefully outside the company.

On a new machine:
```bash
git clone --recurse-submodules https://github.com/voidmatcha/dotfiles.git ~/dotfiles
# or, if already cloned:
git -C ~/dotfiles submodule update --init
```

See `company/README.md` for what lives in the overlay and how to maintain it.

## Run individual scripts

```bash
./scripts/brew.sh     # Homebrew only
./scripts/macos.sh    # macOS settings only
./scripts/dev.sh      # dev tools only
./scripts/shell.sh    # shell only
./scripts/git.sh      # Git only
```

## Dry run

Preview without making changes:

```bash
./install.sh --dry-run
```

## Separate Git accounts

`~/personal/` repos → personal account
`~/work/` repos → work account

Run `git.sh` — it prompts for names and emails, with existing values pre-filled. Press Enter to keep them.

## SSH keys

`git.sh` generates separate keys for personal and work.
Add the public keys to GitHub after:

```bash
cat ~/.ssh/id_ed25519_personal.pub  # personal
cat ~/.ssh/id_ed25519_work.pub      # work
```
