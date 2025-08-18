#!/usr/bin/env bash
set -euo pipefail

# Smoke test for tools/context-optimizer.sh on Windows Git Bash
# Validates CRLF normalization, chunking, and summarization path.

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TOOL="$ROOT_DIR/tools/context-optimizer.sh"
[[ -x "$TOOL" ]] || chmod +x "$TOOL"

workdir="$ROOT_DIR/.agent-os/tmp-tests/context-optimizer"
mkdir -p "$workdir"

# Create a CRLF sample with headings and a long code block
cat > "$workdir/sample.md" << 'EOF'
# Title

Intro paragraph.

## Section A
- item 1
- item 2

```js
// many lines to force summarization
function x(){ return 1 }
function y(){ return 2 }
function z(){ return 3 }
function a(){ return 4 }
function b(){ return 5 }
function c(){ return 6 }
function d(){ return 7 }
function e(){ return 8 }
function f(){ return 9 }
function g(){ return 10 }
```

## Section B
Some tail text.
EOF

out_md="$workdir/out.md"
out_meta="$workdir/out.meta.json"

bash "$TOOL" --input "$workdir/sample.md" --output "$out_md" --metadata-out "$out_meta" --summarize-threshold 60 --compression lossless --dedupe 1

# Assertions
[[ -s "$out_md" ]] || { echo "FAIL: no output generated"; exit 1; }
[[ -s "$out_meta" ]] || { echo "FAIL: no metadata generated"; exit 1; }

# Ensure CRs were removed in processing result (output should not contain \r)
if grep -q $'\r' "$out_md"; then
  echo "FAIL: output contains CR characters"
  exit 1
fi

# Metadata should be valid-ish JSON and contain keys
grep -q '"total_tokens_before"' "$out_meta" || { echo "FAIL: meta missing total_tokens_before"; exit 1; }
grep -q '"chunks"' "$out_meta" || { echo "FAIL: meta missing chunks"; exit 1; }

# Ensure summary markers appear (due to low threshold)
grep -q "\[summary\]" "$out_md" || { echo "FAIL: summary marker missing"; exit 1; }

echo "PASS: context-optimizer smoke"
