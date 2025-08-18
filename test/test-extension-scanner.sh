#!/usr/bin/env bash
set -euo pipefail

# Minimal test for tools/extensions/extension-scanner.sh
# Verifies front-matter-only filtering for targets and requires.

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
SCANNER="$ROOT_DIR/tools/extensions/extension-scanner.sh"

if [[ ! -f "$SCANNER" ]]; then
  echo "missing scanner: $SCANNER" >&2
  exit 1
fi

TMPDIR=$(mktemp -d 2>/dev/null || mktemp -d -t extscan)
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

# Create mock layout under repo instructions (repo scope)
BASE="$ROOT_DIR/instructions/extensions/create-spec"
mkdir -p "$BASE"

echo "---
description: Repo extension A
targets: [\"create-spec\"]
vendor: acme
---

# body not read" > "$BASE/repo-a.md"

echo "---
description: Requires Atlassian
targets: [\"create-spec\"]
requires: [\"mcp:atlassian\"]
vendor: atlassian
---

# body not read" > "$BASE/requires-atlassian.md"

# 1) No capabilities: should load repo-a, skip requires-atlassian
out1=$(bash "$SCANNER" --flow create-spec --scope repo --no-cache)
loaded1=$(echo "$out1" | grep -c 'repo-a.md') || true
skipped1=$(echo "$out1" | grep -c 'requires-atlassian.md') || true

if [[ "$loaded1" -lt 1 ]]; then
  echo "[FAIL] expected repo-a.md to load without capabilities" >&2
  exit 1
fi
if [[ "$skipped1" -lt 1 ]]; then
  echo "[FAIL] expected requires-atlassian.md to be skipped without capability" >&2
  exit 1
fi

# 2) With capability mcp:atlassian: both should load
out2=$(bash "$SCANNER" --flow create-spec --scope repo --capabilities mcp:atlassian --no-cache)
loaded2a=$(echo "$out2" | grep -c 'repo-a.md') || true
loaded2b=$(echo "$out2" | grep -c 'requires-atlassian.md') || true

if [[ "$loaded2a" -lt 1 || "$loaded2b" -lt 1 ]]; then
  echo "[FAIL] expected both files to load with capability" >&2
  echo "$out2" >&2
  exit 1
fi

echo "[PASS] extension scanner front-matter gating works"
