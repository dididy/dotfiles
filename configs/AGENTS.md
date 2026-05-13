If something is ambiguous, stop. State what's unclear and ask.
Don't silently pick an interpretation and run with it.

Don't touch code unrelated to the request.
Don't clean up what you didn't break.

## Available tools

These are installed by this dotfiles setup. Prefer them over reinventing or
asking the user to install something new.

- **serena** (MCP) — semantic code navigation and editing backed by LSP. Use
  for cross-file renames, symbol lookups, reference searches, and refactors
  where text-level edits would be fragile. Semantic tools are active by
  default; serena's redundant basic utilities (read/grep/ls/bash equivalents)
  are auto-disabled because Claude Code already covers them. The shell
  wrapper in `.zshrc` injects serena's system-prompt-override automatically
  to counter Opus 4.7's strong bias toward built-in tools. https://github.com/oraios/serena
- **graphify** (Claude Code skill, `/graphify`) — build a queryable knowledge
  graph from any folder (code, docs, PDFs, images). Use when you need to
  understand structure of a large unfamiliar codebase or document set before
  diving in. 71x fewer tokens per query than re-reading raw files. https://github.com/safishamsi/graphify
- **defuddle** (npm CLI) — extract main content from a web page as Markdown.
  Use ad-hoc via `npx defuddle parse <url> --markdown` when summarizing or
  quoting articles; prefer this over scraping raw HTML. https://github.com/kepano/defuddle
- **rtk** — CLI output compressor that auto-applies to most Bash commands via
  hook. Saves 60-90% tokens. You'll see compressed output already; if you need
  the raw output, prepend `rtk proxy <cmd>` or run the command outside the
  hook-rewritten path.
- **ccusage** — `ccusage` CLI for analyzing your token usage from local JSONL.
- **agent-browser** — fast browser automation CLI (alternative to Playwright
  MCP for ad-hoc browsing). Prefer this over Playwright MCP per project rules.
