#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
GATHER="$ROOT_DIR/tools/context-gatherer.sh"
[[ -x "$GATHER" ]] || chmod +x "$GATHER"

workdir="$ROOT_DIR/.agent-os/tmp-tests/gatherer-claude"
mkdir -p "$workdir"

# Ensure minimal input
cat > "$ROOT_DIR/spec.md" << 'EOF'
# Title

## Requirements
r
EOF

out="$workdir/out-forced.md"
# Simulate Claude environment; optimization forced to run
CLAUDE_CODE=1 CONTEXT_OPTIMIZE=1 CONTEXT_OPTIMIZE_FORCE=1 CONTEXT_SUMMARIZE_THRESHOLD=1 bash "$GATHER" --operation create-spec gather-context repo "$out" 2>"$workdir/stderr.log"

[[ -s "$out" ]] || { echo "FAIL: no output from gatherer"; exit 1; }
# Since summarize threshold is minimal, expect summary marker
if ! grep -q "\[summary\]" "$out"; then
  echo "FAIL: expected summary marker not found in forced run"
  exit 1
fi

echo "PASS: claude force override"
