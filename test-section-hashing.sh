#!/usr/bin/env bash
# test-section-hashing.sh - Test script for demonstrating section hashing integration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR" && pwd)"

# Colorization for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
NC='\033[0m'

log() { echo -e "${BLUE}[test]${NC} $*"; }
success() { echo -e "${GREEN}[test][SUCCESS]${NC} $*"; }
info() { echo -e "${CYAN}[test][INFO]${NC} $*"; }
important() { echo -e "${YELLOW}[test][IMPORTANT]${NC} $*"; }

# Test 1: Run section-hash.sh on golden examples
log "Test 1: Running section-hash.sh on golden examples directory..."
bash "$ROOT_DIR/tools/section-hash.sh" "$ROOT_DIR/examples/golden" --dry-run

# Test 2: Create a temp markdown file with sections for testing
TEST_MD="$ROOT_DIR/temp-test-sections.md"

log "Test 2: Creating temporary test markdown file with sections..."
cat > "$TEST_MD" << EOL
# Test Section Hashing

This file demonstrates section hashing functionality.

## Overview

This is the overview section content.
It spans multiple lines.
And provides basic information.

## Requirements

These are the requirements:
1. Section hashing should work correctly
2. Changes should be detected
3. Token counts should be estimated

## Technical Details

Some technical details:
- Using sha256 for hashing
- Token estimation based on character count
- Section extraction using markdown headers
EOL

success "Created test file: $TEST_MD"

# Test 3: Run section-hash on our test file
log "Test 3: Running section-hash.sh on test file..."
bash "$ROOT_DIR/tools/section-hash.sh" "$ROOT_DIR" --files "temp-test-sections.md"

# Test 4: Modify a section and check for changes
log "Test 4: Modifying a section and checking for changes..."
sed -i 's/These are the requirements:/These are the updated requirements:/' "$TEST_MD" 2>/dev/null || \
sed -i '' 's/These are the requirements:/These are the updated requirements:/' "$TEST_MD"

info "Running section-hash.sh again to detect changes..."
bash "$ROOT_DIR/tools/section-hash.sh" "$ROOT_DIR" --files "temp-test-sections.md"

# Test 5: Test integration with context gatherer
log "Test 5: Testing integration with context-gatherer-simple.sh..."
info "Running context gatherer without section tracking..."
bash "$ROOT_DIR/tools/context-gatherer-simple.sh" --tier essential product test-without-sections.md

info "Running context gatherer with section tracking (if supported)..."
if grep -q "track-sections" "$ROOT_DIR/tools/context-gatherer-simple.sh"; then
  bash "$ROOT_DIR/tools/context-gatherer-simple.sh" --tier essential --track-sections product test-with-sections.md
  success "Context gatherer supports section tracking!"
else
  important "Context gatherer simple version doesn't support section tracking."
  important "Try using context-gatherer-enhanced.sh instead if available."
  
  if [[ -f "$ROOT_DIR/tools/context-gatherer-enhanced.sh" ]]; then
    info "Enhanced version found, running with section tracking..."
    bash "$ROOT_DIR/tools/context-gatherer-enhanced.sh" --tier essential --track-sections product test-with-sections.md
  fi
fi

# Clean up
log "Cleaning up test files..."
rm -f "$TEST_MD" test-without-sections.md test-with-sections.md

success "All tests completed!"
