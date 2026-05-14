# dotfiles

My opinionated macOS dev setup. Three goals: AI-assisted by default (Claude Code, opencode, hermes-agent, codex CLI side-by-side), remote access via Tailscale (private mesh, no public ports) with both OpenSSH and Tailscale SSH enabled side-by-side, and reproducible (idempotent scripts, `--dry-run`, CI-checked with shellcheck + `bash -n` + Brewfile validation + bats).

Run `bootstrap.sh` (one curl line on a fresh Mac) or clone + `./install.sh`
manually. Either way it asks for confirmation before doing anything, then
prompts for git name/email when it gets to that step.

## Quick start (fresh machine, one-shot)

```bash
curl -fsSL https://raw.githubusercontent.com/voidmatcha/dotfiles/main/bootstrap.sh | bash
```

`bootstrap.sh` installs Xcode Command Line Tools if `git` is missing, clones
this repo (with submodules) into `~/dotfiles`, and hands off to `./install.sh`.
The `--recurse-submodules` step pulls the optional `company/` overlay if you
have access to the internal git host; without access the submodule clone
fails silently and `install.sh` proceeds normally.

Pass-through args work too:

```bash
curl -fsSL https://raw.githubusercontent.com/voidmatcha/dotfiles/main/bootstrap.sh | bash -s -- --dry-run
```

## Quick start (already cloned)

```bash
cd ~/dotfiles
./install.sh
```

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
- Social / web read CLIs (subset of what [agent-reach](https://github.com/Panniantong/Agent-Reach) bundles, installed directly to keep the dependency surface small):
  - `yt-dlp` — YouTube/Bilibili/1800+ sites, metadata + subtitles, no auth
  - `bird` (twitter-cli, via pipx) — X/Twitter read/search/timeline; `bird login` once for cookie capture
  - `rdt` (rdt-cli, via pipx) — Reddit search/read; `rdt login` once (Reddit requires auth since 2024)
  - `feedparser` (Python lib) — RSS/Atom feeds (blog/YouTube channel/GitHub releases/Hacker News etc.)
  - For any other URL, `curl https://r.jina.ai/<URL>` returns clean Markdown (Jina Reader, no install)
  - See `configs/AGENTS.md` for exact one-liners agents should call.
- MCP servers wired up by `configs/mcp.json` (registered via `claude mcp add-json --scope user`):
  - **chrome-devtools** — browser control
  - **serena** — semantic code intelligence
  - **linkedin** (`linkedin-scraper-mcp` via `uvx`) — LinkedIn profiles/companies/jobs (browser auth on first call). Excluded on internal NAVER machines — not yet security-reviewed.
  - **exa** — semantic web search + `web_fetch_exa` URL reader. Connects to Exa's hosted endpoint (`https://mcp.exa.ai/mcp`) anonymously — no API key needed for free-plan usage. Add `x-api-key` header (key from https://dashboard.exa.ai/) only if you hit the rate limit.
  - **context7** — up-to-date library/framework docs lookup. Connects to Context7's hosted endpoint (`https://mcp.context7.com/mcp`) anonymously for basic usage. The company overlay sources `CONTEXT7_API_KEY` from `~/.company.secrets.env` to lift rate limits when working under `~/work/`.
  - GitHub Operations on the public dotfiles use the `gh` CLI directly. The company overlay (if configured) can add a `github-enterprise` MCP for the corporate GitHub Enterprise host — see `company/configs/AGENTS-company.md`.

**Shell** — Oh My Zsh with zsh-autosuggestions, zsh-syntax-highlighting, zsh-completions.

**Git** — separate personal/work accounts via `includeIf` with **remote-URL-based** routing (see "Separate Git accounts" below). Commits and tags are SSH-signed by default — register the public key as a Signing Key on GitHub to get a verified badge. A global `~/.gitignore_global` (symlink to `configs/.gitignore_global`) catches `.DS_Store`, editor leftovers, `.envrc`, `.env*`, etc., so individual repos don't have to.

**Claude Code:**
- Skills — agent-skills, ai-slop-cleaner, clarify, code-review, doc-coauthoring, e2e-skills, frontend-design, humanizer, im-not-ai, internal-comms, karpathy-guidelines, mcp-builder, project-session-manager (`/psm`), security-best-practices, skill-creator, ui-clone-skills, ultrawork, webapp-testing
- Plugins — ralph-loop (iterative autonomous dev loops), [codex@openai-codex](https://github.com/openai/codex-plugin-cc) (delegate to / review with Codex from inside Claude Code; pulls in `@openai/codex` CLI), superpowers, rust-analyzer-lsp, fakechat, vercel, session-report, claude-md-management (`/revise-claude-md` + `claude-md-improver` audit skill), hookify, [claude-mem@thedotmack](https://github.com/thedotmack/claude-mem) (persistent memory + cross-session search), plus role-focused plugins from [wshobson/agents](https://github.com/wshobson/agents) marketplace (comprehensive-review, javascript-typescript, python-development, frontend-mobile-development, security-scanning, tdd-workflows, git-pr-workflows, error-debugging, ui-design, accessibility-compliance, content-marketing, seo-*)
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

Account selection is **remote-URL-based**, not directory-based — a repo's
location on disk doesn't matter, only its `remote.origin.url`:

- Remote matches the corporate git host → work account
  (`~/.gitconfig-work`)
- Anything else (or no remote yet) → personal account
  (`~/.gitconfig-personal`)

The exact host(s) that route to "work" live in `configs/.gitconfig`'s
`includeIf "hasconfig:remote.*.url:..."` blocks (currently set for the
maintainer's employer; fork and edit those patterns to match your own
internal git host — `https://`, `git@`, and `ssh://` URL forms are
each their own line). Requires **git 2.36+**.

The two account files (`configs/.gitconfig-personal` and `.gitconfig-work`)
carry only `user.name` and `user.email`. SSH `signingkey` paths are
**machine-specific** so they live in `~/.gitconfig.local` (gitignored),
with an optional `~/.gitconfig.local-work` for a separate work-account
signing key. `configs/.gitconfig` loads `~/.gitconfig.local` last, so it
always wins for signing/keys.

Run `git.sh` — it prompts for names and emails, then writes the two
account configs plus `~/.gitconfig.local` (default signing key path) and
`~/.gitconfig.local-work` (work signing key path).

### Where to put company repos: `~/work/`

Git identity routes by remote URL (above), but **MCP loading routes by
directory**. The company overlay writes its MCP config to
`~/work/.mcp.json` (project scope), and Claude Code picks it up only when
started inside `~/work/<repo>/`. So:

- **Keep company repos under `~/work/`** → company MCP servers
  (e.g. `github-enterprise`) auto-load on top of the personal set, and the
  overlay provides `CONTEXT7_API_KEY` to lift `context7` rate limits.
- Any other location → personal MCP only (`exa`, `linkedin`, `context7` — anon).
  Git author/signing still routes correctly via remote URL.

`git.sh` creates `~/work/` and `~/personal/` for you.

## SSH keys

`git.sh` generates separate keys for personal and work.
Add the public keys to GitHub after:

```bash
cat ~/.ssh/id_ed25519_personal.pub  # personal
cat ~/.ssh/id_ed25519_work.pub      # work
```
