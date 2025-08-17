#!/usr/bin/env bash
# Test modifying a file to see if section tracking detects changes

set -euo pipefail

# Create a test markdown file with sections
TEST_FILE="test-markdown-sections.md"

echo "Creating test markdown file..."
cat > "$TEST_FILE" << EOL
# Test File

This is a test file with sections.

## Overview

This is the overview section.
It contains important information.

## Requirements

These are the requirements:
1. First requirement
2. Second requirement
EOL

echo "Running context gatherer with section tracking for the first time..."
./tools/context-gatherer-with-sections.sh --tier essential --track-sections product test-output-1.md

echo "Modifying the Overview section..."
sed -i 's/This is the overview section./This is the MODIFIED overview section./' "$TEST_FILE" 2>/dev/null || \
sed -i '' 's/This is the overview section./This is the MODIFIED overview section./' "$TEST_FILE"

echo "Running context gatherer again to detect changes..."
./tools/context-gatherer-with-sections.sh --tier essential --track-sections product test-output-2.md

echo "Cleaning up..."
rm -f "$TEST_FILE" test-output-1.md test-output-2.md

echo "Test completed!"
