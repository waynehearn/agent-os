#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

log() { echo "[create-spec][$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
error() { echo "[create-spec][ERROR][$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2; }

log "========== Starting create-spec =========="

# Set the initial spec input file path from the first argument
SPEC_INPUT_FILE=$1
if [ -z "$SPEC_INPUT_FILE" ]; then
  error "Usage: $0 <path_to_spec_input_file>"
  exit 1
fi

# Ensure the spec input file exists
if [ ! -f "$SPEC_INPUT_FILE" ]; then
  error "Spec input file not found at '$SPEC_INPUT_FILE'"
  exit 1
fi

log "Step 1: Normalizing spec name..."
NORMALIZED_NAME=$(cat "$SPEC_INPUT_FILE" | "$SCRIPT_DIR/spec-name-normalizer.sh")
if [ $? -ne 0 ]; then
  error "Error during spec name normalization."
  exit 1
fi
log "Normalized name: $NORMALIZED_NAME"

log "Step 2: Discovering product context..."
PRODUCT_CONTEXT=$("$SCRIPT_DIR/discover-product-context.sh" "$NORMALIZED_NAME")
if [ $? -ne 0 ]; then
  error "Error during product context discovery."
  exit 1
fi
log "Product context discovered."

log "Step 3: Creating specification..."
SPEC_OUTPUT_FILE="docs/$NORMALIZED_NAME-spec.md"
echo "# Specification for $NORMALIZED_NAME" > "$SPEC_OUTPUT_FILE"
echo "" >> "$SPEC_OUTPUT_FILE"
echo "This specification was generated based on the input from '$SPEC_INPUT_FILE' and the following product context:" >> "$SPEC_OUTPUT_FILE"
echo "" >> "$SPEC_OUTPUT_FILE"
echo "\`\`\`json" >> "$SPEC_OUTPUT_FILE"
echo "$PRODUCT_CONTEXT" >> "$SPEC_OUTPUT_FILE"
echo "\`\`\`" >> "$SPEC_OUTPUT_FILE"
log "Specification created at '$SPEC_OUTPUT_FILE'"

log "Step 4: Validating specification..."
"$SCRIPT_DIR/spec-validator.sh" "$SPEC_INPUT_FILE"
if [ $? -ne 0 ]; then
  error "Spec validation failed. See errors above."
  exit 1
fi
log "Validation complete."

log "========== create-spec process finished successfully =========="
