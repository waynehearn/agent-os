#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
GATHER="$ROOT_DIR/tools/context-gatherer.sh"
[[ -x "$GATHER" ]] || chmod +x "$GATHER"

workdir="$ROOT_DIR/.agent-os/tmp-tests/gatherer-claude"
mkdir -p "$workdir"

# Ensure minimal input
: > "$ROOT_DIR/spec.md"

out="$workdir/out.md"
# Simulate Claude environment; optimization requested but should be auto-disabled
CLAUDE_CODE=1 CONTEXT_OPTIMIZE=1 bash "$GATHER" --operation create-spec gather-context repo "$out" 2>"$workdir/stderr.log"

[[ -s "$out" ]] || { echo "FAIL: no output from gatherer"; exit 1; }
# Expect a warning about auto-disabling
if ! grep -q "Auto-disabling context optimization under Claude" "$workdir/stderr.log"; then
  echo "FAIL: expected auto-disable warning not found"
  exit 1
fi

echo "PASS: claude auto-disable"
