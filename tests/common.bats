#!/usr/bin/env bats
# Tests for scripts/lib/common.sh

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  COMMON="$REPO_ROOT/scripts/lib/common.sh"
  TMPDIR_TEST="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

@test "common.sh sources cleanly with defaults" {
  run bash -c "source '$COMMON' && echo \"\$DOTFILES_DIR|\$DRY_RUN|\$TAG\""
  [ "$status" -eq 0 ]
  [[ "$output" == *"|false|dotfiles" ]]
}

@test "common.sh is idempotent (guard against double-source)" {
  run bash -c "source '$COMMON' && source '$COMMON' && echo ok"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "info/warn/error tag the output" {
  run bash -c "TAG=mytag; source '$COMMON'; info hello; warn careful; error boom"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[mytag]"*"hello"* ]]
  [[ "$output" == *"[mytag]"*"careful"* ]]
  [[ "$output" == *"[mytag]"*"boom"* ]]
}

@test "run_or_dry executes when DRY_RUN=false" {
  out="$TMPDIR_TEST/marker"
  run bash -c "DRY_RUN=false; source '$COMMON'; run_or_dry 'touch marker' touch '$out'"
  [ "$status" -eq 0 ]
  [ -f "$out" ]
}

@test "run_or_dry skips and announces in dry-run" {
  out="$TMPDIR_TEST/marker"
  run bash -c "DRY_RUN=true; source '$COMMON'; run_or_dry 'touch marker' touch '$out'"
  [ "$status" -eq 0 ]
  [ ! -f "$out" ]
  [[ "$output" == *"[dry-run]"* ]]
}

@test "link_file creates a symlink" {
  src="$TMPDIR_TEST/src"; dst="$TMPDIR_TEST/dst"
  echo hi > "$src"
  run bash -c "DRY_RUN=false; source '$COMMON'; link_file '$src' '$dst'"
  [ "$status" -eq 0 ]
  [ -L "$dst" ]
  [ "$(readlink "$dst")" = "$src" ]
}

@test "link_file backs up existing real file before linking" {
  src="$TMPDIR_TEST/src"; dst="$TMPDIR_TEST/dst"
  echo new > "$src"
  echo old > "$dst"
  run bash -c "DRY_RUN=false; source '$COMMON'; link_file '$src' '$dst'"
  [ "$status" -eq 0 ]
  [ -L "$dst" ]
  [ -f "${dst}.backup" ]
  [ "$(cat "${dst}.backup")" = "old" ]
}

@test "link_file is a no-op in dry-run" {
  src="$TMPDIR_TEST/src"; dst="$TMPDIR_TEST/dst"
  echo hi > "$src"
  run bash -c "DRY_RUN=true; source '$COMMON'; link_file '$src' '$dst'"
  [ "$status" -eq 0 ]
  [ ! -e "$dst" ]
}
