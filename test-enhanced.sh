#!/usr/bin/env bash
# test-enhanced.sh - Test the enhanced context gatherer script

echo "Testing enhanced hierarchical context gathering..."

# Test essential context gathering
echo "1. Testing essential context gathering:"
./tools/context-gatherer-enhanced.sh --tier essential product test-essential.md

# Test conditional context gathering
echo "2. Testing conditional context gathering:"
./tools/context-gatherer-enhanced.sh --tier conditional product test-conditional.md

# Test reference context gathering
echo "3. Testing reference context gathering:"
./tools/context-gatherer-enhanced.sh --tier reference product test-reference.md

# Test all tiers for a specific operation
echo "4. Testing all tiers for create-spec operation:"
./tools/context-gatherer-enhanced.sh --operation create-spec spec test-spec.md

# Show token summary
echo -e "\nToken usage summary:"
for file in test-essential.md test-conditional.md test-reference.md test-spec.md; do
  if [[ -f "$file" ]]; then
    tokens=$(grep "Total tokens:" "$file" | sed 's/- Total tokens: //')
    echo "$file: $tokens tokens"
  else
    echo "$file: Not created"
  fi
done

echo -e "\nTesting completed. Check the output files for results."
