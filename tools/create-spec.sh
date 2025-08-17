#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Set the initial spec input file path from the first argument
SPEC_INPUT_FILE=$1
if [ -z "$SPEC_INPUT_FILE" ]; then
  echo "Usage: $0 <path_to_spec_input_file>"
  exit 1
fi

# Ensure the spec input file exists
if [ ! -f "$SPEC_INPUT_FILE" ]; then
  echo "Error: Spec input file not found at '$SPEC_INPUT_FILE'"
  exit 1
fi

# 1. Normalize the spec name
echo "Normalizing spec name..."
NORMALIZED_NAME=$(cat "$SPEC_INPUT_FILE" | "$SCRIPT_DIR/spec-name-normalizer.sh")
if [ $? -ne 0 ]; then
  echo "Error during spec name normalization."
  exit 1
fi
echo "Normalized name: $NORMALIZED_NAME"

# 2. Discover product context
echo "Discovering product context..."
PRODUCT_CONTEXT=$("$SCRIPT_DIR/discover-product-context.sh" "$NORMALIZED_NAME")
if [ $? -ne 0 ]; then
  echo "Error during product context discovery."
  exit 1
fi
echo "Product context discovered."

# 3. Create the specification
echo "Creating specification..."
SPEC_OUTPUT_FILE="docs/$NORMALIZED_NAME-spec.md"
echo "# Specification for $NORMALIZED_NAME" > "$SPEC_OUTPUT_FILE"
echo "" >> "$SPEC_OUTPUT_FILE"
echo "This specification was generated based on the input from '$SPEC_INPUT_FILE' and the following product context:" >> "$SPEC_OUTPUT_FILE"
echo "" >> "$SPEC_OUTPUT_FILE"
echo "\`\`\`json" >> "$SPEC_OUTPUT_FILE"
echo "$PRODUCT_CONTEXT" >> "$SPEC_OUTPUT_FILE"
echo "\`\`\`" >> "$SPEC_OUTPUT_FILE"
echo "Specification created at '$SPEC_OUTPUT_FILE'"

# 4. Validate the specification

echo "Validating specification..."
"$SCRIPT_DIR/spec-validator.sh" "$SPEC_INPUT_FILE"
if [ $? -ne 0 ]; then
  echo "Spec validation failed. See errors above."
  exit 1
fi
echo "Validation complete."

echo "create-spec process finished successfully."
