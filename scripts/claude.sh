#!/bin/bash
set -euo pipefail
TAG="claude"
# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

info "Setting up Claude Code..."

if $DRY_RUN; then
  info "[dry-run] ralph install-skills"
else
  if ralph install-skills; then
    info "ralph install-skills done"
  else
    info "⚠️  ralph install-skills failed"
  fi
fi

# npm 11.x breaks npx for packages not in package.json
if ! command -v skills &>/dev/null; then
  if $DRY_RUN; then
    info "[dry-run] npm install -g skills"
  else
    if npm install -g skills; then
      info "skills CLI installed"
    else
      info "⚠️  skills CLI install failed"
    fi
  fi
fi

SKILL_REPOS=(
  "voidmatcha/e2e-skills"
  "voidmatcha/ui-clone-skills"
  "blader/humanizer"
  "epoko77-ai/im-not-ai"
  "forrestchang/andrej-karpathy-skills@karpathy-guidelines"
  # obra/superpowers: removed — already installed via `superpowers@claude-plugins-official`
  # plugin (which pins to a tested sha, more stable than tracking main).
  "vercel-labs/agent-skills"
  "anthropics/skills@frontend-design"
  "anthropics/skills@doc-coauthoring"        # handover docs / specs
  "anthropics/skills@internal-comms"         # status reports / FAQs
  "anthropics/skills@webapp-testing"         # cake-pc-web Playwright
  "anthropics/skills@mcp-builder"            # author new MCP servers
  "anthropics/skills@skill-creator"          # author / tune custom skills
  "supercent-io/skills-template@security-best-practices"
  "supercent-io/skills-template@code-review"
  "yeachan-heo/oh-my-claudecode@ultrawork"
  "yeachan-heo/oh-my-claudecode@project-session-manager"  # worktree + tmux + gh/jira issue pipeline (psm fix/review/feature)
  "yeachan-heo/oh-my-claudecode@ai-slop-cleaner"           # regression-safe deletion-first cleanup of AI-generated code
)

SKILL_URLS=(
  "https://github.com/pbakaus/impeccable --skill clarify"
)

for repo in "${SKILL_REPOS[@]}"; do
  if $DRY_RUN; then
    info "[dry-run] skills add $repo --yes --global"
  else
    if skills add "$repo" --yes --global 2> >(grep -v "invalid option" >&2); then
      info "Installed: $repo"
    else
      info "⚠️  Failed: $repo"
    fi
  fi
done

for url_args in "${SKILL_URLS[@]}"; do
  if $DRY_RUN; then
    info "[dry-run] npx skills add $url_args --yes --global"
  else
    # shellcheck disable=SC2086
    # url_args intentionally stores pre-tokenized flags.
    if npx skills add $url_args --yes --global 2> >(grep -v "invalid option" >&2); then
      info "Installed: $url_args"
    else
      info "⚠️  Failed: $url_args"
    fi
  fi
done

PLUGIN_MARKETPLACES=(
  "openai/codex-plugin-cc"
  # wshobson/agents — 80+ focused plugins (185 agents, 153 skills, 100 commands)
  # registered under the marketplace id `claude-code-workflows`.
  # Catalog: https://github.com/wshobson/agents/blob/main/docs/plugins.md
  "wshobson/agents"
  # thedotmack/claude-mem — persistent memory + cross-session search (~75k★).
  # Hooks SessionStart/End + 5 others, SQLite + Chroma vector DB, MCP search tools,
  # web viewer at localhost:37777, <private> tag for sensitive content.
  "thedotmack/claude-mem"
)

PLUGINS=(
  "ralph-loop@claude-plugins-official"
  "codex@openai-codex"
  "superpowers@claude-plugins-official"
  "rust-analyzer-lsp@claude-plugins-official"
  "fakechat@claude-plugins-official"
  "vercel@claude-plugins-official"
  "session-report@claude-plugins-official"
  "claude-md-management@claude-plugins-official"
  "hookify@claude-plugins-official"

  # wshobson/agents — one plugin per role. Each is isolated (own agents +
  # commands + skills); only what you install is loaded into context.
  "comprehensive-review@claude-code-workflows"          # architect + code-review + security
  "javascript-typescript@claude-code-workflows"         # cake-pc-web stack
  "python-development@claude-code-workflows"
  "frontend-mobile-development@claude-code-workflows"
  "security-scanning@claude-code-workflows"             # SAST
  "documentation-generation@claude-code-workflows"      # OpenAPI / mermaid / tutorials
  "unit-testing@claude-code-workflows"                  # pytest + jest generators
  "git-pr-workflows@claude-code-workflows"
  "tdd-workflows@claude-code-workflows"                 # test-first methodology
  "error-debugging@claude-code-workflows"               # error analysis + trace debugging
  "ui-design@claude-code-workflows"                     # iOS/Android/RN/web UI guidance
  "accessibility-compliance@claude-code-workflows"      # WCAG auditing
  "content-marketing@claude-code-workflows"
  "seo-content-creation@claude-code-workflows"
  "seo-technical-optimization@claude-code-workflows"    # meta tags, schema markup
  "seo-analysis-monitoring@claude-code-workflows"

  # thedotmack/claude-mem — persistent memory across sessions
  "claude-mem@thedotmack"
)

info "Installing Claude Code Plugins..."

for marketplace in "${PLUGIN_MARKETPLACES[@]}"; do
  if $DRY_RUN; then
    info "[dry-run] claude plugin marketplace add $marketplace"
  else
    if claude plugin marketplace add "$marketplace"; then
      info "Added marketplace: $marketplace"
    else
      info "⚠️  Failed marketplace: $marketplace"
    fi
  fi
done

for plugin in "${PLUGINS[@]}"; do
  if $DRY_RUN; then
    info "[dry-run] claude plugin install $plugin"
  else
    if claude plugin install "$plugin"; then
      info "Installed plugin: $plugin"
    else
      info "⚠️  Failed plugin: $plugin"
    fi
  fi
done

# Codex CLI is required by codex@openai-codex; install if missing.
if ! command -v codex >/dev/null 2>&1; then
  if $DRY_RUN; then
    info "[dry-run] npm install -g @openai/codex"
  else
    if npm install -g @openai/codex; then
      info "Codex CLI installed"
    else
      info "⚠️  Codex CLI install failed"
    fi
  fi
fi

# ── MCP servers (user scope) ──
# Claude Code stores user-scope MCP entries in ~/.claude.json (managed via
# `claude mcp add-json`). Symlinking configs/mcp.json into ~/.claude/.mcp.json
# does NOT work — verified: `claude mcp add --scope user` writes to
# ~/.claude.json directly.
register_mcp_from_file() {
  local mcp_file="$1"
  if [ ! -f "$mcp_file" ]; then
    return 0
  fi
  if ! command -v jq &>/dev/null || ! command -v claude &>/dev/null; then
    warn "jq or claude not available — skipping MCP registration from $mcp_file"
    return 0
  fi

  # Load dev/user secrets so any ${VAR} placeholders in mcp.json expand below.
  # ~/.dev.secrets.env is gitignored (*.secrets.env in .gitignore).
  # Public mcp.json currently has no ${VAR} placeholders, but this keeps the
  # door open for adding entries that need keys later without code changes.
  if [ -f "$HOME/.dev.secrets.env" ]; then
    # shellcheck source=/dev/null
    set -a; . "$HOME/.dev.secrets.env"; set +a
  fi

  local names
  names=$(jq -r '.mcpServers | keys[]' "$mcp_file" 2>/dev/null)
  while IFS= read -r name; do
    [ -z "$name" ] && continue
    local entry
    # Use --arg to safely pass the key (avoids jq filter string-interpolation injection).
    # envsubst expands ${VAR} with an explicit allowlist; anything else stays
    # as a literal $VAR. Missing key → empty string (JSON still valid).
    # Extend the allowlist as new keys are added to mcp.json.
    entry=$(jq -c --arg n "$name" '.mcpServers[$n]' "$mcp_file" \
      | envsubst '${EXA_API_KEY}')
    if $DRY_RUN; then
      info "[dry-run] claude mcp add-json --scope user $name '$entry'"
      continue
    fi
    # Remove first (idempotent), then add. Suppress "not found" errors on first run.
    claude mcp remove --scope user "$name" >/dev/null 2>&1 || true
    if claude mcp add-json --scope user "$name" "$entry" >/dev/null 2>&1; then
      info "Registered MCP: $name"
    else
      warn "Failed to register MCP: $name"
    fi
  done <<< "$names"
}

info "Registering user-scope MCP servers from configs/mcp.json..."
register_mcp_from_file "$DOTFILES_DIR/configs/mcp.json"

# session-wrap plugin
if ! [ -d ~/.claude/plugins/session-wrap ]; then
  if $DRY_RUN; then
    info "[dry-run] install session-wrap plugin"
  else
    TMPDIR=$(mktemp -d)
    if git clone https://github.com/team-attention/plugins-for-claude-natives "$TMPDIR" \
      && cp -r "$TMPDIR/plugins/session-wrap" ~/.claude/plugins/; then
      info "Installed plugin: session-wrap"
    else
      info "⚠️  Failed plugin: session-wrap"
    fi
    rm -rf "$TMPDIR"
  fi
else
  info "session-wrap already installed, skipping"
fi

info "Claude Code setup done"
