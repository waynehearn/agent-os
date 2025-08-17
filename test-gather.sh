#!/usr/bin/env bash
# Testing simplified context gatherer functionality

echo "Testing hierarchical context gathering..."

# Create a simple test file with sections
mkdir -p test
cat > test/test-spec.md << 'EOF'
# Test Spec

## Requirements
- Requirement 1
- Requirement 2
- Requirement 3

## Implementation
- Step 1
- Step 2
- Step 3

## Examples
- Example 1
- Example 2
EOF

echo "Created test file with sections"

# Test section hash functionality
echo "Testing section hash functionality:"
./tools/context-gatherer.sh hash-section test/test-spec.md "Requirements"

# Test hierarchical gathering with essential tier only
echo "Testing essential tier gathering:"
./tools/context-gatherer.sh --tier essential --operation create-spec gather-context product test-context.md

# Check results
echo "Test completed. Results in test-context.md (if created)"
