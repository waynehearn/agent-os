#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
GATHER="$ROOT_DIR/tools/context-gatherer.sh"
[[ -x "$GATHER" ]] || chmod +x "$GATHER"

workdir="$ROOT_DIR/.agent-os/tmp-tests/gatherer-opt"
mkdir -p "$workdir"

# Create a sample spec.md to ensure there is some content to gather
cat > "$ROOT_DIR/spec.md" << 'EOF'
# Spec Agent K

## Requirements
Must be efficient.

## Constraints
Use bash scripts.

## Implementation
Details...

## Architecture
Overview...
EOF

out="$workdir/repo-context.md"
CONTEXT_OPTIMIZE=1 CONTEXT_SUMMARIZE_THRESHOLD=60 CONTEXT_OPTIMIZE_MODE=lossless bash "$GATHER" --operation create-spec gather-context repo "$out"

[[ -s "$out" ]] || { echo "FAIL: no output from gatherer"; exit 1; }
grep -q "## Context Summary" "$out" || { echo "FAIL: missing summary"; exit 1; }

echo "PASS: gatherer optimize integration"
