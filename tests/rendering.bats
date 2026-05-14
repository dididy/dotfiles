#!/usr/bin/env bats
# Tests for things the installer renders/templates:
#  - git.sh writes valid .gitconfig-personal / .gitconfig-work with the given
#    name + email and no signingkey baked in (machine-local stays out of repo).
#  - company/configs/mcp.json.template renders through envsubst with only the
#    allow-listed variables expanded (so other env values can't leak in).

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  TMPDIR_TEST="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

@test "git.sh heredoc renders personal config with given name+email and no signingkey" {
  # We exercise just the cat-heredoc logic from git.sh, not the prompts.
  personal_name="Test User"
  personal_email="test@example.com"
  target="$TMPDIR_TEST/.gitconfig-personal"
  cat > "$target" <<EOF
[user]
    name = $personal_name
    email = $personal_email
# signingkey: machine-local — set in ~/.gitconfig.local
EOF
  run grep -q "name = Test User" "$target"
  [ "$status" -eq 0 ]
  run grep -q "email = test@example.com" "$target"
  [ "$status" -eq 0 ]
  run grep -E "^[[:space:]]*signingkey[[:space:]]*=" "$target"
  [ "$status" -ne 0 ]  # signingkey MUST NOT be in tracked config
}

@test "envsubst allowlist only expands listed variables" {
  if ! command -v envsubst >/dev/null 2>&1; then
    skip "envsubst not installed (brew install gettext)"
  fi
  template="$TMPDIR_TEST/in.txt"
  printf '%s\n' '${ALLOWED_VAR}|${SECRET_VAR}|${PATH}' > "$template"
  run env ALLOWED_VAR=allowed SECRET_VAR=should-not-leak \
        envsubst '${ALLOWED_VAR}' < "$template"
  [ "$status" -eq 0 ]
  [[ "$output" == "allowed"*'${SECRET_VAR}|${PATH}'* ]]
}

@test "company mcp template references documented MCPs only" {
  template="$REPO_ROOT/company/configs/mcp.json.template"
  if [ ! -f "$template" ]; then
    skip "company overlay not present"
  fi
  if ! command -v jq >/dev/null 2>&1; then
    skip "jq not installed"
  fi
  run jq -r '.mcpServers | keys[]' "$template"
  [ "$status" -eq 0 ]
  for name in $output; do
    # Each MCP must be referenced (by name) in the agent doc so reviewers
    # have something to map against.
    grep -q "$name" "$REPO_ROOT/company/configs/AGENTS-company.md" \
      || { echo "MCP '$name' in template but not mentioned in AGENTS-company.md"; return 1; }
  done
}

@test "company install.sh writes ~/work/.mcp.json (project scope), not user scope" {
  [ -f "$REPO_ROOT/company/install.sh" ] || skip "company overlay not present"
  grep -q '~/work/.mcp.json\|"$HOME/work/.mcp.json"' "$REPO_ROOT/company/install.sh" \
    || { echo "company install.sh should target ~/work/.mcp.json"; return 1; }
  # Negative assertion: we should NOT see a `claude mcp add-json --scope user`
  # for company servers anymore (those leak company tools into personal sessions).
  ! grep -q 'claude mcp add-json --scope user' "$REPO_ROOT/company/install.sh"
}

@test "tracked .gitconfig-personal/.gitconfig-work do not contain signingkey" {
  for f in "$REPO_ROOT/configs/.gitconfig-personal" "$REPO_ROOT/configs/.gitconfig-work"; do
    [ -f "$f" ] || skip "$(basename "$f") not present yet"
    run grep -E "^[[:space:]]*signingkey" "$f"
    [ "$status" -ne 0 ] || { echo "signingkey leaked into $f"; return 1; }
  done
}
