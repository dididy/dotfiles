#!/usr/bin/env bats
# Smoke tests: every script parses, dry-runs cleanly, and follows our conventions.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

@test "bash -n parses all scripts" {
  while IFS= read -r f; do
    run bash -n "$f"
    [ "$status" -eq 0 ] || { echo "syntax error in $f: $output"; return 1; }
  done < <(find "$REPO_ROOT/scripts" "$REPO_ROOT/install.sh" -type f -name "*.sh")
}

@test "every script uses set -euo pipefail" {
  while IFS= read -r f; do
    grep -q "set -euo pipefail" "$f" || { echo "missing set -euo pipefail: $f"; return 1; }
  done < <(find "$REPO_ROOT/scripts" "$REPO_ROOT/install.sh" -type f -name "*.sh" -not -path "*/lib/*")
}

@test "Brewfile parses (brew bundle list)" {
  if ! command -v brew >/dev/null 2>&1; then
    skip "brew not installed"
  fi
  run brew bundle list --file="$REPO_ROOT/Brewfile"
  [ "$status" -eq 0 ]
}
